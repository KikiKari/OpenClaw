#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "abe55d2d00dc11419bcd22cf42038c0ef4a9955c29ae778ae53bfc3f82b18f55", "source_sha256": "5081f9f0745ca8b2223c2de657aa97d48e58ccf61c24467e46c9d562803e34a6", "target_language": "javascript"}
// log_collector.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/log-collector/scripts/log_collector.py
// auch in: OpenClaw@gateway2:skills/log-collector/scripts/log_collector.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

/**
 * Log Collector Sub-Agent
 * Sammelt Logs von allen Nodes via SSH/VPN alle 3 Stunden
 */

const fs = require('fs');
const path = require('path');
const { spawnSync, execSync } = require('child_process');
const sqlite3 = require('sqlite3').verbose();

const WORKSPACE = path.join(process.env.HOME, '.openclaw', 'workspace');
const DB_PATH = path.join(WORKSPACE, 'db', 'logs.db');
const LOG_DIR = path.join(WORKSPACE, 'logs', 'log-collector');

// Stelle sicher, dass das Log-Verzeichnis existiert
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
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
    fs.appendFileSync(this.logFile, line + '\n');
  }

  info(msg) { this.log('INFO', msg); }
  error(msg) { this.log('ERROR', msg); }
}

class LogCollector {
  constructor() {
    this.logger = new Logger();
    this.db = null;
  }

  connectDb() {
    this.db = new sqlite3.Database(DB_PATH);
    // Schema initialisieren falls nicht existiert
    this.initSchema();
    return this.db;
  }

  initSchema() {
    const schemaPath = path.join(WORKSPACE, 'db', 'logs.db.schema.sql');
    if (fs.existsSync(schemaPath)) {
      const schema = fs.readFileSync(schemaPath, 'utf8');
      this.db.exec(schema);
    }
  }

  getNodes() {
    return new Promise((resolve, reject) => {
      this.db.all("SELECT * FROM nodes", (err, rows) => {
        if (err) reject(err);
        else resolve(rows);
      });
    });
  }

  checkVpn(ip) {
    try {
      const result = spawnSync('ping', ['-c', '1', '-W', '3', ip], {
        timeout: 10000
      });
      return result.status === 0;
    } catch {
      return false;
    }
  }

  async sshConnectAndCollect(node) {
    const nodeId = node.node_id;
    const vpnIp = node.vpn_ip || node.tailscale_ip || node.wireguard_ip;

    if (!vpnIp) {
      this.logger.error(`${nodeId}: Keine VPN-IP konfiguriert`);
      return null;
    }

    // 1. VPN-Check
    this.logger.info(`${nodeId}: Prüfe VPN ${vpnIp}...`);
    if (!this.checkVpn(vpnIp)) {
      this.logger.error(`${nodeId}: VPN nicht erreichbar`);
      await this.logSshConnection(nodeId, 'tailscale', false, 'VPN unreachable');
      return null;
    }

    // 2. SSH-Verbindung
    this.logger.info(`${nodeId}: Verbinde via SSH...`);
    try {
      // Logs abholen (ohne cd wegen exec-Beschränkungen)
      const logCommands = [
        "journalctl -n 500 --no-pager",
        "tail -n 200 /var/log/syslog 2>/dev/null || echo 'no syslog'",
        "tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo 'no openclaw logs'"
      ];

      const logsCollected = [];
      for (const cmd of logCommands) {
        const result = spawnSync('ssh', [
          '-o', 'ConnectTimeout=10',
          '-o', 'StrictHostKeyChecking=no',
          `openclaw@${vpnIp}`,
          cmd
        ], {
          encoding: 'utf8',
          timeout: 30000
        });

        if (result.status === 0) {
          logsCollected.push({
            command: cmd,
            output: result.stdout,
            timestamp: new Date().toISOString()
          });
        }
      }

      // Erfolg loggen
      await this.logSshConnection(nodeId, 'ssh', true, null);

      // In DB speichern
      await this.insertLogs(nodeId, logsCollected);

      return logsCollected.length;

    } catch (error) {
      if (error.message.includes('ETIMEDOUT')) {
        this.logger.error(`${nodeId}: SSH Timeout`);
        await this.logSshConnection(nodeId, 'ssh', false, 'Timeout');
      } else {
        this.logger.error(`${nodeId}: SSH Fehler: ${error.message}`);
        await this.logSshConnection(nodeId, 'ssh', false, error.message);
      }
      return null;
    }
  }

  logSshConnection(nodeId, connType, success, error) {
    return new Promise((resolve, reject) => {
      this.db.run(`
        INSERT INTO ssh_connections (node_id, connection_type, success, error_message)
        VALUES (?, ?, ?, ?)
      `, [nodeId, connType, success, error], (err) => {
        if (err) reject(err);
        else resolve();
      });
    });
  }

  insertLogs(nodeId, logs) {
    return new Promise((resolve, reject) => {
      const stmt = this.db.prepare(`
        INSERT INTO logs (node_id, log_type, source, content, severity, 
                         collected_by, collection_method, retention_until)
        VALUES (?, 'system', ?, ?, 'info', ?, 'ssh', ?)
      `);

      const retention = new Date();
      retention.setDate(retention.getDate() + 30);
      const retentionIso = retention.toISOString();

      let insertedCount = 0;
      logs.forEach(logEntry => {
        stmt.run(
          nodeId,
          logEntry.command.substring(0, 50),
          logEntry.output.substring(0, 10000),
          'node1',
          retentionIso
        );
        insertedCount++;
      });

      stmt.finalize((err) => {
        if (err) reject(err);
        else {
          this.logger.info(`${nodeId}: ${insertedCount} Log-Einträge gespeichert`);
          resolve();
        }
      });
    });
  }

  cleanupRetention() {
    return new Promise((resolve, reject) => {
      this.db.run(`
        DELETE FROM logs WHERE retention_until < datetime('now')
      `, function(err) {
        if (err) reject(err);
        else {
          this.logger.info(`Retention-Cleanup: ${this.changes} alte Logs gelöscht`);
          resolve(this.changes);
        }
      }.bind(this));
    });
  }

  async runCollectionCycle() {
    this.logger.info("=".repeat(60));
    this.logger.info("LOG COLLECTOR CYCLE START");
    this.logger.info("=".repeat(60));

    this.connectDb();

    // 1. Nodes holen
    const nodes = await this.getNodes();
    this.logger.info(`Gefunden: ${nodes.length} Nodes`);

    // 2. Collection-Run starten
    const runInfo = await new Promise((resolve, reject) => {
      this.db.run(`
        INSERT INTO collection_runs (started_at, nodes_total)
        VALUES (CURRENT_TIMESTAMP, ?)
      `, [nodes.length], function(err) {
        if (err) reject(err);
        else resolve({ runId: this.lastID });
      });
    });

    // 3. Für jeden Node sammeln
    let successCount = 0;
    let failedCount = 0;
    let totalLogs = 0;

    for (const node of nodes) {
      if (node.node_id === 'node1') {
        // Lokale Logs (Gateway selbst)
        this.logger.info("node1: Lokale Collection (Gateway)");
        successCount++;
      } else {
        // Remote-Node abfragen
        const result = await this.sshConnectAndCollect(node);
        if (result !== null) {
          successCount++;
          totalLogs += result;
        } else {
          failedCount++;
        }
      }
    }

    // 4. Run abschließen
    await new Promise((resolve, reject) => {
      this.db.run(`
        UPDATE collection_runs SET
          finished_at = CURRENT_TIMESTAMP,
          nodes_success = ?,
          nodes_failed = ?,
          logs_collected = ?
        WHERE run_id = ?
      `, [successCount, failedCount, totalLogs, runInfo.runId], (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    // 5. Retention-Cleanup
    this.logger.info("Retention-Cleanup (30 Tage)...");
    await this.cleanupRetention();

    this.logger.info("=".repeat(60));
    this.logger.info(`SUMMARY: ${successCount} OK, ${failedCount} Failed, ${totalLogs} Logs`);
    this.logger.info("=".repeat(60));
  }
}

async function main() {
  console.log("=".repeat(60));
  console.log("LOG COLLECTOR");
  console.log("=".repeat(60));

  const collector = new LogCollector();

  try {
    await collector.runCollectionCycle();
  } catch (error) {
    console.error(`CRITICAL ERROR: ${error.message}`);
    console.error(error.stack);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { LogCollector };
