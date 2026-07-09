import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A simple on-device log of every SMS this gateway has sent or forwarded,
/// so the Messages tab has something to show even if the server is
/// temporarily unreachable.
class LocalLogService {
  static const _key = 'message_log_v1';
  static const _maxEntries = 300;

  static Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// direction: 'inbound' | 'outbound'
  /// status: 'sent' | 'failed' | 'forwarded' | 'forward_failed' | 'blocked'
  static Future<void> add({
    required String direction,
    required String otherParty,
    required String body,
    required String status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getAll();
    entries.add({
      'direction': direction,
      'otherParty': otherParty,
      'body': body,
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    });
    final trimmed = entries.length > _maxEntries
        ? entries.sublist(entries.length - _maxEntries)
        : entries;
    await prefs.setString(_key, jsonEncode(trimmed));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
