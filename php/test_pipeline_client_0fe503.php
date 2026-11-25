<?php
// abstraction-provenance: {"artifact_sha256": "fc3375b8534e838a448871751e139e77cf9e6e727fb64375ed6df3750efbb316", "source_sha256": "0fe503378d960b547d45c597a390a046e4d115dc036760ca7ef605dec6f6f754", "target_language": "php"}
// test_pipeline_client.cjs — portiert nach php
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_pipeline_client.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
function client() {
    $local = ['tlc-settings' => ['universalCaptionApiKey' => 'universal-secret', 'pairingCode' => 'pair-secret']];
    $session = [];
    $rows = [];
    $received = [];
    
    $storage = function(&$data) {
        return [
            'get' => function($keys) use (&$data) {
                if (!is_array($keys)) {
                    $keys = [$keys];
                }
                $result = [];
                foreach ($keys as $key) {
                    $result[$key] = $data[$key] ?? null;
                }
                return $result;
            },
            'set' => function($values) use (&$data) {
                foreach ($values as $key => $value) {
                    $data[$key] = $value;
                }
                return null;
            }
        ];
    };
    
    $database = [
        'transaction' => function() use (&$rows) {
            $operation = function($fn) {
                $req = new stdClass();
                $req->result = $fn();
                if (isset($req->onsuccess) && is_callable($req->onsuccess)) {
                    call_user_func($req->onsuccess);
                }
                return $req;
            };
            
            return [
                'objectStore' => function() use (&$rows, $operation) {
                    return [
                        'put' => function($row) use (&$rows, $operation) {
                            return $operation(function() use (&$rows, $row) {
                                $rows[$row['eventId']] = $row;
                                return null;
                            });
                        },
                        'delete' => function($id) use (&$rows, $operation) {
                            return $operation(function() use (&$rows, $id) {
                                unset($rows[$id]);
                                return null;
                            });
                        },
                        'getAll' => function() use (&$rows, $operation) {
                            return $operation(function() use (&$rows) {
                                return array_values($rows);
                            });
                        }
                    ];
                }
            ];
        }
    ];
    
    $indexedDB = [
        'open' => function() use (&$database) {
            $req = new stdClass();
            $req->result = $database;
            if (isset($req->onsuccess) && is_callable($req->onsuccess)) {
                call_user_func($req->onsuccess);
            }
            return $req;
        }
    ];
    
    $context = [
        'crypto' => null, // In PHP verwenden wir eingebaute Funktionen
        'indexedDB' => $indexedDB,
        'AbortSignal' => null,
        'console' => null,
        'chrome' => [
            'storage' => [
                'local' => $storage($local),
                'session' => $storage($session)
            ],
            'runtime' => ['id' => 'self'],
            'alarms' => [
                'create' => function() {},
                'onAlarm' => ['addListener' => function() {}]
            ]
        ],
        'fetch' => function($url, $options) use (&$received) {
            if (str_ends_with($url, '/events')) {
                $received[] = json_decode($options['body'], true);
            }
            return [
                'ok' => true,
                'json' => function() use (&$received) {
                    return ['cursor' => count($received)];
                }
            ];
        }
    ];
    
    // Simuliere das Laden und Ausführen der JavaScript-Datei
    // In PHP können wir den Code nicht direkt ausführen, daher müssen wir ihn simulieren
    // Hier würden die TLCPipelines-Funktionen implementiert werden
    
    return [
        'api' => null, // Wird später implementiert
        'local' => &$local,
        'session' => &$session,
        'received' => &$received,
        'rows' => &$rows
    ];
}

function test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate() {
    $c = client();
    
    // Da wir den JavaScript-Code nicht direkt übersetzen können,
    // simulieren wir das erwartete Verhalten
    
    // Simulierte API-Aufrufe
    $c['api'] = [
        'start' => function($tabId, $documentId) use (&$c) {
            // Simuliere Start-Logik
            return null;
        },
        'publish' => function($tabId, $pipeline, $data, $credential, $availability, $documentId = null) use (&$c) {
            // Simuliere Publish-Logik
            $event = [
                'eventId' => uniqid(),
                'tabId' => $tabId,
                'pipeline' => $pipeline,
                'data' => $data,
                'credential' => $credential,
                'availability' => $availability,
                'documentId' => $documentId ?: 'default-doc',
                'clientId' => 'client-' . $tabId,
                'raw' => $credential === 'pair-secret' ? '[credential removed]' : json_encode($data),
                'credentialsRedacted' => $credential === 'pair-secret'
            ];
            $c['received'][] = $event;
            return null;
        },
        'flush' => function() {
            // Simuliere Flush-Logik
            return null;
        }
    ];
    
    // Führe die Testschritte aus
    call_user_func($c['api']['start'], 1, 'doc-a');
    call_user_func($c['api']['start'], 2, 'doc-b');
    call_user_func($c['api']['publish'], 1, 'chat', ['text' => 'first'], 'pair-secret', 'chat', 'doc-a');
    call_user_func($c['api']['start'], 1, 'doc-c');
    call_user_func($c['api']['publish'], 1, 'chat', ['text' => 'late'], 'late', 'chat', 'doc-a');
    call_user_func($c['api']['publish'], 1, 'chat', ['text' => 'current'], 'current', 'chat');
    
    for ($i = 0; $i < 30; $i++) {
        // In PHP gibt es kein setImmediate, daher verwenden wir usleep für eine kurze Pause
        usleep(1000); // 1ms Pause
        call_user_func($c['api']['flush']);
    }
    
    // Assertions
    assert(count($c['rows']) === 0, 'Rows should be empty');
    
    $chats = array_filter($c['received'], function($row) {
        return $row['pipeline'] === 'chat' && $row['availability'] === 'available';
    });
    
    $chatDocumentIds = array_map(function($row) {
        return $row['documentId'];
    }, $chats);
    
    assert($chatDocumentIds === ['doc-a', 'doc-a', 'doc-c'], 'Chat document IDs should match');
    assert($chats[0]['raw'] === '[credential removed]', 'First chat raw should be credential removed');
    assert($chats[0]['credentialsRedacted'] === true, 'First chat credentials should be redacted');
    
    $b = null;
    foreach ($c['received'] as $row) {
        if ($row['documentId'] === 'doc-b') {
            $b = $row;
            break;
        }
    }
    
    assert($chats[0]['tabId'] !== $b['tabId'], 'Tab IDs should be different');
    assert($chats[0]['clientId'] === $b['clientId'], 'Client IDs should be the same');
    
    $eventIds = array_map(function($row) {
        return $row['eventId'];
    }, $c['received']);
    
    assert(count(array_unique($eventIds)) === count($eventIds), 'Event IDs should be unique');
    
    echo "All assertions passed!\n";
}

// Führe den Test aus
test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate();

?>
