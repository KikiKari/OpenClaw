#!/usr/bin/env python3
# test_hook_recovery.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_hook_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_hook_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_hook_recovery.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_hook_recovery.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import unittest
import asyncio
from collections import deque
import struct

class TestHookRecovery(unittest.TestCase):
    
    def harness(self):
        now = 1000
        serial = 0
        identity = 'stream-a'
        timers = {}
        events = []
        sockets = []
        
        def uuid():
            nonlocal serial
            serial += 1
            return str(serial)
            
        def emit(e):
            events.append(e)
            
        def later(fn, ms):
            nonlocal serial
            serial += 1
            timer_id = serial
            timers[timer_id] = {'at': now + ms, 'fn': fn}
            return timer_id
            
        def cancel(timer_id):
            if timer_id in timers:
                del timers[timer_id]
                return True
            return False
            
        def connect(template, token):
            s = {'token': token, 'closed': False}
            def close():
                s['closed'] = True
            s['close'] = close
            sockets.append(s)
            return s
            
        controller = create_controller({
            'now': lambda: now,
            'uuid': uuid,
            'identity': lambda: identity,
            'emit': emit,
            'later': later,
            'cancel': cancel,
            'connect': connect
        })
        
        def tick(ms):
            nonlocal now
            target = now + ms
            while True:
                next_timer = None
                next_at = float('inf')
                for tid, t in list(timers.items()):
                    if t['at'] <= target and t['at'] < next_at:
                        next_at = t['at']
                        next_timer = (tid, t)
                if not next_timer:
                    break
                now = next_timer[1]['at']
                fn = next_timer[1]['fn']
                del timers[next_timer[0]]
                fn()
            now = target
            
        def stream(v):
            nonlocal identity
            identity = v
            controller.checkStream()
            
        def prime():
            controller.nativeConnected({'supported': True})
            controller.configure({'enabled': True, 'seconds': 3})
            controller.nativeDisconnected()
            
        return {
            'controller': controller,
            'tick': tick,
            'events': events,
            'sockets': sockets,
            'timers': timers,
            'stream': stream,
            'prime': prime
        }
    
    def test_hook_default_disabled_and_unverified_protocol_cannot_create_sockets(self):
        h = self.harness()
        h['controller'].nativeDisconnected()
        h['tick'](60000)
        self.assertEqual(len(h['sockets']), 0)
        h['controller'].configure({'enabled': True})
        h['tick'](60000)
        self.assertEqual(len(h['sockets']), 0)
        self.assertEqual(h['events'][-1]['phase'], 'unavailable')
        
    def test_five_synthetic_hook_failures_recover_without_any_media_navigation_capability(self):
        h = self.harness()
        h['prime']()
        for i in range(5):
            h['tick'](2999)
            self.assertEqual(len(h['sockets']), i)
            h['tick'](1)
            token = h['sockets'][-1]['token']
            h['controller'].stage(token, 'socket-open')
            h['tick'](200)
            h['controller'].stage(token, 'first-frame')
            h['tick'](100)
            h['controller'].stage(token, 'first-decoded-message')
            self.assertEqual(h['controller'].connected(token), True)
            self.assertEqual(h['events'][-1]['disconnectToDecodedMs'], 3300)
            h['controller'].nativeConnected({'supported': True})
            self.assertEqual(h['sockets'][-1]['closed'], True)
            h['controller'].nativeDisconnected()
            
    def test_open_alone_times_out_after_ten_seconds_one_socket_backoff_capped_at_30_seconds(self):
        h = self.harness()
        h['prime']()
        h['tick'](3000)
        for i in range(6):
            s = h['sockets'][-1]
            h['controller'].stage(s['token'], 'socket-open')
            h['tick'](9999)
            self.assertEqual(s['closed'], False)
            h['tick'](1)
            self.assertEqual(s['closed'], True)
            delay = h['events'][-1]['effectiveDelayMs']
            self.assertLessEqual(delay, 30000)
            h['tick'](delay)
            self.assertEqual(len([s for s in h['sockets'] if not s['closed']]), 1)
            
    def test_native_takeover_cancels_deadline_and_ignores_stale_socket_callbacks(self):
        h = self.harness()
        h['prime']()
        h['tick'](3000)
        token = h['sockets'][0]['token']
        h['controller'].nativeConnected({'supported': True})
        self.assertEqual(h['controller'].connected(token), False)
        h['controller'].failed(token, 'socket-close')
        h['tick'](60000)
        self.assertEqual(len(h['sockets']), 1)
        self.assertEqual(h['events'][-1]['phase'], 'native')
        
    def test_stream_switch_discards_template_and_cancels_scheduled_attempt(self):
        h = self.harness()
        h['prime']()
        h['stream']('stream-b')
        h['tick'](60000)
        self.assertEqual(len(h['sockets']), 0)
        h['controller'].nativeDisconnected()
        self.assertEqual(h['events'][-1]['phase'], 'unavailable')
        
    def test_disable_closes_owned_socket_and_policy_rejection_forbids_retries(self):
        h = self.harness()
        h['prime']()
        h['tick'](3000)
        h['controller'].configure({'enabled': False})
        self.assertEqual(h['sockets'][0]['closed'], True)
        h['tick'](60000)
        self.assertEqual(len(h['sockets']), 1)
        p = self.harness()
        p['prime']()
        p['tick'](3000)
        p['controller'].failed(p['sockets'][0]['token'], 'policy-rejected')
        p['tick'](60000)
        self.assertEqual(len(p['sockets']), 1)
        self.assertEqual(p['events'][-1]['phase'], 'unavailable')
        
    def test_disposed_document_never_reconnects_after_new_configuration(self):
        h = self.harness()
        h['prime']()
        h['controller'].dispose()
        h['controller'].configure({'enabled': True})
        h['tick'](60000)
        self.assertEqual(len(h['sockets']), 0)

def create_controller(deps):
    # Simplified implementation based on the JavaScript version
    state = {
        'configured': False,
        'enabled': False,
        'seconds': 0,
        'nativeSupported': False,
        'nativeConnected': False,
        'attempt': None,
        'sockets': {},
        'disposed': False
    }
    
    def checkStream():
        pass
        
    def configure(config):
        state['configured'] = True
        state['enabled'] = config.get('enabled', False)
        state['seconds'] = config.get('seconds', 0)
        scheduleAttempt()
        
    def nativeConnected(status):
        state['nativeSupported'] = status.get('supported', False)
        state['nativeConnected'] = True
        if state['attempt']:
            deps['cancel'](state['attempt'])
            state['attempt'] = None
            
    def nativeDisconnected():
        state['nativeConnected'] = False
        scheduleAttempt()
        
    def scheduleAttempt():
        if state['attempt']:
            deps['cancel'](state['attempt'])
            state['attempt'] = None
        if state['configured'] and state['enabled'] and not state['nativeConnected'] and not state['disposed']:
            state['attempt'] = deps['later'](attemptConnection, state['seconds'] * 1000)
            
    def attemptConnection():
        state['attempt'] = None
        if state['configured'] and state['enabled'] and not state['nativeConnected'] and not state['disposed']:
            token = deps['uuid']()
            socket = deps['connect']({}, token)
            state['sockets'][token] = socket
            
    def stage(token, phase):
        pass
        
    def connected(token):
        return token in state['sockets']
        
    def failed(token, reason):
        if token in state['sockets']:
            del state['sockets'][token]
            
    def dispose():
        state['disposed'] = True
        if state['attempt']:
            deps['cancel'](state['attempt'])
            state['attempt'] = None
            
    return {
        'checkStream': checkStream,
        'configure': configure,
        'nativeConnected': nativeConnected,
        'nativeDisconnected': nativeDisconnected,
        'stage': stage,
        'connected': connected,
        'failed': failed,
        'dispose': dispose
    }

class ProtoTest(unittest.TestCase):
    
    def test_ACK_and_heartbeat_encoder_round_trips_supported_dialect_and_rejects_malformed_controls(self):
        # Simplified tests for protocol encoding/decoding
        self.assertEqual(inspect_transport_control(encode_transport('hb'))['type'], 'hb')
        
        ack = inspect_transport_control(encode_transport('ack', '18446744073709551615', 'opaque'))
        self.assertEqual(ack['id'], '18446744073709551615')
        self.assertEqual(ack['payload'], 'opaque')
        
        self.assertIsNone(inspect_transport_control(encode_transport('ack', 0)))
        self.assertIsNone(inspect_transport_control(encode_transport('hb', 1)))
        self.assertIsNone(inspect_transport_control(bytes([255])))
        
        with self.assertRaises(ValueError):
            encode_transport('ack', -1)

def encode_transport(control_type, arg1=None, arg2=None):
    if control_type == 'hb':
        if arg1 is not None:
            return None
        return bytes([0x01])
    elif control_type == 'ack':
        if isinstance(arg1, int) and arg1 < 0:
            raise ValueError("Negative ID")
        if arg1 is None or arg2 is None:
            return None
        # Simplified encoding
        return bytes([0x02]) + str(arg1).encode() + b'\x00' + (arg2.encode() if isinstance(arg2, str) else arg2)
    return None

def inspect_transport_control(data):
    if not data or len(data) == 0:
        return None
    if data[0] == 0x01:
        if len(data) > 1:
            return None
        return {'type': 'hb'}
    elif data[0] == 0x02:
        try:
            null_idx = data.index(0, 1)
            id_str = data[1:null_idx].decode()
            payload = data[null_idx+1:].decode()
            return {'type': 'ack', 'id': id_str, 'payload': payload}
        except:
            return None
    return None

if __name__ == '__main__':
    unittest.main()
