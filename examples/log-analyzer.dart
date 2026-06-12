import 'dart:io';

// OpenClaw log analyzer (Dart) — parses gateway access logs from stdin
void main() {
  final pattern = RegExp(r'^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$');
  final counts = {'INFO': 0, 'WARN': 0, 'ERROR': 0};

  String? line;
  while ((line = stdin.readLineSync()) != null) {
    final m = pattern.firstMatch(line!);
    if (m == null) continue;
    final level = m.group(2)!;
    counts[level] = counts[level]! + 1;
    if (level == 'ERROR') print('⚠ ${m.group(1)} [${m.group(3)}] ${m.group(4)}');
  }

  print('\n--- Summary ---');
  for (final level in ['ERROR', 'INFO', 'WARN']) {
    print('$level: ${counts[level]}');
  }
}
