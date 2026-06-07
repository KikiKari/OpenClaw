import 'dart:io';
import 'dart:async';

// OpenClaw TCP port probe (Dart) — checks gateway nodes
Future<bool> probe(String host, int port,
    {Duration timeout = const Duration(seconds: 3)}) async {
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  final nodes = [
    ['localhost', 8080],
    ['localhost', 8081],
  ];
  for (final n in nodes) {
    final ok = await probe(n[0] as String, n[1] as int);
    print('${ok ? "OK  " : "FAIL"} ${n[0]}:${n[1]}');
  }
}
