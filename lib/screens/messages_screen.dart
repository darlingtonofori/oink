import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import '../services/local_log_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _log = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final log = await LocalLogService.getAll();
    log.sort(
      (a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String),
    );
    if (!mounted) return;
    setState(() {
      _log = log;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _filtered(String direction) {
    if (direction == 'all') return _log;
    return _log.where((e) => e['direction'] == direction).toList();
  }

  String _timeAgo(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _openCompose() async {
    final toController = TextEditingController();
    final bodyController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New message',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: toController,
              decoration: const InputDecoration(
                labelText: 'To',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final to = toController.text.trim();
                  final body = bodyController.text.trim();
                  if (to.isEmpty || body.isEmpty) return;
                  Navigator.of(ctx).pop();
                  try {
                    await Telephony.instance.sendSms(to: to, message: body);
                    await LocalLogService.add(
                      direction: 'outbound',
                      otherParty: to,
                      body: body,
                      status: 'sent',
                    );
                  } catch (e) {
                    await LocalLogService.add(
                      direction: 'outbound',
                      otherParty: to,
                      body: body,
                      status: 'failed',
                    );
                  }
                  _load();
                },
                child: const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Sent'),
            Tab(text: 'Received'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_filtered('all')),
                _buildList(_filtered('outbound')),
                _buildList(_filtered('inbound')),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCompose,
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final e = entries[index];
          final isInbound = e['direction'] == 'inbound';
          final status = e['status']?.toString() ?? '';
          Color statusColor;
          switch (status) {
            case 'sent':
            case 'forwarded':
              statusColor = Colors.green;
              break;
            case 'failed':
            case 'forward_failed':
              statusColor = Colors.red;
              break;
            default:
              statusColor = Colors.grey;
          }
          return ListTile(
            leading: Icon(
              isInbound ? Icons.arrow_downward : Icons.arrow_upward,
              color: statusColor,
            ),
            title: Text(e['otherParty']?.toString() ?? ''),
            subtitle: Text(
              e['body']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _timeAgo(e['timestamp']?.toString() ?? ''),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        },
      ),
    );
  }
}
