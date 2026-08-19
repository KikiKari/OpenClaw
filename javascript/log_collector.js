#!/usr/bin/env node
// log_collector.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/log-collector/scripts/log_collector.py
// auch in: OpenClaw@gateway2:skills/log-collector/scripts/log_collector.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

/**
 * Log Collector Sub-Agent
 * Sammelt Logs von allen Nodes via SSH/VPN alle 3 Stunden
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const sqlite3 = require('sqlite3').verbose();

const WORKSPACE = path.join('/home/openclaw/.openclaw/workspace');
const DB_PATH = path.join(WORKSPACE, 'db', 'logs.db');
const LOG_DIR = path.join(WORKSPACE, 'logs', 'log-collector');

// Stelle sicher dass LOG_DIR existiert
try {
  fs.mkdirSync(LOG_DIR, { recursive: true });
} catch (err) {
  // Verzeichnis existiert bereits oder kann nicht erstellt werden
}

class Logger {
  constructor() {
    const today = new Date().toISOString().split('T')[0];
    this.logFile = path.join(LOG_DIR, `${today}.log`);
  }

  log(level, msg) {
    const ts = new Date().toISOString();
    const line = `[${ts}] [${level}] ${msg}`;
    console.log(line);
    try {
      fs.appendFileSync(this.logFile, line + '\n');
    } catch (err) {
      console.error(`Fehler beim Schreiben ins Logfile: ${err}`);
    }
  }

  info(msg) { this.log('INFO', msg); }
  error(msg) { this.log('ERROR', msg); }
}

class LogCollector {
  constructor() {
    this.logger = new Logger();
    this.conn = null;
  }

  connectDb() {
    this.conn = new sqlite3.Database(DB_PATH);
    // Schema initialisieren falls nicht existiert
    this.initSchema();
    return this.conn;
  }

  initSchema() {
    this.conn.serialize(() => {
      this.conn.all("SELECT name FROM sqlite_master WHERE type='table'", [], (err, rows) => {
        if (err) {
          this.logger.error(`Schema Check Fehler: ${err}`);
          return;
        }
        if (rows.length === 0) {
          const schemaPath = path.join(WORKSPACE, 'db', 'logs.db.schema.sql');
          if (fs.existsSync(schemaPath)) {
            const schemaSql = fs.readFileSync(schemaPath, 'utf8');
            this.conn.exec(schemaSql, (err) => {
              if (err) {
                this.logger.error(`Schema Init Fehler: ${err}`);
              }
            });
          }
        }
      });
    });
  }

  getNodes(callback) {
    /** Holt Liste aller Nodes aus DB */
    this.conn.all("SELECT * FROM nodes", [], (err, rows) => {
      if (err) {
        callback(err, []);
        return;
      }
      callback(null, rows);
    });
  }

  checkVpn(ip, callback) {
    /** Prüft ob VPN-IP erreichbar ist */
    const child = spawnSync('ping', ['-c', '1', '-W', '3', ip], { timeout: 10000 });
    callback(null, child.status === 0);
  }

  sshConnectAndCollect(node, callback) {
    /** Verbindet via SSH und sammelt Logs */
    const nodeId = node.node_id;
    const vpnIp = node.vpn_ip || node.tailscale_ip || node.wireguard_ip;

    if (!vpnIp) {
      this.logger.error(`${nodeId}: Keine VPN-IP konfiguriert`);
      callback(null, null);
      return;
    }

    // 1. VPN-Check
    this.logger.info(`${nodeId}: Prüfe VPN ${vpnIp}...`);
    this.checkVpn(vpnIp, (err, reachable) => {
      if (err || !reachable) {
        this.logger.error(`${nodeId}: VPN nicht erreichbar`);
        this.logSshConnection(nodeId, 'tailscale', false, 'VPN unreachable');
        callback(null, null);
        return;
      }

      // 2. SSH-Verbindung
      this.logger.info(`${nodeId}: Verbinde via SSH...`);
      
      const logCommands = [
        "journalctl -n 500 --no-pager",
        "tail -n 200 /var/log/syslog 2>/dev/null || echo 'no syslog'",
        "tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo 'no openclaw logs'"
      ];

      let logsCollected = [];
      let commandIndex = 0;

      const executeNextCommand = () => {
        if (commandIndex >= logCommands.length) {
          // Alle Commands ausgeführt
          this.logSshConnection(nodeId, 'ssh', true, null);
          this.insertLogs(nodeId, logsCollected);
          callback(null, logsCollected.length);
          return;
        }

        const cmd = logCommands[commandIndex];
        const child = spawnSync('ssh', [
          '-o', 'ConnectTimeout=10',
          '-o', 'StrictHostKeyChecking=no',
          `openclaw@${vpnIp}`,
          cmd
        ], { timeout: 30000 });

        if (child.error) {
          this.logger.error(`${nodeId}: SSH Fehler bei "${cmd}": ${child.error}`);
          this.logSshConnection(nodeId, 'ssh', false, child.error.message);
          callback(null, null);
          return;
        }

        if (child.status === 0) {
          logsCollected.push({
            command: cmd,
            output: child.stdout.toString(),
            timestamp: new Date().toISOString()
          });
        }

        commandIndex++;
        executeNextCommand();
      };

      try {
        executeNextCommand();
      } catch (e) {
        this.logger.error(`${nodeId}: SSH Fehler: ${e}`);
        this.logSshConnection(nodeId, 'ssh', false, e.message);
        callback(null, null);
      }
    });
  }

  logSshConnection(nodeId, connType, success, error) {
    /** Loggt SSH-Verbindungsversuch */
    const stmt = this.conn.prepare(`
      INSERT INTO ssh_connections (node_id, connection_type, success, error_message)
      VALUES (?, ?, ?, ?)
    `);
    stmt.run(nodeId, connType, success ? 1 : 0, error);
    stmt.finalize();
  }

  insertLogs(nodeId, logs) {
    /** Speichert Logs in Datenbank */
    const retention = new Date();
    retention.setDate(retention.getDate() + 30);
    const retentionIso = retention.toISOString();

    const stmt = this.conn.prepare(`
      INSERT INTO logs (node_id, log_type, source, content, severity, 
                      collected_by, collection_method, retention_until)
      VALUES (?, 'system', ?, ?, 'info', ?, 'ssh', ?)
    `);

    for (const logEntry of logs) {
      const source = logEntry.command.substring(0, 50);
      const content = logEntry.output.substring(0, 10000); // Limit 10KB
      stmt.run(nodeId, source, content, 'node1', retentionIso);
    }
    stmt.finalize();

    this.logger.info(`${nodeId}: ${logs.length} Log-Einträge gespeichert`);
  }

  cleanupRetention(callback) {
    /** Löscht Logs älter 30 Tage */
    this.conn.run(`
      DELETE FROM logs WHERE retention_until < datetime('now')
    `, function(err) {
      if (err) {
        console.error(`Retention-Cleanup Fehler: ${err}`);
        callback(err, 0);
        return;
      }
      const deleted = this.changes;
      this.logger.info(`Retention-Cleanup: ${deleted} alte Logs gelöscht`);
      callback(null, deleted);
    }.bind(this));
  }

  runCollectionCycle() {
    /** Ein kompletter Sammel-Durchlauf */
    this.logger.info("=".repeat(60));
    this.logger.info("LOG COLLECTOR CYCLE START");
    this.logger.info("=".repeat(60));

    this.connectDb();

    // 1. Nodes holen
    this.getNodes((err, nodes) => {
      if (err) {
        this.logger.error(`Fehler beim Holen der Nodes: ${err}`);
        process.exit(1);
      }

      this.logger.info(`Gefunden: ${nodes.length} Nodes`);

      // 2. Collection-Run starten
      this.conn.run(`
        INSERT INTO collection_runs (started_at, nodes_total)
        VALUES (CURRENT_TIMESTAMP, ?)
      `, [nodes.length], function(err) {
        if (err) {
          this.logger.error(`Fehler beim Starten des Runs: ${err}`);
          process.exit(1);
        }

        const runId = this.lastID;

        // 3. Für jeden Node sammeln
        let successCount = 0;
        let failedCount = 0;
        let totalLogs = 0;
        let processedNodes = 0;

        const processNextNode = () => {
          if (processedNodes >= nodes.length) {
            // Alle Nodes verarbeitet
            this.conn.run(`
              UPDATE collection_runs SET
                finished_at = CURRENT_TIMESTAMP,
                nodes_success = ?,
                nodes_failed = ?,
                logs_collected = ?
              WHERE run_id = ?
            `, [successCount, failedCount, totalLogs, runId], (err) => {
              if (err) {
                this.logger.error(`Fehler beim Abschließen des Runs: ${err}`);
              }

              // 5. Retention-Cleanup
              this.logger.info("Retention-Cleanup (30 Tage)...");
              this.cleanupRetention((err, deleted) => {
                if (err) {
                  this.logger.error(`Retention-Cleanup Fehler: ${err}`);
                }

                this.logger.info("=".repeat(60));
                this.logger.info(`SUMMARY: ${successCount} OK, ${failedCount} Failed, ${totalLogs} Logs`);
                this.logger.info("=".repeat(60));
              });
            });
            return;
          }

          const node = nodes[processedNodes];

          if (node.node_id === 'node1') {
            // Lokale Logs (Gateway selbst)
            this.logger.info("node1: Lokale Collection (Gateway)");
            successCount++;
            processedNodes++;
            processNextNode();
          } else {
            // Remote-Node abfragen
            this.sshConnectAndCollect(node, (err, result) => {
              if (result !== null) {
                successCount++;
                totalLogs += result;
              } else {
                failedCount++;
              }
              processedNodes++;
              processNextNode();
            });
          }
        };

        processNextNode();
      }.bind(this));
    });
  }
}

function main() {
  console.log("=".repeat(60));
  console.log("LOG COLLECTOR");
  console.log("=".repeat(60));

  const collector = new LogCollector();

  try {
    collector.runCollectionCycle();
  } catch (e) {
    console.log(`CRITICAL ERROR: ${e}`);
    console.error(e.stack);
    process.exit(1);
  }
}

main();
