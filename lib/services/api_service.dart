import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';

/// Everything the phone needs to talk to your VPS lives here:
///  - forwardIncomingSms   -> phone received an SMS, push it to the server
///  - fetchPendingMessages -> ask the server "anything to send?"
///  - reportSentStatus     -> tell the server whether a send succeeded
class ApiService {
  static Future<bool> forwardIncomingSms(String from, String body) async {
    final baseUrl = await ConfigService.getServerUrl();
    if (baseUrl == null || baseUrl.isEmpty) return false;
    final apiKey = await ConfigService.getApiKey();
    final device = await ConfigService.getDeviceLabel();

    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/inbound'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': apiKey ?? '',
            },
            body: jsonEncode({
              'device': device,
              'from': from,
              'body': body,
              'receivedAt': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPendingMessages() async {
    final baseUrl = await ConfigService.getServerUrl();
    if (baseUrl == null || baseUrl.isEmpty) return [];
    final apiKey = await ConfigService.getApiKey();
    final device = await ConfigService.getDeviceLabel();

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/pending?device=$device'),
        headers: {'X-API-Key': apiKey ?? ''},
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final messages = data['messages'] as List<dynamic>? ?? [];
        return messages.cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // Network hiccup - the next poll cycle will just try again.
    }
    return [];
  }

  static Future<void> reportSentStatus(
    String id, {
    required bool success,
    String? error,
  }) async {
    final baseUrl = await ConfigService.getServerUrl();
    if (baseUrl == null || baseUrl.isEmpty) return;
    final apiKey = await ConfigService.getApiKey();

    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/status'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': apiKey ?? '',
            },
            body: jsonEncode({
              'id': id,
              'success': success,
              'error': error,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Best-effort; if this fails the server can time out the job itself.
    }
  }

  /// Simple reachability check used by the "Test connection" button.
  static Future<bool> ping() async {
    final baseUrl = await ConfigService.getServerUrl();
    if (baseUrl == null || baseUrl.isEmpty) return false;
    final apiKey = await ConfigService.getApiKey();
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/api/ping'),
            headers: {'X-API-Key': apiKey ?? ''},
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
