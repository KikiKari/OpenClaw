// abstraction-provenance: {"artifact_sha256": "df0b8874167d35c5f4e546d1ab8f4a84e2fea5d574fde24614c81562b9a4cc4c", "source_sha256": "5081f9f0745ca8b2223c2de657aa97d48e58ccf61c24467e46c9d562803e34a6", "target_language": "go"}
// log_collector.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/log-collector/scripts/log_collector.py
// auch in: OpenClaw@gateway2:skills/log-collector/scripts/log_collector.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

const (
	WORKSPACE = "/home/openclaw/.openclaw/workspace"
	DB_PATH   = WORKSPACE + "/db/logs.db"
	LOG_DIR   = WORKSPACE + "/logs/log-collector"
)

type Logger struct {
	logFile *os.File
}

func NewLogger() *Logger {
	os.MkdirAll(LOG_DIR, 0755)
	today := time.Now().Format("2006-01-02")
	logFilePath := filepath.Join(LOG_DIR, today+".log")
	
	file, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatal(err)
	}
	
	return &Logger{logFile: file}
}

func (l *Logger) log(level string, msg string) {
	ts := time.Now().Format(time.RFC3339)
	line := fmt.Sprintf("[%s] [%s] %s\n", ts, level, msg)
	fmt.Print(line)
	l.logFile.WriteString(line)
}

func (l *Logger) Info(msg string)  { l.log("INFO", msg) }
func (l *Logger) Error(msg string) { l.log("ERROR", msg) }

type LogCollector struct {
	logger *Logger
	conn   *sql.DB
}

func NewLogCollector() *LogCollector {
	return &LogCollector{
		logger: NewLogger(),
	}
}

func (lc *LogCollector) connectDB() error {
	db, err := sql.Open("sqlite3", DB_PATH)
	if err != nil {
		return err
	}
	lc.conn = db
	
	// Initialize schema if needed
	err = lc.initSchema()
	if err != nil {
		return err
	}
	
	return nil
}

func (lc *LogCollector) initSchema() error {
	// Check if tables exist
	var name string
	err := lc.conn.QueryRow("SELECT name FROM sqlite_master WHERE type='table' LIMIT 1").Scan(&name)
	
	// If no tables found, initialize schema
	if err == sql.ErrNoRows {
		schemaPath := filepath.Join(WORKSPACE, "db", "logs.db.schema.sql")
		if _, err := os.Stat(schemaPath); err == nil {
			schemaBytes, err := os.ReadFile(schemaPath)
			if err != nil {
				return err
			}
			
			_, err = lc.conn.Exec(string(schemaBytes))
			if err != nil {
				return err
			}
		}
	}
	
	return nil
}

func (lc *LogCollector) getNodes() ([]map[string]interface{}, error) {
	rows, err := lc.conn.Query("SELECT * FROM nodes")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	columns, _ := rows.Columns()
	nodes := make([]map[string]interface{}, 0)
	
	for rows.Next() {
		values := make([]interface{}, len(columns))
		valuePtrs := make([]interface{}, len(columns))
		for i := range values {
			valuePtrs[i] = &values[i]
		}
		
		err := rows.Scan(valuePtrs...)
		if err != nil {
			return nil, err
		}
		
		node := make(map[string]interface{})
		for i, col := range columns {
			val := *(valuePtrs[i].(*interface{}))
			node[col] = val
		}
		nodes = append(nodes, node)
	}
	
	return nodes, nil
}

func (lc *LogCollector) checkVPN(ip string) bool {
	cmd := exec.Command("ping", "-c", "1", "-W", "3", ip)
	err := cmd.Run()
	return err == nil
}

func (lc *LogCollector) sshConnectAndCollect(node map[string]interface{}) *int {
	nodeID := node["node_id"].(string)
	
	var vpnIP string
	if val, ok := node["vpn_ip"]; ok && val != nil {
		vpnIP = val.(string)
	} else if val, ok := node["tailscale_ip"]; ok && val != nil {
		vpnIP = val.(string)
	} else if val, ok := node["wireguard_ip"]; ok && val != nil {
		vpnIP = val.(string)
	}
	
	if vpnIP == "" {
		lc.logger.Error(fmt.Sprintf("%s: Keine VPN-IP konfiguriert", nodeID))
		return nil
	}
	
	// 1. VPN-Check
	lc.logger.Info(fmt.Sprintf("%s: Prüfe VPN %s...", nodeID, vpnIP))
	if !lc.checkVPN(vpnIP) {
		lc.logger.Error(fmt.Sprintf("%s: VPN nicht erreichbar", nodeID))
		lc.logSSHConnection(nodeID, "tailscale", false, "VPN unreachable")
		return nil
	}
	
	// 2. SSH-Verbindung
	lc.logger.Info(fmt.Sprintf("%s: Verbinde via SSH...", nodeID))
	
	logCommands := []string{
		"journalctl -n 500 --no-pager",
		"tail -n 200 /var/log/syslog 2>/dev/null || echo 'no syslog'",
		"tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo 'no openclaw logs'",
	}
	
	logsCollected := make([]map[string]interface{}, 0)
	
	for _, cmd := range logCommands {
		sshCmd := exec.Command("ssh", "-o", "ConnectTimeout=10", "-o", "StrictHostKeyChecking=no",
			fmt.Sprintf("openclaw@%s", vpnIP), cmd)
		
		output, err := sshCmd.CombinedOutput()
		if err == nil {
			logEntry := map[string]interface{}{
				"command":   cmd,
				"output":    string(output),
				"timestamp": time.Now().Format(time.RFC3339),
			}
			logsCollected = append(logsCollected, logEntry)
		}
	}
	
	// Erfolg loggen
	lc.logSSHConnection(nodeID, "ssh", true, "")
	
	// In DB speichern
	lc.insertLogs(nodeID, logsCollected)
	
	count := len(logsCollected)
	return &count
}

func (lc *LogCollector) logSSHConnection(nodeID string, connType string, success bool, errorMsg string) {
	stmt, err := lc.conn.Prepare(`INSERT INTO ssh_connections 
		(node_id, connection_type, success, error_message) 
		VALUES (?, ?, ?, ?)`)
	if err != nil {
		log.Fatal(err)
	}
	defer stmt.Close()
	
	_, err = stmt.Exec(nodeID, connType, success, errorMsg)
	if err != nil {
		log.Fatal(err)
	}
}

func (lc *LogCollector) insertLogs(nodeID string, logs []map[string]interface{}) {
	stmt, err := lc.conn.Prepare(`INSERT INTO logs 
		(node_id, log_type, source, content, severity, collected_by, collection_method, retention_until) 
		VALUES (?, 'system', ?, ?, 'info', ?, 'ssh', ?)`)
	if err != nil {
		log.Fatal(err)
	}
	defer stmt.Close()
	
	retention := time.Now().AddDate(0, 0, 30).Format(time.RFC3339)
	
	for _, logEntry := range logs {
		command := logEntry["command"].(string)
		if len(command) > 50 {
			command = command[:50]
		}
		
		content := logEntry["output"].(string)
		if len(content) > 10000 {
			content = content[:10000]
		}
		
		_, err := stmt.Exec(nodeID, command, content, "node1", retention)
		if err != nil {
			log.Fatal(err)
		}
	}
	
	lc.logger.Info(fmt.Sprintf("%s: %d Log-Einträge gespeichert", nodeID, len(logs)))
}

func (lc *LogCollector) cleanupRetention() int {
	stmt, err := lc.conn.Prepare(`DELETE FROM logs WHERE retention_until < datetime('now')`)
	if err != nil {
		log.Fatal(err)
	}
	defer stmt.Close()
	
	result, err := stmt.Exec()
	if err != nil {
		log.Fatal(err)
	}
	
	deleted, _ := result.RowsAffected()
	lc.logger.Info(fmt.Sprintf("Retention-Cleanup: %d alte Logs gelöscht", deleted))
	return int(deleted)
}

func (lc *LogCollector) runCollectionCycle() {
	lc.logger.Info(strings.Repeat("=", 60))
	lc.logger.Info("LOG COLLECTOR CYCLE START")
	lc.logger.Info(strings.Repeat("=", 60))
	
	err := lc.connectDB()
	if err != nil {
		log.Fatal(err)
	}
	
	// 1. Nodes holen
	nodes, err := lc.getNodes()
	if err != nil {
		log.Fatal(err)
	}
	lc.logger.Info(fmt.Sprintf("Gefunden: %d Nodes", len(nodes)))
	
	// 2. Collection-Run starten
	stmt, err := lc.conn.Prepare(`INSERT INTO collection_runs 
		(started_at, nodes_total) VALUES (datetime('now'), ?)`)
	if err != nil {
		log.Fatal(err)
	}
	
	result, err := stmt.Exec(len(nodes))
	if err != nil {
		log.Fatal(err)
	}
	
	runID, _ := result.LastInsertId()
	stmt.Close()
	
	// 3. Für jeden Node sammeln
	successCount := 0
	failedCount := 0
	totalLogs := 0
	
	for _, node := range nodes {
		nodeID := node["node_id"].(string)
		if nodeID == "node1" {
			// Lokale Logs (Gateway selbst)
			lc.logger.Info("node1: Lokale Collection (Gateway)")
			successCount++
		} else {
			// Remote-Node abfragen
			result := lc.sshConnectAndCollect(node)
			if result != nil {
				successCount++
				totalLogs += *result
			} else {
				failedCount++
			}
		}
	}
	
	// 4. Run abschließen
	stmt, err = lc.conn.Prepare(`UPDATE collection_runs SET
		finished_at = datetime('now'),
		nodes_success = ?,
		nodes_failed = ?,
		logs_collected = ?
		WHERE run_id = ?`)
	if err != nil {
		log.Fatal(err)
	}
	
	_, err = stmt.Exec(successCount, failedCount, totalLogs, runID)
	if err != nil {
		log.Fatal(err)
	}
	stmt.Close()
	
	// 5. Retention-Cleanup
	lc.logger.Info("Retention-Cleanup (30 Tage)...")
	lc.cleanupRetention()
	
	lc.logger.Info(strings.Repeat("=", 60))
	lc.logger.Info(fmt.Sprintf("SUMMARY: %d OK, %d Failed, %d Logs", successCount, failedCount, totalLogs))
	lc.logger.Info(strings.Repeat("=", 60))
}

func main() {
	fmt.Println(strings.Repeat("=", 60))
	fmt.Println("LOG COLLECTOR")
	fmt.Println(strings.Repeat("=", 60))
	
	collector := NewLogCollector()
	
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("CRITICAL ERROR: %v\n", r)
			os.Exit(1)
		}
	}()
	
	collector.runCollectionCycle()
}
