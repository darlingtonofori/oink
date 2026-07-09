import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/config_service.dart';
import '../services/gateway_controller.dart';
import '../services/local_log_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ReceivePort? _receivePort;
  bool _running = false;
  bool _receiveSmsEnabled = true;
  String _deviceLabel = 'gateway-1';
  String _serverUrl = '';
  String _statusLine = 'Not started yet.';
  int _sentCount = 0;
  int _receivedCount = 0;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    GatewayController.initForegroundTask();
    _initReceivePort();
    _load();
  }

  void _initReceivePort() {
    _receivePort = FlutterForegroundTask.receivePort;
    _receivePort?.listen((data) {
      if (data is Map && mounted) {
        setState(() {
          _statusLine = 'Sent: ${data['sent']}  Failed: ${data['failed']}  '
              'Last check: ${_shortTime(data['lastCheck'])}';
        });
      }
    });
  }

  String _shortTime(dynamic iso) {
    if (iso is! String) return '';
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _receivePort?.close();
    super.dispose();
  }

  Future<void> _load() async {
    final running = await GatewayController.isRunning();
    final receiveSms = await ConfigService.getReceiveSmsEnabled();
    final label = await ConfigService.getDeviceLabel();
    final url = await ConfigService.getServerUrl();
    final log = await LocalLogService.getAll();

    var sent = 0;
    var received = 0;
    var failed = 0;
    for (final e in log) {
      final status = e['status'];
      if (status == 'sent') sent++;
      if (status == 'forwarded') received++;
      if (status == 'failed' || status == 'forward_failed') failed++;
    }

    if (!mounted) return;
    setState(() {
      _running = running;
      _receiveSmsEnabled = receiveSms;
      _deviceLabel = label;
      _serverUrl = url ?? '';
      _sentCount = sent;
      _receivedCount = received;
      _failedCount = failed;
    });
  }

  Future<void> _toggleGateway(bool value) async {
    if (value) {
      if (_serverUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set your server URL in Settings first')),
        );
        return;
      }
      final granted = await GatewayController.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS permission is required')),
          );
        }
        return;
      }
      final interval = await ConfigService.getPollInterval();
      await GatewayController.start(pollIntervalSeconds: interval);
      setState(() {
        _running = true;
        _statusLine = 'Started. Polling every $interval seconds.';
      });
    } else {
      await GatewayController.stop();
      setState(() {
        _running = false;
        _statusLine = 'Stopped.';
      });
    }
  }

  Future<void> _toggleReceiveSms(bool value) async {
    await ConfigService.setReceiveSmsEnabled(value);
    setState(() => _receiveSmsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _running
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          child: Icon(
                            Icons.sms,
                            color: _running ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _deviceLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _running ? 'Gateway running' : 'Gateway stopped',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch(value: _running, onChanged: _toggleGateway),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Receive SMS'),
                        Switch(
                          value: _receiveSmsEnabled,
                          onChanged: _toggleReceiveSms,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_statusLine, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Received',
                    value: _receivedCount,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Sent',
                    value: _sentCount,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Failed',
                    value: _failedCount,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_serverUrl.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Server dashboard',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Open this in your phone\'s browser to see live '
                        'inbox/outbox on the server side:',
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        '$_serverUrl/dashboard',
                        style: const TextStyle(color: Colors.greenAccent),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
