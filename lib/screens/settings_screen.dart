import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../services/filter_service.dart';
import '../services/gateway_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _deviceId = '';
  String _deviceLabel = '';
  String _serverUrl = '';
  String _apiKey = '';
  bool _apiKeyVisible = false;
  int _pollInterval = 15;
  int _sendDelay = 2;
  bool _stickyNotification = true;
  bool _receiveSmsEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await ConfigService.getDeviceId();
    final label = await ConfigService.getDeviceLabel();
    final url = await ConfigService.getServerUrl();
    final key = await ConfigService.getApiKey();
    final poll = await ConfigService.getPollInterval();
    final delay = await ConfigService.getSendDelaySeconds();
    final sticky = await ConfigService.getStickyNotification();
    final receiveSms = await ConfigService.getReceiveSmsEnabled();
    if (!mounted) return;
    setState(() {
      _deviceId = id;
      _deviceLabel = label;
      _serverUrl = url ?? '';
      _apiKey = key ?? '';
      _pollInterval = poll;
      _sendDelay = delay;
      _stickyNotification = sticky;
      _receiveSmsEnabled = receiveSms;
    });
  }

  Future<void> _editTextField({
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSave,
    bool obscure = false,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await onSave(result);
      _load();
    }
  }

  Future<void> _editNumberField({
    required String title,
    required int initialValue,
    required Future<void> Function(int) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue.toString());
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      final n = int.tryParse(result);
      if (n != null) {
        await onSave(n);
        _load();
      }
    }
  }

  Future<void> _configureFilters() async {
    var mode = await FilterService.getMode();
    final numbers = await FilterService.getNumbers();
    final controller = TextEditingController(text: numbers.join('\n'));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Configure filters'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<FilterMode>(
                  segments: const [
                    ButtonSegment(value: FilterMode.none, label: Text('Off')),
                    ButtonSegment(
                        value: FilterMode.allowlist, label: Text('Allow')),
                    ButtonSegment(
                        value: FilterMode.blocklist, label: Text('Block')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) =>
                      setDialogState(() => mode = s.first),
                ),
                const SizedBox(height: 12),
                const Text('One number (or part of a number) per line:'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: '+2335...\n024...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final lines = controller.text
                    .split('\n')
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty)
                    .toList();
                await FilterService.setMode(mode);
                await FilterService.setNumbers(lines);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect device?'),
        content: const Text(
          'This stops the gateway and clears your server URL and API key. '
          'Your message log and device ID stay on this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await GatewayController.stop();
      await ConfigService.clearServerConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected')),
        );
      }
      _load();
    }
  }

  Future<void> _testConnection() async {
    final ok = await ApiService.ping();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Server reachable' : 'Could not reach server'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Device ID'),
            subtitle: SelectableText(_deviceId),
          ),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('Server URL'),
            subtitle: Text(_serverUrl.isEmpty ? 'Not set' : _serverUrl),
            onTap: () => _editTextField(
              title: 'Server URL',
              initialValue: _serverUrl,
              onSave: ConfigService.setServerUrl,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('API key'),
            subtitle: Text(
              _apiKey.isEmpty ? 'Not set' : (_apiKeyVisible ? _apiKey : '•' * 12),
            ),
            trailing: IconButton(
              icon: Icon(
                _apiKeyVisible ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _apiKeyVisible = !_apiKeyVisible),
            ),
            onTap: () => _editTextField(
              title: 'API key',
              initialValue: _apiKey,
              onSave: ConfigService.setApiKey,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wifi_tethering),
            title: const Text('Test connection'),
            onTap: _testConnection,
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Device name'),
            subtitle: Text(_deviceLabel),
            onTap: () => _editTextField(
              title: 'Device name',
              initialValue: _deviceLabel,
              onSave: ConfigService.setDeviceLabel,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link_off, color: Colors.red),
            title: const Text(
              'Disconnect device',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _disconnect,
          ),
          const _SectionHeader('SMS'),
          SwitchListTile(
            secondary: const Icon(Icons.download),
            title: const Text('Receive SMS'),
            subtitle: const Text('Forward incoming SMS to backend'),
            value: _receiveSmsEnabled,
            onChanged: (v) async {
              await ConfigService.setReceiveSmsEnabled(v);
              _load();
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Poll interval'),
            subtitle: Text('$_pollInterval seconds between checks'),
            onTap: () => _editNumberField(
              title: 'Poll interval (seconds)',
              initialValue: _pollInterval,
              onSave: ConfigService.setPollInterval,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.hourglass_bottom),
            title: const Text('Send delay'),
            subtitle: Text('$_sendDelay seconds between each SMS'),
            onTap: () => _editNumberField(
              title: 'Send delay (seconds)',
              initialValue: _sendDelay,
              onSave: ConfigService.setSendDelaySeconds,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.filter_alt),
            title: const Text('Configure filters'),
            subtitle: const Text('Allow/block list for incoming SMS'),
            onTap: _configureFilters,
          ),
          const _SectionHeader('System'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active),
            title: const Text('Sticky notification'),
            subtitle: const Text(
              'Keeps the gateway visibly alive in the background',
            ),
            value: _stickyNotification,
            onChanged: (v) async {
              await ConfigService.setStickyNotification(v);
              setState(() => _stickyNotification = v);
              if (await GatewayController.isRunning()) {
                await GatewayController.start(pollIntervalSeconds: _pollInterval);
              }
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App version'),
            subtitle: Text('1.0.0'),
          ),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.auto_awesome),
            title: Text('About'),
            subtitle: Text(
              'Self-hosted SMS gateway. Your phone, your server, your data - '
              'no third-party cloud in between.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.support_agent),
            title: Text('Source & support'),
            subtitle: SelectableText('github.com/darlingtonofori/oink'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
