import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:telephony/telephony.dart';
import 'api_service.dart';
import 'config_service.dart';
import 'local_log_service.dart';

/// Entry point the foreground service isolate calls into. Must stay a
/// top-level function (not a class method) so Flutter can find it when
/// the service is (re)started in its own isolate.
@pragma('vm:entry-point')
void startGatewayCallback() {
  FlutterForegroundTask.setTaskHandler(GatewayTaskHandler());
}

/// Runs in the background for as long as the gateway is "on". Every
/// [onRepeatEvent] tick it asks the VPS for pending outbound messages and
/// fires them off via the device's own SIM.
class GatewayTaskHandler extends TaskHandler {
  final Telephony _telephony = Telephony.instance;
  int _sentCount = 0;
  int _failCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    FlutterForegroundTask.updateService(
      notificationTitle: 'SMS Gateway running',
      notificationText: 'Waiting for messages to send...',
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    final pending = await ApiService.fetchPendingMessages();
    final delaySeconds = await ConfigService.getSendDelaySeconds();

    for (final msg in pending) {
      final to = msg['to']?.toString();
      final body = msg['body']?.toString();
      final id = msg['id']?.toString() ?? '';

      if (to == null || to.isEmpty || body == null || body.isEmpty) {
        continue;
      }

      try {
        await _telephony.sendSms(to: to, message: body);
        _sentCount++;
        await ApiService.reportSentStatus(id, success: true);
        await LocalLogService.add(
          direction: 'outbound',
          otherParty: to,
          body: body,
          status: 'sent',
        );
      } catch (e) {
        _failCount++;
        await ApiService.reportSentStatus(id, success: false, error: '$e');
        await LocalLogService.add(
          direction: 'outbound',
          otherParty: to,
          body: body,
          status: 'failed',
        );
      }

      if (delaySeconds > 0) {
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    FlutterForegroundTask.updateService(
      notificationTitle: 'SMS Gateway running',
      notificationText: 'Sent: $_sentCount  Failed: $_failCount  '
          'Last check: ${_formatTime(timestamp)}',
    );

    sendPort?.send({
      'sent': _sentCount,
      'failed': _failCount,
      'lastCheck': timestamp.toIso8601String(),
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
