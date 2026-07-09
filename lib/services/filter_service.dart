import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum FilterMode { none, allowlist, blocklist }

/// Allow/block list for incoming SMS numbers. Numbers are matched with a
/// simple "contains" check, so a partial number like "0244" or a full
/// "+233244123456" both work.
class FilterService {
  static const _modeKey = 'filter_mode';
  static const _listKey = 'filter_numbers';

  static Future<FilterMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_modeKey) ?? 'none';
    return FilterMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => FilterMode.none,
    );
  }

  static Future<void> setMode(FilterMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  static Future<List<String>> getNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_listKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setNumbers(List<String> numbers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listKey, jsonEncode(numbers));
  }

  /// Returns true if this number should be processed (forwarded).
  static Future<bool> isAllowed(String number) async {
    final mode = await getMode();
    if (mode == FilterMode.none) return true;
    final numbers = await getNumbers();
    if (numbers.isEmpty) return true;
    final matches = numbers.any((n) => number.contains(n));
    if (mode == FilterMode.allowlist) return matches;
    return !matches;
  }
}
