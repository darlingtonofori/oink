import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'api_service.dart';
import 'config_service.dart';
import 'filter_service.dart';
import 'gateway_task_handler.dart';
import 'local_log_service.dart';

/// This is what runs when an SMS arrives while the app (and even the
/// foreground service) is not in the foreground. Must be a top-level
/// function with the vm:entry-point pragma.
@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  final enabled = await ConfigService.getReceiveSmsEnabled();
  if (!enabled) return;

  final from = message.address ?? 'unknown';
  final body = message.body ?? '';
  final allowed = await FilterService.isAllowed(from);
  if (!allowed) {
    await LocalLogService.add(
      direction: 'inbound',
      otherParty: from,
      body: body,
      status: 'blocked',
    );
    return;
  }

  final ok = await ApiService.forwardIncomingSms(from, body);
  await LocalLogService.add(
    direction: 'inbound',
    otherParty: from,
    body: body,
    status: ok ? 'forwarded' : 'forward_failed',
  );
}

class GatewayController {
  static final Telephony _telephony = Telephony.instance;

  static Future<bool> requestPermissions() async {
    final smsGranted = await _telephony.requestPhoneAndSmsPermissions;
    await Permission.notification.request();
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    return smsGranted ?? false;
  }

  static Future<void> _configureForegroundTask({int intervalMs = 15000}) async {
    final sticky = await ConfigService.getStickyNotification();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sms_gateway_channel',
        channelName: 'SMS Gateway',
        channelDescription: 'Keeps the SMS gateway online in the background.',
        channelImportance: sticky
            ? NotificationChannelImportance.DEFAULT
            : NotificationChannelImportance.LOW,
        priority:
            sticky ? NotificationPriority.DEFAULT : NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        interval: intervalMs,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> initForegroundTask() async {
    await _configureForegroundTask();
  }

  static Future<void> start({int pollIntervalSeconds = 15}) async {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        final enabled = await ConfigService.getReceiveSmsEnabled();
        if (!enabled) return;

        final from = message.address ?? 'unknown';
        final body = message.body ?? '';
        final allowed = await FilterService.isAllowed(from);
        if (!allowed) {
          await LocalLogService.add(
            direction: 'inbound',
            otherParty: from,
            body: body,
            status: 'blocked',
          );
          return;
        }

        final ok = await ApiService.forwardIncomingSms(from, body);
        await LocalLogService.add(
          direction: 'inbound',
          otherParty: from,
          body: body,
          status: ok ? 'forwarded' : 'forward_failed',
        );
      },
      onBackgroundMessage: backgroundSmsHandler,
      listenInBackground: true,
    );

    await _configureForegroundTask(intervalMs: pollIntervalSeconds * 1000);

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'SMS Gateway running',
        notificationText: 'Waiting for messages to send...',
        callback: startGatewayCallback,
      );
    }
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}
