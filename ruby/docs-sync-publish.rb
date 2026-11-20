#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "6a0ffa8af4706979ec3a30907176acc92cbfc918b98348b88f15435175c8c46c", "source_sha256": "51ab4d0a9d189c9eda9b410805bf753ea3df4406b70d58c8757e52b4551325b6", "target_language": "ruby"}
# docs-sync-publish.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-sync-publish.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'json'
require 'pathname'

HERE = File.dirname(__FILE__)
ROOT = File.expand_path(File.join(HERE, '..'))
SOURCE_DOCS_DIR = File.join(ROOT, 'docs')
SOURCE_CONFIG_PATH = File.join(SOURCE_DOCS_DIR, 'docs.json')

GENERATED_LOCALES = [
  {
    language: 'zh-Hans',
    dir: 'zh-CN',
    navFile: 'zh-Hans-navigation.json',
    tmFile: 'zh-CN.tm.jsonl',
    navMode: 'overlay'
  },
  {
    language: 'ja',
    dir: 'ja-JP',
    navFile: 'ja-navigation.json',
    tmFile: 'ja-JP.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'es',
    dir: 'es',
    navFile: 'es-navigation.json',
    tmFile: 'es.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'pt-BR',
    dir: 'pt-BR',
    navFile: 'pt-BR-navigation.json',
    tmFile: 'pt-BR.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'ko',
    dir: 'ko',
    navFile: 'ko-navigation.json',
    tmFile: 'ko.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'de',
    dir: 'de',
    navFile: 'de-navigation.json',
    tmFile: 'de.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'fr',
    dir: 'fr',
    navFile: 'fr-navigation.json',
    tmFile: 'fr.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'ar',
    dir: 'ar',
    navFile: 'ar-navigation.json',
    tmFile: 'ar.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'it',
    dir: 'it',
    navFile: 'it-navigation.json',
    tmFile: 'it.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'tr',
    dir: 'tr',
    navFile: 'tr-navigation.json',
    tmFile: 'tr.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'uk',
    dir: 'uk',
    navFile: 'uk-navigation.json',
    tmFile: 'uk.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'id',
    dir: 'id',
    navFile: 'id-navigation.json',
    tmFile: 'id.tm.jsonl',
    navMode: 'clone-en'
  },
  {
    language: 'pl',
    dir: 'pl',
    navFile: 'pl-navigation.json',
    tmFile: 'pl.tm.jsonl',
    navMode: 'clone-en'
  }
]

def parse_args(argv)
  args = {
    target: '',
    source_repo: '',
    source_sha: ''
  }

  index = 0
  while index < argv.length
    part = argv[index]
    case part
    when '--target'
      args[:target] = argv[index + 1] || ''
      index += 1
    when '--source-repo'
      args[:source_repo] = argv[index + 1] || ''
      index += 1
    when '--source-sha'
      args[:source_sha] = argv[index + 1] || ''
      index += 1
    else
      raise "unknown arg: #{part}"
    end
    index += 1
  end

  if args[:target].empty?
    raise 'missing --target'
  end

  args
end

def run(command, args, options = {})
  Dir.chdir(ROOT) do
    system(command, *args)
    raise "Command failed: #{command}" unless $?.success?
  end
end

def ensure_dir(dir_path)
  FileUtils.mkdir_p(dir_path)
end

def read_json(file_path)
  JSON.parse(File.read(file_path))
end

def write_json(file_path, value)
  ensure_dir(File.dirname(file_path))
  File.write(file_path, "#{JSON.pretty_generate(value)}\n")
end

def prefix_locale_page(entry, locale_dir)
  if entry.is_a?(String)
    return "#{locale_dir}/#{entry}"
  end
  if entry.is_a?(Array)
    return entry.map { |item| prefix_locale_page(item, locale_dir) }
  end
  if !entry || !entry.is_a?(Hash)
    return entry
  end

  clone = entry.dup
  if clone[:page].is_a?(String)
    clone[:page] = "#{locale_dir}/#{clone[:page]}"
  end
  if clone[:pages].is_a?(Array)
    clone[:pages] = clone[:pages].map { |item| prefix_locale_page(item, locale_dir) }
  end
  clone
end

def clone_english_language_nav(english_nav, locale)
  if !english_nav
    raise 'docs/docs.json is missing navigation.languages.en'
  end
  
  result = english_nav.dup
  result[:language] = locale[:language]
  
  if english_nav[:tabs].is_a?(Array)
    result[:tabs] = english_nav[:tabs].map do |tab|
      tab_clone = tab.dup
      if tab[:pages].is_a?(Array)
        tab_clone[:pages] = tab[:pages].map { |entry| prefix_locale_page(entry, locale[:dir]) }
      end
      if tab[:groups].is_a?(Array)
        tab_clone[:groups] = tab[:groups].map do |group|
          group_clone = group.dup
          if group[:pages].is_a?(Array)
            group_clone[:pages] = group[:pages].map { |entry| prefix_locale_page(entry, locale[:dir]) }
          end
          group_clone
        end
      end
      tab_clone
    end
  end
  
  result
end

def compose_locale_nav(locale, english_nav)
  if locale[:navMode] == 'clone-en'
    return clone_english_language_nav(english_nav, locale)
  end
  read_json(File.join(SOURCE_DOCS_DIR, '.i18n', locale[:navFile]))
end

def compose_docs_config
  source_config = read_json(SOURCE_CONFIG_PATH)
  languages = source_config.dig('navigation', 'languages')

  if !languages.is_a?(Array)
    raise 'docs/docs.json is missing navigation.languages'
  end

  english_nav = languages.find { |entry| entry&.dig('language') == 'en' }
  generated_language_set = GENERATED_LOCALES.map { |entry| entry[:language] }.to_set
  without_generated = languages.select { |entry| !generated_language_set.include?(entry&.dig('language')) }
  en_index = without_generated.index { |entry| entry&.dig('language') == 'en' }
  generated = GENERATED_LOCALES.map { |entry| compose_locale_nav(entry, english_nav) }
  
  if en_index.nil?
    without_generated.concat(generated)
  else
    without_generated.insert(en_index + 1, *generated)
  end

  result = source_config.dup
  result['navigation'] = source_config['navigation'].dup
  result['navigation']['languages'] = without_generated
  result
end

def sync_docs_tree(target_root)
  target_docs_dir = File.join(target_root, 'docs')
  ensure_dir(target_docs_dir)

  locale_filters = []
  GENERATED_LOCALES.each do |entry|
    locale_filters.concat([
      '--filter', "P #{entry[:dir]}/",
      '--filter', "P .i18n/#{entry[:tmFile]}",
      '--exclude', "#{entry[:dir]}/",
      '--exclude', ".i18n/#{entry[:tmFile]}"
    ])
  end

  rsync_args = [
    '-a',
    '--delete',
    '--filter', 'P .i18n/README.md',
    '--exclude', '.i18n/README.md'
  ] + locale_filters + ["#{SOURCE_DOCS_DIR}/", "#{target_docs_dir}/"]

  run('rsync', rsync_args)

  GENERATED_LOCALES.each do |locale|
    source_tm_path = File.join(SOURCE_DOCS_DIR, '.i18n', locale[:tmFile])
    target_tm_path = File.join(target_docs_dir, '.i18n', locale[:tmFile])
    if !File.exist?(target_tm_path) && File.exist?(source_tm_path)
      ensure_dir(File.dirname(target_tm_path))
      FileUtils.cp(source_tm_path, target_tm_path)
    end
  end

  write_json(File.join(target_docs_dir, 'docs.json'), compose_docs_config)
end

def write_sync_metadata(target_root, args)
  metadata = {
    'repository' => args[:source_repo] || '',
    'sha' => args[:source_sha] || '',
    'syncedAt' => Time.now.utc.iso8601
  }
  write_json(File.join(target_root, '.openclaw-sync', 'source.json'), metadata)
end

def main
  args = parse_args(ARGV)
  target_root = File.expand_path(args[:target])

  if !File.exist?(target_root)
    raise "target does not exist: #{target_root}"
  end

  sync_docs_tree(target_root)
  write_sync_metadata(target_root, args)
end

main if __FILE__ == $0
