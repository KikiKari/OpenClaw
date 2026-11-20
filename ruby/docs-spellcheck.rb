#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f7ea49104e31a731b2cd481594c6418573e6f73ecc077962468905dc445af592", "source_sha256": "d563770ee41496760efbfdbb5c3e2c054ecf84de1c5e8eb2fc7cd2ad260b16ce", "target_language": "ruby"}
# docs-spellcheck.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docs-spellcheck.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

mode = ARGV[0] || ''
write_flag = []
write_flag = ['-w'] if mode == '--write'

args = [
  'README.md',
  'docs',
  '--skip=*.png,*.jpg,*.jpeg,*.gif,*.svg',
  '-D',
  '-',
  '-D',
  'scripts/codespell-dictionary.txt',
  '-I',
  'scripts/codespell-ignore.txt'
] + write_flag

# Check if codespell is available
if system('command', '-v', 'codespell', out: File::NULL)
  exec('codespell', *args)
  exit(0)
end

# Check if python3 is available
if system('command', '-v', 'python3', out: File::NULL)
  # Try to install codespell with --break-system-packages first, fallback without
  install_cmd = 'python3 -m pip install --user --disable-pip-version-check --break-system-packages codespell'
  unless system("#{install_cmd} >/dev/null 2>&1")
    install_cmd = 'python3 -m pip install --user --disable-pip-version-check codespell'
    system("#{install_cmd} >/dev/null 2>&1")
  end

  # Get user bin directory from Python
  user_bin = `python3 -c "import site; print(f'{site.USER_BASE}/bin')"`.strip
  codespell_path = File.join(user_bin, 'codespell')

  if File.executable?(codespell_path)
    exec(codespell_path, *args)
    exit(0)
  end
end

# If we get here, neither codespell nor python3 was found
STDERR.puts 'codespell unavailable: install codespell or python3'
exit(1)
