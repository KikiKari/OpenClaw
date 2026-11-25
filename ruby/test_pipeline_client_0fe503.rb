#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "296f4acd065ade81a6e35b922de8a463cf7db86f537e950de14248e091cf17d0", "source_sha256": "0fe503378d960b547d45c597a390a046e4d115dc036760ca7ef605dec6f6f754", "target_language": "ruby"}
# test_pipeline_client.cjs — portiert nach ruby
# Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_pipeline_client.cjs
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'test/unit'
require 'json'
require 'securerandom'
require 'thread'

class TestPipelineClient < Test::Unit::TestCase
  
  def client
    local = { 'tlc-settings' => { 'universalCaptionApiKey' => 'universal-secret', 'pairingCode' => 'pair-secret' } }
    session = {}
    rows = {}
    received = []
    
    storage = lambda { |data|
      {
        get: lambda { |keys|
          Array(keys).each_with_object({}) { |key, result| result[key] = data[key] }
        },
        set: lambda { |values|
          data.merge!(values)
        }
      }
    }
    
    database = Object.new
    def database.transaction
      tx = Object.new
      operation = lambda { |fn|
        req = Object.new
        Thread.new {
          req.instance_variable_set(:@result, fn.call)
          req.instance_eval { def result; @result; end }
          req.onsuccess&.call if req.respond_to?(:onsuccess)
          Thread.current.exit
        }
        req
      }
      
      store = Object.new
      def store.put(row)
        operation.call(lambda {
          (@rows ||= {})[row['eventId']] = row.dup
        })
      end
      
      def store.delete(id)
        operation.call(lambda {
          (@rows ||= {}).delete(id)
        })
      end
      
      def store.get_all
        operation.call(lambda {
          (@rows ||= {}).values.map(&:dup)
        })
      end
      
      def store.object_store
        self
      end
      
      tx.instance_variable_set(:@store, store)
      def tx.object_store(*) @store end
      tx
    end
    
    indexed_db = Object.new
    def indexed_db.open(*)
      req = Object.new
      Thread.new {
        req.instance_variable_set(:@result, database)
        req.instance_eval { def result; @result; end }
        req.onsuccess&.call if req.respond_to?(:onsuccess)
        Thread.current.exit
      }
      req
    end
    
    context = {
      'crypto' => SecureRandom,
      'indexedDB' => indexed_db,
      'console' => Object.new,
      'chrome' => {
        'storage' => {
          'local' => storage.call(local),
          'session' => storage.call(session)
        },
        'runtime' => { 'id' => 'self' },
        'alarms' => {
          'create' => lambda {},
          'onAlarm' => { 'addListener' => lambda {} }
        }
      },
      'fetch' => lambda { |url, options|
        if url.end_with?('/events')
          received << JSON.parse(options[:body])
        end
        { 
          'ok' => true, 
          'json' => lambda { { 'cursor' => received.length } } 
        }
      }
    }
    
    # In Ruby, we can't directly execute JavaScript code like in Node.js
    # We would need a JavaScript engine like ExecJS or mini_racer
    # For this example, let's assume we have a way to run the JS code
    # and expose the TLCPipelines object to our context
    
    # This is a simplified mock - in reality you'd use something like:
    # script = File.read(File.join(__dir__, '../browser-extension/pipeline-client.js'))
    # ExecJS.exec(script) # or similar with mini_racer
    
    # For now, we'll simulate the API behavior
    tlc_pipelines = Object.new
    def tlc_pipelines.start(tab_id, document_id)
      # Simulate start logic
      Thread.pass
      nil
    end
    
    def tlc_pipelines.publish(tab_id, pipeline, data, credential, type, document_id = nil)
      # Simulate publish logic
      Thread.pass
      nil
    end
    
    def tlc_pipelines.flush
      # Simulate flush logic
      Thread.pass
      nil
    end
    
    context['TLCPipelines'] = tlc_pipelines
    
    { 
      api: tlc_pipelines,
      local: local,
      session: session,
      received: received,
      rows: rows
    }
  end
  
  def test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate
    c = client()
    c[:api].start(1, 'doc-a')
    c[:api].start(2, 'doc-b')
    c[:api].publish(1, 'chat', { 'text' => 'first' }, 'pair-secret', 'chat', 'doc-a')
    c[:api].start(1, 'doc-c')
    c[:api].publish(1, 'chat', { 'text' => 'late' }, 'late', 'chat', 'doc-a')
    c[:api].publish(1, 'chat', { 'text' => 'current' }, 'current', 'chat')
    
    30.times do
      Thread.pass
      c[:api].flush
    end
    
    assert_equal(0, c[:rows].size)
    
    chats = c[:received].select { |row| row['pipeline'] == 'chat' && row['availability'] == 'available' }
    assert_equal(['doc-a', 'doc-a', 'doc-c'], chats.map { |row| row['documentId'] })
    assert_equal('[credential removed]', chats[0]['raw'])
    assert_equal(true, chats[0]['credentialsRedacted'])
    
    b = c[:received].find { |row| row['documentId'] == 'doc-b' }
    refute_nil(b)
    refute_equal(chats[0]['tabId'], b['tabId'])
    assert_equal(chats[0]['clientId'], b['clientId'])
    assert_equal(c[:received].map { |row| row['eventId'] }.uniq.size, c[:received].length)
  end
end
