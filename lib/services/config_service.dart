import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores every bit of local config the gateway needs: where your VPS is,
/// the API key, device identity, and behavior toggles.
class ConfigService {
  static const _serverUrlKey = 'server_url';
  static const _apiKeyKey = 'api_key';
  static const _pollIntervalKey = 'poll_interval_seconds';
  static const _deviceLabelKey = 'device_label';
  static const _deviceIdKey = 'device_id';
  static const _receiveSmsEnabledKey = 'receive_sms_enabled';
  static const _sendDelaySecondsKey = 'send_delay_seconds';
  static const _stickyNotificationKey = 'sticky_notification';

  static Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await prefs.setString(_serverUrlKey, cleaned);
  }

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
  }

  static Future<int> getPollInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pollIntervalKey) ?? 15;
  }

  static Future<void> setPollInterval(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pollIntervalKey, seconds);
  }

  static Future<String> getDeviceLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceLabelKey) ?? 'gateway-1';
  }

  static Future<void> setDeviceLabel(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceLabelKey, label);
  }

  /// A random ID generated once per install, purely local (nothing to do
  /// with your carrier's IMEI/IMSI) - just something to visually identify
  /// this install in the Settings screen, textbee-style.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      final rand = Random();
      id = List.generate(24, (_) => rand.nextInt(16).toRadixString(16)).join();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  static Future<bool> getReceiveSmsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_receiveSmsEnabledKey) ?? true;
  }

  static Future<void> setReceiveSmsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_receiveSmsEnabledKey, value);
  }

  static Future<int> getSendDelaySeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sendDelaySecondsKey) ?? 2;
  }

  static Future<void> setSendDelaySeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sendDelaySecondsKey, seconds);
  }

  static Future<bool> getStickyNotification() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_stickyNotificationKey) ?? true;
  }

  static Future<void> setStickyNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_stickyNotificationKey, value);
  }

  /// Wipes server credentials (Disconnect Device). Keeps the local device
  /// ID and message log intact.
  static Future<void> clearServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
    await prefs.remove(_apiKeyKey);
  }
}
