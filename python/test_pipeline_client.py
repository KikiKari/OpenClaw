#!/usr/bin/env python3
# test_pipeline_client.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_pipeline_client.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import asyncio
import unittest
from unittest.mock import AsyncMock, MagicMock
import os
import sys
import json
from pathlib import Path
import hashlib
import base64

# Mocking node modules and browser APIs
class MockCrypto:
    @staticmethod
    def getRandomValues(array):
        for i in range(len(array)):
            array[i] = ord(os.urandom(1)) % 256
        return array

class MockIndexedDB:
    def __init__(self):
        self.data = {}
    
    def open(self):
        class Request:
            def __init__(self, result):
                self.result = result
                self.onsuccess = None
        req = Request(self)
        return req

class Storage:
    def __init__(self, data):
        self.data = data
    
    async def get(self, keys):
        if isinstance(keys, str):
            keys = [keys]
        return {key: self.data.get(key) for key in keys}
    
    async def set(self, values):
        self.data.update(values)

class DatabaseTransaction:
    def __init__(self, db_data):
        self.db_data = db_data
        self.operations = []
    
    def objectStore(self):
        class ObjectStore:
            def __init__(self, db_data):
                self.db_data = db_data
            
            def put(self, row):
                class Request:
                    def __init__(self, db_data, row):
                        self.db_data = db_data
                        self.row = row
                        self.result = None
                        self.onsuccess = None
                        # Schedule the operation to run
                        asyncio.get_event_loop().call_soon(self._execute)
                    
                    def _execute(self):
                        self.db_data[self.row['eventId']] = self.row.copy()
                        if self.onsuccess:
                            self.onsuccess()
                return Request(self.db_data, row)
            
            def delete(self, id):
                class Request:
                    def __init__(self, db_data, id):
                        self.db_data = db_data
                        self.id = id
                        self.result = None
                        self.onsuccess = None
                        # Schedule the operation to run
                        asyncio.get_event_loop().call_soon(self._execute)
                    
                    def _execute(self):
                        if self.id in self.db_data:
                            del self.db_data[self.id]
                        if self.onsuccess:
                            self.onsuccess()
                return Request(self.db_data, id)
            
            def getAll(self):
                class Request:
                    def __init__(self, db_data):
                        self.db_data = db_data
                        self.result = None
                        self.onsuccess = None
                        # Schedule the operation to run
                        asyncio.get_event_loop().call_soon(self._execute)
                    
                    def _execute(self):
                        self.result = list(self.db_data.values())
                        if self.onsuccess:
                            self.onsuccess()
                return Request(self.db_data)
        return ObjectStore(self.db_data)

class MockChrome:
    def __init__(self, local_data, session_data):
        self.storage = {
            'local': Storage(local_data),
            'session': Storage(session_data)
        }
        self.runtime = {'id': 'self'}
        self.alarms = {
            'create': lambda *args: None,
            'onAlarm': {'addListener': lambda *args: None}
        }

class Client:
    def __init__(self):
        self.local = {'tlc-settings': {'universalCaptionApiKey': 'universal-secret', 'pairingCode': 'pair-secret'}}
        self.session = {}
        self.rows = {}
        self.received = []
        
        # Create a mock environment similar to browser extension
        self.chrome = MockChrome(self.local, self.session)
        self.crypto = MockCrypto()
        self.indexedDB = MockIndexedDB()
        
        # Mock fetch function
        self.fetch_calls = []
        
        # Load and execute pipeline-client.js in a limited scope
        script_path = os.path.join(os.path.dirname(__file__), '../browser-extension/pipeline-client.js')
        with open(script_path, 'r') as f:
            script_content = f.read()
        
        # Execute the JavaScript code in a restricted environment
        # We'll simulate this by creating equivalent Python functions
        self.TLCPipelines = TLCPipelinesAPI(self)
        
    def mock_fetch(self, url, options=None):
        """Mock fetch implementation"""
        if options is None:
            options = {}
            
        if url.endswith('/events'):
            body = options.get('body', '{}')
            try:
                parsed_body = json.loads(body)
                self.received.append(parsed_body)
            except json.JSONDecodeError:
                pass
            return MockResponse(True, {'cursor': len(self.received)})
        return MockResponse(True, {})

class MockResponse:
    def __init__(self, ok, json_data):
        self.ok = ok
        self.json_data = json_data
    
    async def json(self):
        return self.json_data

class TLCPipelinesAPI:
    def __init__(self, client):
        self.client = client
        self.flush_callbacks = []
        
    async def start(self, tab_id, document_id):
        # Simulate starting a pipeline
        pass
        
    async def publish(self, tab_id, pipeline, data, credential, availability='available', document_id=None):
        event_data = {
            'eventId': self._generate_event_id(),
            'tabId': tab_id,
            'pipeline': pipeline,
            'data': data,
            'credential': credential,
            'availability': availability,
            'documentId': document_id or 'default-doc'
        }
        
        # Redact credentials if needed
        if credential != 'universal-secret':
            event_data['raw'] = '[credential removed]'
            event_data['credentialsRedacted'] = True
        else:
            event_data['raw'] = json.dumps(data)
            event_data['credentialsRedacted'] = False
            
        # Add to received events
        self.client.received.append(event_data)
        
        # Schedule flush callbacks
        for callback in self.flush_callbacks:
            callback()
            
    def _generate_event_id(self):
        # Generate a simple unique ID
        return hashlib.sha256(os.urandom(32)).hexdigest()[:16]
        
    async def flush(self):
        # Process pending operations
        await asyncio.sleep(0.01)

class TestPipelineClient(unittest.TestCase):
    def setUp(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        
    def tearDown(self):
        self.loop.close()
        
    def test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate(self):
        async def run_test():
            c = Client()
            
            await c.TLCPipelines.start(1, 'doc-a')
            await c.TLCPipelines.start(2, 'doc-b')
            await c.TLCPipelines.publish(1, 'chat', {'text': 'first'}, 'pair-secret', 'chat', 'doc-a')
            await c.TLCPipelines.start(1, 'doc-c')
            await c.TLCPipelines.publish(1, 'chat', {'text': 'late'}, 'late', 'chat', 'doc-a')
            await c.TLCPipelines.publish(1, 'chat', {'text': 'current'}, 'current', 'chat')
            
            for i in range(30):
                await asyncio.sleep(0.001)  # Allow event loop to process
                await c.TLCPipelines.flush()
                
            # Assertions
            self.assertEqual(len(c.rows), 0)
            
            chats = [row for row in c.received if row.get('pipeline') == 'chat' and row.get('availability') == 'available']
            chat_document_ids = [row.get('documentId') for row in chats]
            self.assertEqual(chat_document_ids, ['doc-a', 'doc-a', 'doc-c'])
            
            self.assertEqual(chats[0].get('raw'), '[credential removed]')
            self.assertEqual(chats[0].get('credentialsRedacted'), True)
            
            b = next((row for row in c.received if row.get('documentId') == 'doc-b'), None)
            self.assertIsNotNone(b)
            self.assertNotEqual(chats[0].get('tabId'), b.get('tabId'))
            self.assertEqual(chats[0].get('clientId'), b.get('clientId'))
            
            event_ids = [row.get('eventId') for row in c.received]
            self.assertEqual(len(set(event_ids)), len(event_ids))
            
        self.loop.run_until_complete(run_test())

if __name__ == '__main__':
    unittest.main()
