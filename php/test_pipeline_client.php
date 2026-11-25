<?php
// abstraction-provenance: {"artifact_sha256": "f78a2e07a97301d011ea614bae6e329c6b95ca4ed4100383d171a88caa39502e", "source_sha256": "e28f06911ddc1d346df8de8f09de3cdbd61d7cfd8fed3f4f2a080d921fb0d448", "target_language": "php"}
// test_pipeline_client.cjs — portiert nach php
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_pipeline_client.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_pipeline_client.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_pipeline_client.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_pipeline_client.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
// Emulation von Node.js APIs und Test-Funktionen in PHP

class TestRunner {
    private $tests = [];
    
    public function test($name, $callback) {
        $this->tests[] = ['name' => $name, 'callback' => $callback];
    }
    
    public function run() {
        foreach ($this->tests as $test) {
            echo "Running test: " . $test['name'] . "\n";
            call_user_func($test['callback']);
        }
    }
}

class Assert {
    public static function equal($actual, $expected) {
        if ($actual !== $expected) {
            throw new Exception("Assertion failed: expected $expected, got $actual");
        }
    }
    
    public static function notEqual($actual, $expected) {
        if ($actual === $expected) {
            throw new Exception("Assertion failed: expected not $expected, got $actual");
        }
    }
    
    public static function deepEqual($actual, $expected) {
        if ($actual != $expected) {
            throw new Exception("Assertion failed: expected " . json_encode($expected) . ", got " . json_encode($actual));
        }
    }
}

class Storage {
    private $data;
    
    public function __construct(&$data) {
        $this->data = &$data;
    }
    
    public function get($keys) {
        $result = [];
        $keyArray = is_array($keys) ? $keys : [$keys];
        foreach ($keyArray as $key) {
            $result[$key] = isset($this->data[$key]) ? $this->data[$key] : null;
        }
        return $result;
    }
    
    public function set($values) {
        foreach ($values as $key => $value) {
            $this->data[$key] = $value;
        }
    }
}

class DatabaseTransaction {
    private $rows;
    
    public function __construct(&$rows) {
        $this->rows = &$rows;
    }
    
    public function objectStore() {
        return new ObjectStore($this->rows);
    }
}

class ObjectStore {
    private $rows;
    
    public function __construct(&$rows) {
        $this->rows = &$rows;
    }
    
    public function put($row) {
        $this->rows[$row['eventId']] = $row;
        return new Request();
    }
    
    public function delete($id) {
        unset($this->rows[$id]);
        return new Request();
    }
    
    public function getAll() {
        return new Request(array_values($this->rows));
    }
}

class Request {
    public $result;
    
    public function __construct($result = null) {
        $this->result = $result;
    }
}

class IndexedDB {
    private $database;
    
    public function __construct(&$database) {
        $this->database = &$database;
    }
    
    public function open() {
        return new Request($this->database);
    }
}

class AbortSignal {}

function client() {
    $local = ['tlc-settings' => ['universalCaptionApiKey' => 'universal-secret', 'pairingCode' => 'pair-secret']];
    $session = [];
    $rows = [];
    $received = [];
    
    $storageLocal = new Storage($local);
    $storageSession = new Storage($session);
    
    $database = [
        'transaction' => function() use (&$rows) {
            return new DatabaseTransaction($rows);
        }
    ];
    
    $indexedDB = new IndexedDB($database);
    
    // Hier würden wir normalerweise den JavaScript-Code ausführen
    // Da wir in PHP sind, simulieren wir das Verhalten
    
    return [
        'api' => new TLCPipelines($local, $session, $rows, $received),
        'local' => $local,
        'session' => $session,
        'received' => $received,
        'rows' => $rows
    ];
}

class TLCPipelines {
    private $local;
    private $session;
    private $rows;
    private $received;
    
    public function __construct(&$local, &$session, &$rows, &$received) {
        $this->local = &$local;
        $this->session = &$session;
        $this->rows = &$rows;
        $this->received = &$received;
    }
    
    public function start($tabId, $documentId) {
        // Simuliere Start-Logik
        return new Promise(function($resolve) {
            $resolve();
        });
    }
    
    public function publish($tabId, $pipeline, $data, $credential, $availability, $documentId = null) {
        // Simuliere Publish-Logik
        $event = [
            'eventId' => uniqid(),
            'tabId' => $tabId,
            'pipeline' => $pipeline,
            'data' => $data,
            'credential' => $credential,
            'availability' => $availability,
            'documentId' => $documentId ?: 'default',
            'clientId' => 'client-' . uniqid()
        ];
        
        $this->received[] = $event;
        return new Promise(function($resolve) {
            $resolve();
        });
    }
    
    public function flush() {
        // Simuliere Flush-Logik
        return new Promise(function($resolve) {
            $resolve();
        });
    }
}

class Promise {
    private $executor;
    
    public function __construct($executor) {
        $this->executor = $executor;
    }
    
    public function then($callback) {
        call_user_func($this->executor, $callback);
        return $this;
    }
    
    public static function resolve($value = null) {
        return new Promise(function($resolve) use ($value) {
            $resolve($value);
        });
    }
}

// Test ausführen
$testRunner = new TestRunner();

$testRunner->test('one key, two tabs, reload and delayed old-document events stay separate', function() {
    $c = client();
    
    $c['api']->start(1, 'doc-a');
    $c['api']->start(2, 'doc-b');
    $c['api']->publish(1, 'chat', ['text' => 'first'], 'pair-secret', 'chat', 'doc-a');
    $c['api']->start(1, 'doc-c');
    $c['api']->publish(1, 'chat', ['text' => 'late'], 'late', 'chat', 'doc-a');
    $c['api']->publish(1, 'chat', ['text' => 'current'], 'current', 'chat');
    
    // Simuliere Warten und Flush
    for ($i = 0; $i < 30; $i++) {
        usleep(1000); // Kurze Pause
        $c['api']->flush();
    }
    
    Assert::equal(count($c['rows']), 0);
    
    $chats = array_filter($c['received'], function($row) {
        return $row['pipeline'] === 'chat' && $row['availability'] === 'available';
    });
    
    $documentIds = array_map(function($row) {
        return $row['documentId'];
    }, $chats);
    
    Assert::deepEqual($documentIds, ['doc-a', 'doc-a', 'doc-c']);
    
    // Weitere Assertions...
    $firstChat = $chats[0];
    Assert::equal($firstChat['raw'], '[credential removed]');
    Assert::equal($firstChat['credentialsRedacted'], true);
    
    $b = null;
    foreach ($c['received'] as $row) {
        if ($row['documentId'] === 'doc-b') {
            $b = $row;
            break;
        }
    }
    
    Assert::notEqual($firstChat['tabId'], $b['tabId']);
    Assert::equal($firstChat['clientId'], $b['clientId']);
    
    $eventIds = array_map(function($row) {
        return $row['eventId'];
    }, $c['received']);
    
    Assert::equal(count(array_unique($eventIds)), count($eventIds));
});

$testRunner->run();

?>
