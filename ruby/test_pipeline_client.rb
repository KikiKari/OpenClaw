#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "622c99308b60b91e21945b026e0041b2d295c4b3ab0df1254c3573df6db19747", "source_sha256": "e28f06911ddc1d346df8de8f09de3cdbd61d7cfd8fed3f4f2a080d921fb0d448", "target_language": "ruby"}
# test_pipeline_client.cjs — portiert nach ruby
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_pipeline_client.cjs
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'test/unit'
require 'securerandom'
require 'json'
require 'pathname'

# Mock für Crypto API
class WebCryptoMock
  def getRandomValues(array)
    array.each_with_index { |_, i| array[i] = rand(256) }
  end
end

# Storage Mock
class StorageMock
  def initialize(data)
    @data = data
  end

  def get(keys)
    keys = [keys] unless keys.is_a?(Array)
    result = {}
    keys.each { |key| result[key] = @data[key] }
    result
  end

  def set(values)
    @data.merge!(values)
  end
end

# IndexedDB Mock
class IndexedDBMock
  class Transaction
    def initialize(rows)
      @rows = rows
    end

    def object_store(*)
      self
    end

    def put(row)
      @rows[row['eventId']] = Marshal.load(Marshal.dump(row))
      nil
    end

    def delete(id)
      @rows.delete(id)
      nil
    end

    def get_all
      @rows.values.map { |row| Marshal.load(Marshal.dump(row)) }
    end
  end

  def initialize(rows)
    @rows = rows
  end

  def transaction(*)
    Transaction.new(@rows)
  end
end

# Client Factory
def client
  local = { 'tlc-settings' => { 'universalCaptionApiKey' => 'universal-secret', 'pairingCode' => 'pair-secret' } }
  session = {}
  rows = {}
  received = []
  
  storage = ->(data) { StorageMock.new(data) }
  database = IndexedDBMock.new(rows)
  indexed_db = database
  
  # Context für Pipeline-Client
  context = {
    'crypto' => WebCryptoMock.new,
    'indexedDB' => indexed_db,
    'console' => STDOUT,
    'chrome' => {
      'storage' => {
        'local' => storage.call(local),
        'session' => storage.call(session)
      },
      'runtime' => { 'id' => 'self' },
      'alarms' => {
        'create' => ->(*) {},
        'onAlarm' => { 'addListener' => ->(*) {} }
      }
    },
    'fetch' => ->(url, options) {
      if url.end_with?('/events')
        received << JSON.parse(options[:body])
        { 'ok' => true, 'json' => -> { { 'cursor' => received.length } } }
      else
        { 'ok' => true, 'json' => -> { {} } }
      end
    }
  }

  # Lade und führe pipeline-client.js aus
  script_path = File.join(File.dirname(__FILE__), '../browser-extension/pipeline-client.js')
  script_content = File.read(script_path)
  
  # Evaluiere den JavaScript-ähnlichen Code im Kontext
  eval(script_content, binding)
  
  {
    'api' => TLCPipelines,
    'local' => local,
    'session' => session,
    'received' => received,
    'rows' => rows
  }
end

class TestPipelineClient < Test::Unit::TestCase
  def test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate
    c = client()
    
    c['api'].start(1, 'doc-a')
    c['api'].start(2, 'doc-b')
    c['api'].publish(1, 'chat', { 'text' => 'first' }, 'pair-secret', 'chat', 'doc-a')
    c['api'].start(1, 'doc-c')
    c['api'].publish(1, 'chat', { 'text' => 'late' }, 'late', 'chat', 'doc-a')
    c['api'].publish(1, 'chat', { 'text' => 'current' }, 'current', 'chat')
    
    # Warte auf asynchrone Operationen
    30.times do
      sleep(0.001) # Minimaler Sleep für Event Loop
      c['api'].flush() if c['api'].respond_to?(:flush)
    end
    
    assert_equal(0, c['rows'].size)
    
    chats = c['received'].select { |row| row['pipeline'] == 'chat' && row['availability'] == 'available' }
    assert_equal(['doc-a', 'doc-a', 'doc-c'], chats.map { |row| row['documentId'] })
    assert_equal('[credential removed]', chats[0]['raw'])
    assert_equal(true, chats[0]['credentialsRedacted'])
    
    b = c['received'].find { |row| row['documentId'] == 'doc-b' }
    refute_nil(b)
    refute_equal(chats[0]['tabId'], b['tabId'])
    assert_equal(chats[0]['clientId'], b['clientId'])
    
    event_ids = c['received'].map { |row| row['eventId'] }
    assert_equal(event_ids.uniq.size, event_ids.size)
  end
end
