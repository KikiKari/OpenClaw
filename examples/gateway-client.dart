import 'dart:io';

// OpenClaw Gateway Client (Dart)
Future<int> checkHealth(String baseUrl) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(Uri.parse('$baseUrl/health'));
    final response = await request.close();
    return response.statusCode;
  } finally {
    client.close();
  }
}

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty ? args[0] : 'http://localhost:8080';
  final status = await checkHealth(url);
  print('Gateway $url -> HTTP $status');
}
