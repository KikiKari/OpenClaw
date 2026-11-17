#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "8096f9b8f37584f1a1481aaa54978e4241b345a87055848a76181a7ccf642485", "source_sha256": "5081f9f0745ca8b2223c2de657aa97d48e58ccf61c24467e46c9d562803e34a6", "target_language": "ruby"}
# log_collector.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/log-collector/scripts/log_collector.py
# auch in: OpenClaw@gateway2:skills/log-collector/scripts/log_collector.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Log Collector Sub-Agent
# Sammelt Logs von allen Nodes via SSH/VPN alle 3 Stunden

require 'sqlite3'
require 'json'
require 'fileutils'
require 'date'
require 'open3'

WORKSPACE = File.join(ENV['HOME'], '.openclaw', 'workspace')
DB_PATH = File.join(WORKSPACE, 'db', 'logs.db')
LOG_DIR = File.join(WORKSPACE, 'logs', 'log-collector')

FileUtils.mkdir_p(LOG_DIR)

class Logger
  def initialize
    @today = Date.today.strftime('%Y-%m-%d')
    @log_file = File.join(LOG_DIR, "#{@today}.log")
  end

  def log(level, msg)
    ts = Time.now.iso8601
    line = "[#{ts}] [#{level}] #{msg}"
    puts line
    File.open(@log_file, 'a') { |f| f.puts line }
  end

  def info(msg); log('INFO', msg); end
  def error(msg); log('ERROR', msg); end
end

class LogCollector
  def initialize
    @logger = Logger.new
    @conn = nil
  end

  def connect_db
    @conn = SQLite3::Database.new(DB_PATH)
    @conn.results_as_hash = true
    init_schema
    @conn
  end

  def init_schema
    return unless @conn.execute("SELECT name FROM sqlite_master WHERE type='table'").empty?

    schema_path = File.join(WORKSPACE, 'db', 'logs.db.schema.sql')
    return unless File.exist?(schema_path)

    schema_sql = File.read(schema_path)
    @conn.execute_batch(schema_sql)
  end

  def get_nodes
    rows = @conn.execute('SELECT * FROM nodes')
    rows.map(&:clone)
  end

  def check_vpn(ip)
    stdin, stdout, stderr, wait_thr = Open3.popen3('ping', '-c', '1', '-W', '3', ip)
    stdin.close
    stdout.close
    stderr.close
    wait_thr.value.success?
  rescue StandardError
    false
  end

  def ssh_connect_and_collect(node)
    node_id = node['node_id']
    vpn_ip = node['vpn_ip'] || node['tailscale_ip'] || node['wireguard_ip']

    unless vpn_ip
      @logger.error("#{node_id}: Keine VPN-IP konfiguriert")
      return nil
    end

    # 1. VPN-Check
    @logger.info("#{node_id}: Prüfe VPN #{vpn_ip}...")
    unless check_vpn(vpn_ip)
      @logger.error("#{node_id}: VPN nicht erreichbar")
      log_ssh_connection(node_id, 'tailscale', false, 'VPN unreachable')
      return nil
    end

    # 2. SSH-Verbindung
    @logger.info("#{node_id}: Verbinde via SSH...")
    begin
      log_commands = [
        'journalctl -n 500 --no-pager',
        'tail -n 200 /var/log/syslog 2>/dev/null || echo \'no syslog\'',
        'tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo \'no openclaw logs\''
      ]

      logs_collected = []
      log_commands.each do |cmd|
        stdin, stdout, stderr, wait_thr = Open3.popen3(
          'ssh', '-o', 'ConnectTimeout=10', '-o', 'StrictHostKeyChecking=no',
          "openclaw@#{vpn_ip}", cmd
        )

        output = stdout.read
        stdin.close
        stdout.close
        stderr.close
        exit_status = wait_thr.value

        next unless exit_status.success?

        logs_collected.push(
          'command' => cmd,
          'output' => output,
          'timestamp' => Time.now.iso8601
        )
      end

      # Erfolg loggen
      log_ssh_connection(node_id, 'ssh', true, nil)

      # In DB speichern
      insert_logs(node_id, logs_collected)

      logs_collected.length
    rescue Timeout::Error
      @logger.error("#{node_id}: SSH Timeout")
      log_ssh_connection(node_id, 'ssh', false, 'Timeout')
      nil
    rescue Errno::ENOENT
      @logger.error("#{node_id}: SSH nicht verfügbar")
      nil
    rescue StandardError => e
      @logger.error("#{node_id}: SSH Fehler: #{e.message}")
      log_ssh_connection(node_id, 'ssh', false, e.message)
      nil
    end
  end

  def log_ssh_connection(node_id, conn_type, success, error)
    @conn.execute(
      'INSERT INTO ssh_connections (node_id, connection_type, success, error_message) VALUES (?, ?, ?, ?)',
      [node_id, conn_type, success ? 1 : 0, error]
    )
  end

  def insert_logs(node_id, logs)
    retention = (Date.today + 30).to_time.iso8601
    inserted_count = 0

    logs.each do |log_entry|
      @conn.execute(
        'INSERT INTO logs (node_id, log_type, source, content, severity, collected_by, collection_method, retention_until) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          node_id,
          'system',
          log_entry['command'][0..49],
          log_entry['output'][0..9999],
          'info',
          'node1',
          'ssh',
          retention
        ]
      )
      inserted_count += 1
    end

    @logger.info("#{node_id}: #{inserted_count} Log-Einträge gespeichert")
  end

  def cleanup_retention
    result = @conn.execute('DELETE FROM logs WHERE retention_until < datetime(\'now\')')
    deleted = result
    @logger.info("Retention-Cleanup: #{deleted} alte Logs gelöscht")
    deleted
  end

  def run_collection_cycle
    @logger.info('=' * 60)
    @logger.info('LOG COLLECTOR CYCLE START')
    @logger.info('=' * 60)

    connect_db

    # 1. Nodes holen
    nodes = get_nodes
    @logger.info("Gefunden: #{nodes.length} Nodes")

    # 2. Collection-Run starten
    @conn.execute(
      'INSERT INTO collection_runs (started_at, nodes_total) VALUES (CURRENT_TIMESTAMP, ?)',
      [nodes.length]
    )
    run_id = @conn.last_insert_row_id

    # 3. Für jeden Node sammeln
    success_count = 0
    failed_count = 0
    total_logs = 0

    nodes.each do |node|
      if node['node_id'] == 'node1'
        # Lokale Logs (Gateway selbst)
        @logger.info('node1: Lokale Collection (Gateway)')
        success_count += 1
      else
        # Remote-Node abfragen
        result = ssh_connect_and_collect(node)
        if result
          success_count += 1
          total_logs += result
        else
          failed_count += 1
        end
      end
    end

    # 4. Run abschließen
    @conn.execute(
      'UPDATE collection_runs SET finished_at = CURRENT_TIMESTAMP, nodes_success = ?, nodes_failed = ?, logs_collected = ? WHERE run_id = ?',
      [success_count, failed_count, total_logs, run_id]
    )

    # 5. Retention-Cleanup
    @logger.info('Retention-Cleanup (30 Tage)...')
    cleanup_retention

    @logger.info('=' * 60)
    @logger.info("SUMMARY: #{success_count} OK, #{failed_count} Failed, #{total_logs} Logs")
    @logger.info('=' * 60)
  end
end

def main
  puts '=' * 60
  puts 'LOG COLLECTOR'
  puts '=' * 60

  collector = LogCollector.new

  begin
    collector.run_collection_cycle
  rescue StandardError => e
    puts "CRITICAL ERROR: #{e.message}"
    puts e.backtrace
    exit(1)
  end
end

main if __FILE__ == $PROGRAM_NAME
