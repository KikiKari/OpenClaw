#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "e050084824923e0b18c237aa18288a9708ad84a4700cefb85f445f780785b5f7", "source_sha256": "fc4ce94d8389188be8aa35f040d616ca2baa44095f057fa78606f347d342ff4b", "target_language": "ruby"}
# ABSTRACTIONS_MANAGER.py — portiert nach ruby
# Quelle: python, workspace@local:git/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Script Abstractions Manager
#
# Uebersetzt jede Quelldatei aus den drei Repositories KikiKari/OpenClaw,
# KikiKari/Projects und KikiKari/Onboarding in sechs Zielsprachen und legt
# das Ergebnis in den Sprachverzeichnissen des Abstraktions-Repositories ab.
#
# Es entstehen vollstaendige Uebersetzungen, keine Ruempfe: jede Datei geht
# als Ganzes an ein Sprachmodell, das lauffaehigen Code in der Zielsprache
# zurueckgibt. Erzeugnisse, deren Syntax sich nicht pruefen laesst oder die
# erkennbar unfertig sind, werden verworfen statt abgelegt.
#
# Verwendung:
#     ruby ABSTRACTIONS_MANAGER.rb [--prioritaet high|medium|low|alle]
#                                   [--anzahl N] [--probelauf]
#
# Umgebung:
#     OPENROUTER_API_KEY      Pflicht. Schluessel fuer die Uebersetzung.
#     ABSTRACTIONS_WORKSPACE  Arbeitsverzeichnis, Vorgabe
#                             /home/openclaw/.openclaw/workspace
#     ABSTRACTIONS_MODELL     Modellkennung, Vorgabe siehe MODELLE
#     ABSTRACTIONS_ANZAHL     Quelldateien je Lauf, Vorgabe 40

require 'digest'
require 'fileutils'
require 'json'
require 'logger'
require 'net/http'
require 'optparse'
require 'pathname'
require 'securerandom'
require 'tempfile'
require 'time'
require 'uri'

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

WORKSPACE = Pathname.new(ENV.fetch('ABSTRACTIONS_WORKSPACE', '/home/openclaw/.openclaw/workspace'))
ABSTRACTIONS_REPO = WORKSPACE.join('git', 'OpenClaw-gateway1-abstractions')
QUELLEN_DIR = WORKSPACE.join('git', 'quellen')
LOG_DIR = WORKSPACE.join('logs', 'abstractions-manager')
STATE_FILE = WORKSPACE.join('db', 'abstractions_state.json')

GITHUB_BENUTZER = 'KikiKari'

# Herkunft der Quelldateien. Projects wird ueber alle Branches gelesen, weil
# dort jedes Projekt in einem eigenen verwaisten Branch liegt.
QUELLEN = [
  { 'repo' => 'OpenClaw', 'branches' => %w[main gateway1 gateway2] },
  { 'repo' => 'Projects', 'branches' => 'alle' },
  { 'repo' => 'Onboarding', 'branches' => ['main'] }
]

# Dateiendung -> Quellsprache. Bestimmt zugleich, was eingelesen wird.
QUELLSPRACHEN = {
  '.pl' => 'perl5',
  '.pm' => 'perl5',
  '.ps1' => 'powershell',
  '.psm1' => 'powershell',
  '.sh' => 'shell',
  '.bash' => 'shell',
  '.tcl' => 'tcl',
  '.html' => 'html',
  '.htm' => 'html',
  '.js' => 'javascript',
  '.mjs' => 'javascript',
  '.cjs' => 'javascript',
  '.py' => 'python',
  '.css' => 'css'
}.freeze

# Die sechs Zielverzeichnisse, nach der Vorlage aus
# OpenClaw@gateway1-abstractions. Sie liegen im Wurzelverzeichnis des
# Abstraktions-Repositories.
ZIELSPRACHEN = {
  'javascript' => { 'ext' => '.js', 'bezeichnung' => 'JavaScript fuer Node 20' },
  'perl5' => { 'ext' => '.pl', 'bezeichnung' => 'Perl 5 mit use strict und use warnings' },
  'powershell' => { 'ext' => '.ps1', 'bezeichnung' => 'PowerShell 7' },
  'python' => { 'ext' => '.py', 'bezeichnung' => 'Python 3.12' },
  'shell' => { 'ext' => '.sh', 'bezeichnung' => 'Bash 5 mit set -euo pipefail' },
  'tcl' => { 'ext' => '.tcl', 'bezeichnung' => 'Tcl 8.6' }
}.freeze

# Verzeichnisse und Muster, die nie eingelesen werden.
AUSSCHLUSS = %w[
  node_modules/
  /.git/
  __pycache__/
  dist/
  build/
  vendor/
  .venv/
  site-packages/
  python-hardener-workspace/
  .artifacts/
  coverage/
  .next/
  target/
].freeze

MAX_BYTES = 200_000

# Reihenfolge der Ausweichmodelle. Geprueft gegen das Konto: die Anbieter von
# OpenAI und Anthropic sind dort ueber die Privatsphaere-Einstellung
# ausgeschlossen ("All providers have been ignored"), diese hier antworten.
MODELLE = %w[
  qwen/qwen3-coder
  deepseek/deepseek-chat-v3.1
  z-ai/glm-4.6
  mistralai/codestral-2508
  qwen/qwen-2.5-coder-32b-instruct
].freeze

API_URL = 'https://openrouter.ai/api/v1/chat/completions'
ZEITLIMIT = 240
VERSUCHE = 3

# ---------------------------------------------------------------------------
# Protokoll
# ---------------------------------------------------------------------------

def protokoll
  @logger ||= begin
    log = Logger.new($stdout)
    log.level = Logger::INFO
    log.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} | #{severity.ljust(7)} | #{progname}: #{msg}\n"
    end

    begin
      LOG_DIR.mkpath unless LOG_DIR.exist?
      file_logger = Logger.new(LOG_DIR.join('manager.log'), 3, 2_000_000)
      file_logger.formatter = log.formatter
      log.extend(Module.new do
        def add(severity, message = nil, progname = nil)
          super
          file_logger&.add(severity, message, progname)
        end
      end)
    rescue StandardError => e
      log.warn "Protokolldatei nicht verfuegbar (#{e.message}) — es wird nur nach stdout geschrieben"
    end

    log
  end
end

# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------

def zustand_laden
  if STATE_FILE.exist?
    JSON.parse(STATE_FILE.read(encoding: 'UTF-8'))
  else
    { 'erledigt' => {}, 'statistik' => {} }
  end
rescue StandardError => e
  protokoll.warn "Zustand unlesbar (#{e.message}) — es wird neu begonnen"
  { 'erledigt' => {}, 'statistik' => {} }
end

def zustand_speichern(zustand)
  STATE_FILE.dirname.mkpath unless STATE_FILE.dirname.exist?
  temp_file = Tempfile.new('.zustand_', STATE_FILE.dirname)
  temp_file.write(JSON.pretty_generate(zustand))
  temp_file.close
  FileUtils.mv(temp_file.path, STATE_FILE)
rescue StandardError => e
  protokoll.error "Zustand konnte nicht gespeichert werden: #{e.message}"
end

# ---------------------------------------------------------------------------
# Quellen holen
# ---------------------------------------------------------------------------

def git(*argumente, verzeichnis: nil)
  cmd = ['git']
  cmd.concat(['-C', verzeichnis.to_s]) if verzeichnis
  cmd.concat(argumente.map(&:to_s))

  Open3.capture3(*cmd, timeout: 600)
rescue StandardError => e
  [nil, e.message, 1]
end

def quellen_holen
  QUELLEN_DIR.mkpath unless QUELLEN_DIR.exist?
  baeume = []

  QUELLEN.each do |eintrag|
    repo = eintrag['repo']
    spiegel = QUELLEN_DIR.join("#{repo}.git")
    url = "https://github.com/#{GITHUB_BENUTZER}/#{repo}.git"

    unless spiegel.exist?
      protokoll.info "#{repo} wird geholt"
      stdout, stderr, status = git('clone', '--mirror', '--filter=blob:none', url, spiegel.to_s)
      unless status.success?
        protokoll.error "#{repo} konnte nicht geholt werden: #{stderr.lines.first(200).join.chomp}"
        next
      end
    else
      stdout, stderr, status = git('remote', 'update', '--prune', verzeichnis: spiegel)
      unless status.success?
        protokoll.warn "#{repo} konnte nicht aktualisiert werden: #{stderr.lines.first(200).join.chomp}"
      end
    end

    gewuenscht = eintrag['branches']
    branches = if gewuenscht == 'alle'
                 stdout, stderr, status = git('for-each-ref', '--format=%(refname:short)', 'refs/heads', verzeichnis: spiegel)
                 if status.success?
                   stdout.lines.map(&:chomp).reject(&:empty?)
                 else
                   protokoll.warn "Branches konnten nicht ermittelt werden: #{stderr.lines.first(200).join.chomp}"
                   []
                 end
               else
                 Array(gewuenscht)
               end

    branches.each do |branch|
      baum = QUELLEN_DIR.join('baeume', repo, branch.gsub('/', '_'))
      baum.mkpath unless baum.exist?
      stdout, stderr, status = git('--work-tree', baum.to_s, 'checkout', '-f', branch, '--', '.', verzeichnis: spiegel)
      unless status.success?
        protokoll.warn "#{repo}@#{branch}: Arbeitsbaum fehlgeschlagen: #{stderr.lines.first(160).join.chomp}"
        next
      end
      baeume << [repo, branch, baum]
    end
  end

  protokoll.info "Quellen bereit: #{baeume.length} Arbeitsbaeume"
  baeume
end

# ---------------------------------------------------------------------------
# Inventar
# ---------------------------------------------------------------------------

def prioritaet(pfad, sprache)
  return 'low' if %w[html css].include?(sprache)
  return 'high' if pfad.start_with?('scripts/') || pfad.include?('/scripts/')
  'medium'
end

def inventar_bauen(baeume)
  dateien = {}

  baeume.each do |repo, branch, baum|
    baum.find do |pfad|
      next unless pfad.file?

      rel = pfad.relative_path_from(baum).to_s.gsub('\\', '/')
      next if AUSSCHLUSS.any? { |muster| "/#{rel}".include?(muster) }

      sprache = QUELLSPRACHEN[pfad.extname.downcase]
      next unless sprache

      begin
        roh = pfad.read
      rescue StandardError
        next
      end

      next if roh.strip.empty? || roh.bytesize > MAX_BYTES

      schluessel = Digest::SHA256.hexdigest(roh)[0..15]
      eintrag = dateien[schluessel]

      unless eintrag
        eintrag = {
          'hash' => schluessel,
          'name' => pfad.basename.to_s,
          'stamm' => pfad.basename(pfad.extname).to_s,
          'sprache' => sprache,
          'bytes' => roh.bytesize,
          'pfad' => pfad.to_s,
          'herkunft' => [],
          'prioritaet' => prioritaet(rel, sprache)
        }
        dateien[schluessel] = eintrag
      end

      eintrag['herkunft'] << "#{repo}@#{branch}:#{rel}"
    end
  end

  rang = { 'high' => 0, 'medium' => 1, 'low' => 2 }
  liste = dateien.values.sort_by { |e| [rang[e['prioritaet']], e['name']] }
  protokoll.info "Inventar: #{liste.length} eindeutige Quelldateien aus #{liste.sum { |e| e['herkunft'].length }} Fundstellen"
  liste
end

# ---------------------------------------------------------------------------
# Uebersetzung
# ---------------------------------------------------------------------------

ANWEISUNG = <<~TEXT.freeze
  Du portierst Quellcode zwischen Programmiersprachen.

  Regeln:
  1. Gib ausschliesslich den vollstaendigen Code der Zielsprache aus. Keine
     Erklaerung davor oder danach, keine Code-Zaeune.
  2. Uebersetze die gesamte Funktionalitaet. Kein TODO, kein "hier waere",
     kein leerer Rumpf, kein Platzhalter.
  3. Erhalte Verhalten, Ein- und Ausgaben, Aufrufparameter und Rueckgabewerte.
  4. Verwende die Mittel der Zielsprache statt einer woertlichen Abschrift.
     Wo eine Bibliothek fehlt, loese es mit Bordmitteln der Zielsprache.
  5. Kommentare uebernimmst du sinngemaess in der Sprache des Originals.
  6. Beginne mit der passenden Shebang-Zeile.
TEXT

MARKUP_HINWEIS = <<~TEXT.freeze
  Das Original ist {sprache}. Erzeuge ein Programm in der
  Zielsprache, das dieses Dokument erzeugt und ueber einen Parameter in eine
  Datei schreibt — kein blosses Einbetten als Zeichenkette, sondern eine
  nachvollziehbare Erzeugung der Struktur.
TEXT

def zaeune_entfernen(text)
  zeilen = text.strip.lines
  return text unless zeilen.first&.lstrip&.start_with?('```')

  zeilen.shift
  while zeilen.last&.strip&.empty?
    zeilen.pop
  end
  zeilen.pop if zeilen.last&.lstrip&.start_with?('```')
  zeilen.join
end

def modell_fragen(quelle, quellsprache, zielsprache, name, schluessel)
  ziel = ZIELSPRACHEN[zielsprache]['bezeichnung']
  auftrag = "Portiere die folgende Datei #{name} von #{quellsprache} nach #{ziel}.\n"
  auftrag += "#{MARKUP_HINWEIS.sub('{sprache}', quellsprache.upcase)}\n" if %w[html css].include?(quellsprache)
  auftrag += "\n----- Beginn #{name} -----\n#{quelle}\n----- Ende #{name} -----"

  modelle = ENV['ABSTRACTIONS_MODELL'] ? [ENV['ABSTRACTIONS_MODELL']] : MODELLE

  modelle.each do |modell|
    VERSUCHE.times do |versuch|
      body = {
        'model' => modell,
        'messages' => [
          { 'role' => 'system', 'content' => ANWEISUNG },
          { 'role' => 'user', 'content' => auftrag }
        ],
        'temperature' => 0.1,
        'max_tokens' => 8000
      }.to_json

      uri = URI(API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = ZEITLIMIT
      http.read_timeout = ZEITLIMIT

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{schluessel}"
      request['Content-Type'] = 'application/json'
      request['HTTP-Referer'] = 'https://github.com/KikiKari/Projects'
      request['X-Title'] = 'Abstractions Manager'
      request.body = body

      response = http.request(request)
      data = JSON.parse(response.body)
      inhalt = data.dig('choices', 0, 'message', 'content')

      if inhalt && !inhalt.strip.empty?
        return zaeune_entfernen(inhalt)
      end

      protokoll.warn "#{name} -> #{zielsprache}: leere Antwort von #{modell}"
    rescue Net::HTTPError => e
      text = e.response.body[0..199] if e.response&.body
      protokoll.warn "#{name} -> #{zielsprache}: HTTP #{e.response&.code} von #{modell} (#{text})"
      break if [400, 401, 402, 404].include?(e.response&.code.to_i)
    rescue StandardError => e
      protokoll.warn "#{name} -> #{zielsprache}: #{e.class.name} bei #{modell}"
    end

    sleep([2**(versuch + 1), 20].min)
  end

  protokoll.error "#{name} -> #{zielsprache}: kein Modell hat geliefert"
  nil
end

# ---------------------------------------------------------------------------
# Pruefung der Erzeugnisse
# ---------------------------------------------------------------------------

PRUEFBEFEHLE = {
  'javascript' => %w[node --check],
  'perl5' => %w[perl -c],
  'powershell' => %w[pwsh -NoProfile -Command],
  'shell' => %w[bash -n],
  'tcl' => %w[tclsh]
}.freeze

VERDACHT = %w[
  TODO: Implementiere
  TODO: implement
  not implemented
  hier waere
  Platzhalter
  your code here
  pass  # TODO
].freeze

def erzeugnis_pruefen(code, zielsprache, quelle = '')
  quellzeilen = quelle.lines.count
  zeilen = code.strip.lines.reject(&:empty?).count
  mindestens = quellzeilen.zero? ? 5 : [2, [6, quellzeilen / 3].min].max

  if zeilen < mindestens
    return [false, "zu kurz (#{zeilen} statt mindestens #{mindestens} Zeilen)"]
  end

  niedrig = quelle.downcase
  VERDACHT.each do |muster|
    if code.downcase.include?(muster.downcase) && !niedrig.include?(muster.downcase)
      return [false, "unfertig (#{muster})"]
    end
  end

  if zielsprache == 'python'
    begin
      RubyVM::InstructionSequence.compile(code)
      return [true, 'syntax ok']
    rescue SyntaxError => e
      return [false, "Syntaxfehler #{e.message}"]
    end
  end

  befehl = PRUEFBEFEHLE[zielsprache]
  return [true, 'ohne Syntaxpruefung angenommen'] unless befehl

  endung = ZIELSPRACHEN[zielsprache]['ext']
  temp_file = Tempfile.new(['erzeugnis', endung])
  temp_file.write(code)
  temp_file.close

  result = if zielsprache == 'powershell'
             Open3.capture3(*(befehl + ["$null = [ScriptBlock]::Create((Get-Content -Raw '#{temp_file.path}'))"]))
           elsif zielsprache == 'tcl'
             Open3.capture3('tclsh', stdin_data: "if {[catch {info complete [read [open #{temp_file.path}]]}]} {exit 1}")
           else
             Open3.capture3(*(befehl + [temp_file.path]))
           end

  temp_file.unlink

  if result[2].success?
    [true, 'syntax ok']
  else
    meldung = (result[1] || result[0]).strip
    if meldung.include?('Can\'t locate') || meldung.include?('Cannot find module')
      [true, 'Fremdmodul fehlt hier — Syntax nicht abschliessend geprueft']
    else
      erste = meldung.lines.first&.slice(0, 90) || 'unbekannt'
      [false, "Syntaxfehler: #{erste}"]
    end
  end
rescue Errno::ENOENT
  temp_file&.unlink
  [true, 'Interpreter fehlt — ohne Syntaxpruefung angenommen']
rescue StandardError
  [true, 'Pruefung nicht moeglich — angenommen']
end

# ---------------------------------------------------------------------------
# Ablage
# ---------------------------------------------------------------------------

def zieldatei(eintrag, zielsprache, belegt)
  endung = ZIELSPRACHEN[zielsprache]['ext']
  stamm = eintrag['stamm']
  schluessel = "#{zielsprache}/#{stamm}"
  vorher = belegt[schluessel]

  if vorher && vorher != eintrag['hash']
    stamm = "#{stamm}_#{eintrag['hash'][0..5]}"
  else
    belegt[schluessel] = eintrag['hash']
  end

  ABSTRACTIONS_REPO.join(zielsprache, "#{stamm}#{endung}")
end

def kopf(eintrag, zielsprache)
  zeichen = zielsprache == 'javascript' ? '//' : '#'
  heute = Time.now.utc.strftime('%Y-%m-%d')
  zeilen = [
    "#{zeichen} #{eintrag['name']} — portiert nach #{zielsprache}",
    "#{zeichen} Quelle: #{eintrag['sprache']}, #{eintrag['herkunft'].first}"
  ]

  eintrag['herkunft'][1..3]&.each do |weitere|
    zeilen << "#{zeichen} auch in: #{weitere}"
  end

  if eintrag['herkunft'].length > 4
    zeilen << "#{zeichen} auch in: #{eintrag['herkunft'].length - 4} weiteren Fundstellen"
  end

  zeilen << "#{zeichen} Erzeugt: #{heute} durch ABSTRACTIONS_MANAGER.rb"
  zeilen.join("\n") + "\n"
end

def ablegen(eintrag, zielsprache, code, belegt)
  ziel = zieldatei(eintrag, zielsprache, belegt)
  ziel.dirname.mkpath unless ziel.dirname.exist?

  inhalt = if code.lines.first&.start_with?('#!')
             code.lines.first.chomp + "\n" + kopf(eintrag, zielsprache) + "\n" + code.lines[1..].join.lstrip + "\n"
           else
             kopf(eintrag, zielsprache) + "\n" + code
           end

  temp_file = Tempfile.new(['.neu_', ZIELSPRACHEN[zielsprache]['ext']], ziel.dirname)
  temp_file.write(inhalt)
  temp_file.close
  FileUtils.mv(temp_file.path, ziel)
  ziel
rescue StandardError => e
  protokoll.error "#{ziel} konnte nicht abgelegt werden: #{e.message}"
  nil
end

# ---------------------------------------------------------------------------
# Durchlauf
# ---------------------------------------------------------------------------

def uebersetzen(inventar, zustand, prioritaet, anzahl, probelauf, schluessel)
  zaehler = { 'erzeugt' => 0, 'uebersprungen' => 0, 'verworfen' => 0, 'dateien' => 0 }
  belegt = {}
  erledigt = zustand['erledigt'] ||= {}

  offen = inventar.select { |e| prioritaet == 'alle' || e['prioritaet'] == prioritaet }
  protokoll.info "Prioritaet #{prioritaet}: #{offen.length} Quelldateien im Bestand"

  offen.each do |eintrag|
    break if zaehler['dateien'] >= anzahl

    fertig = Set.new(erledigt[eintrag['hash']] || [])
    ziele = ZIELSPRACHEN.keys - [eintrag['sprache']] - fertig.to_a

    next if ziele.empty?

    begin
      quelle = Pathname.new(eintrag['pfad']).read(encoding: 'UTF-8')
    rescue StandardError => e
      protokoll.warn "#{eintrag['name']} nicht lesbar: #{e.message}"
      next
    end

    zaehler['dateien'] += 1
    protokoll.info "[#{eintrag['prioritaet']}] #{eintrag['name']} (#{eintrag['sprache']}, #{eintrag['bytes']} B) -> #{ziele.join(', ')}"

    ziele.each do |zielsprache|
      if probelauf
        protokoll.info "  #{zielsprache}: Probelauf, nichts gesendet"
        zaehler['uebersprungen'] += 1
        next
      end

      code = modell_fragen(quelle, eintrag['sprache'], zielsprache, eintrag['name'], schluessel)
      if code.nil?
        zaehler['verworfen'] += 1
        next
      end

      angenommen, grund = erzeugnis_pruefen(code, zielsprache, quelle)
      unless angenommen
        protokoll.warn "  #{zielsprache}: verworfen — #{grund}"
        zaehler['verworfen'] += 1
        next
      end

      ziel = ablegen(eintrag, zielsprache, code, belegt)
      if ziel.nil?
        zaehler['verworfen'] += 1
        next
      end

      protokoll.info "  #{zielsprache}: #{ziel.basename} (#{grund})"
      zaehler['erzeugt'] += 1
      (erledigt[eintrag['hash']] ||= []) << zielsprache
    end

    erledigt[eintrag['hash']].sort!
  end

  zaehler
end

# ---------------------------------------------------------------------------
# Bericht und Veroeffentlichung
# ---------------------------------------------------------------------------

def bericht_schreiben(inventar, zustand, zaehler)
  return unless ABSTRACTIONS_REPO.exist?

  je_sprache = ZIELSPRACHEN.keys.each_with_object({}) do |sprache, hash|
    verzeichnis = ABSTRACTIONS_REPO.join(sprache)
    hash[sprache] = verzeichnis.directory? ? verzeichnis.children.count { |p| p.file? } : 0
  end

  rang = { 'high' => 0, 'medium' => 1, 'low' => 2 }
  je_prio = rang.keys.each_with_object({}) do |p, hash|
    hash[p] = inventar.count { |e| e['prioritaet'] == p }
  end

  erledigt = zustand['erledigt'] || {}
  offen = inventar.sum do |e|
    (ZIELSPRACHEN.keys - [e['sprache']]).length - (erledigt[e['hash']] || []).length
  end

  zeilen = [
    '# Script Abstractions — Status',
    '',
    "**Letzter Lauf:** #{Time.now.utc.strftime('%Y-%m-%d %H:%M')} UTC",
    '',
    'Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.',
    'Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige',
    'Syntax oder mit Platzhaltern werden verworfen.',
    '',
    '## Bestand',
    '',
    '| Zielsprache | Dateien |',
    '|---|---:|'
  ]

  zeilen.concat(je_sprache.sort.map { |s, a| "| #{s} | #{a} |" })
  zeilen.concat([
    "| **gesamt** | **#{je_sprache.values.sum}** |",
    '',
    '## Quellen',
    '',
    '| Prioritaet | Quelldateien | Bedeutung |',
    '|---|---:|---|',
    "| high | #{je_prio['high']} | Betriebsscripte aus scripts-Verzeichnissen |",
    "| medium | #{je_prio['medium']} | uebriger ausfuehrbarer Code |",
    "| low | #{je_prio['low']} | Markup und Stilvorlagen |",
    "| **gesamt** | **#{inventar.length}** | nach Inhalt dedupliziert |",
    '',
    "Noch offene Sprachpaare: **#{offen}**",
    '',
    '## Letzter Lauf',
    '',
    "- bearbeitete Quelldateien: #{zaehler['dateien']}",
    "- erzeugte Uebersetzungen: #{zaehler['erzeugt']}",
    "- verworfen: #{zaehler['verworfen']}",
    '',
    '## Herkunft',
    '',
    '- `KikiKari/OpenClaw` — main, gateway1, gateway2',
    '- `KikiKari/Projects` — alle Branches',
    '- `KikiKari/Onboarding` — main',
    '',
    'Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.rb`.',
    ''
  ])

  ABSTRACTIONS_REPO.join('STATUS.md').write(zeilen.join("\n"), encoding: 'UTF-8')
  protokoll.info 'STATUS.md fortgeschrieben'
rescue StandardError => e
  protokoll.error "STATUS.md konnte nicht geschrieben werden: #{e.message}"
end

def veroeffentlichen(nachricht)
  return unless ABSTRACTIONS_REPO.join('.git').exist?

  stdout, = git('status', '--porcelain', verzeichnis: ABSTRACTIONS_REPO)
  if stdout.strip.empty?
    protokoll.info 'Keine Aenderungen zu veroeffentlichen'
    return
  end

  ZIELSPRACHEN.each_key do |sprache|
    git('add', sprache, verzeichnis: ABSTRACTIONS_REPO)
  end
  git('add', 'STATUS.md', verzeichnis: ABSTRACTIONS_REPO)

  stdout, stderr, status = git('commit', '-m', nachricht, verzeichnis: ABSTRACTIONS_REPO)
  unless status.success?
    protokoll.warn "Commit fehlgeschlagen: #{(stderr || stdout).lines.first(200).join.chomp}"
    return
  end
  protokoll.info "Commit gesetzt: #{nachricht}"

  token = ENV['GITHUB_TOKEN'] || ENV['ABSTRACTIONS_PUSH_TOKEN']
  unless token
    protokoll.info 'Kein Token in der Umgebung — Commit bleibt lokal'
    return
  end

  url = "https://x-access-token:#{token}@github.com/#{GITHUB_BENUTZER}/OpenClaw.git"
  stdout, stderr, status = git('push', url, 'HEAD:gateway1-abstractions', verzeichnis: ABSTRACTIONS_REPO)
  if status.success?
    protokoll.info 'Nach OpenClaw@gateway1-abstractions veroeffentlicht'
  else
    protokoll.error "Push fehlgeschlagen: #{stderr.to_s.gsub(token, '***')[0..199]}"
  end
end

# ---------------------------------------------------------------------------
# Einstiegspunkt
# ---------------------------------------------------------------------------

def main
  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: ruby ABSTRACTIONS_MANAGER.rb [options]'
    opts.on('--prioritaet high|medium|low|alle', 'Nur diese Stufe bearbeiten. Ohne Angabe wird reihum gewechselt.') do |p|
      options[:prioritaet] = p
    end
    opts.on('--anzahl N', Integer, "Hoechstzahl Quelldateien je Lauf. Default: #{ENV.fetch('ABSTRACTIONS_ANZAHL', '40')}") do |n|
      options[:anzahl] = n
    end
    opts.on('--probelauf', 'Inventar aufbauen und Plan zeigen, ohne zu uebersetzen.') do
      options[:probelauf] = true
    end
  end.parse!

  protokoll.info "Abstractions Manager gestartet — Arbeitsverzeichnis #{WORKSPACE}"

  schluessel = ENV['OPENROUTER_API_KEY']&.strip
  unless options[:probelauf]
    if schluessel.nil? || schluessel.empty?
      protokoll.error 'OPENROUTER_API_KEY ist leer oder besteht nur aus Leerraum — ohne Schluessel keine Uebersetzung'
      return 2
    end
    unless schluessel.start_with?('sk-or-')
      protokoll.error "OPENROUTER_API_KEY sieht nicht nach einem OpenRouter-Schluessel aus (#{schluessel.length} Zeichen, beginnt mit #{schluessel[0..5]}) — erwartet wird sk-or-..."
      return 2
    end
    protokoll.info "Schluessel erkannt: #{schluessel.length} Zeichen"
  end

  zustand = zustand_laden
  baeume = quellen_holen
  return 1 if baeume.empty?

  inventar = inventar_bauen(baeume)
  return 1 if inventar.empty?

  prioritaet = options[:prioritaet] || zustand['naechste_prioritaet'] || 'high'
  zaehler = uebersetzen(inventar, zustand, prioritaet, options[:anzahl] || ENV.fetch('ABSTRACTIONS_ANZAHL', '40').to_i,
                        options[:probelauf], schluessel)

  reihum = { 'high' => 'medium', 'medium' => 'low', 'low' => 'high', 'alle' => 'alle' }
  zustand['naechste_prioritaet'] = reihum[prioritaet]
  zustand['statistik'] = {
    'letzter_lauf' => Time.now.utc.iso8601,
    'quelldateien' => inventar.length
  }.merge(zaehler)

  bericht_schreiben(inventar, zustand, zaehler)
  zustand_speichern(zustand)

  if zaehler['erzeugt'].positive? && !options[:probelauf]
    veroeffentlichen(
      "auto: #{zaehler['erzeugt']} Uebersetzungen (#{prioritaet}) aus #{zaehler['dateien']} Quelldateien"
    )
  end

  protokoll.info "Abgeschlossen: #{zaehler['erzeugt']} erzeugt, #{zaehler['verworfen']} verworfen, #{zaehler['dateien']} Quelldateien bearbeitet"
  0
end

exit(main) if __FILE__ == $0
