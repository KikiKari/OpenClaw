<?php
// OpenClaw log analyzer (PHP) — parses gateway access logs from stdin
$counts = ['INFO' => 0, 'WARN' => 0, 'ERROR' => 0];

while (($line = fgets(STDIN)) !== false) {
    if (preg_match('/^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$/', trim($line), $m)) {
        $counts[$m[2]]++;
        if ($m[2] === 'ERROR') {
            printf("\u{26a0} %s [%s] %s\n", $m[1], $m[3], $m[4]);
        }
    }
}

echo "\n--- Summary ---\n";
foreach (['ERROR', 'INFO', 'WARN'] as $level) {
    printf("%s: %d\n", $level, $counts[$level]);
}
