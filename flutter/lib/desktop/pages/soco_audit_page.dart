import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// SoCo Sentry — on-device connection log ("Audit Log" tab).
///
/// Shows who connected to THIS machine and when, read from the local log the
/// Rust side keeps (src/soco_audit.rs) via the generic main_get_common channel.
class SocoAuditPage extends StatefulWidget {
  const SocoAuditPage({Key? key}) : super(key: key);

  @override
  State<SocoAuditPage> createState() => _SocoAuditPageState();
}

class _SocoAuditPageState extends State<SocoAuditPage> {
  List<dynamic> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<dynamic> rows = [];
    try {
      final raw = await bind.mainGetCommon(key: 'soco-audit-log');
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) rows = decoded;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  String _fmt(int epochSecs) {
    if (epochSecs <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(epochSecs * 1000).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  String _duration(int start, int end) {
    if (start <= 0) return '—';
    if (end <= 0) return 'active';
    final s = end - start;
    if (s < 60) return '${s}s';
    if (s < 3600) return '${s ~/ 60}m ${s % 60}s';
    return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m';
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(translate('Clear')),
        content: Text(
            'Erase this device\'s local connection log? The copy held by SoCo Systems is not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(translate('Cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(translate('OK'))),
        ],
      ),
    );
    if (ok == true) {
      await bind.mainSetCommon(key: 'soco-audit-clear', value: '');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Connection log',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: translate('Refresh'),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: translate('Clear'),
                  onPressed: _rows.isEmpty ? null : _confirmClear,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(
              'Everyone who has connected to this computer. Recorded on this device.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? Center(
                          child: Text(
                            'No connections recorded yet.',
                            style: TextStyle(color: theme.hintColor),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = _rows[i] as Map<String, dynamic>;
                            final started = (r['started'] ?? 0) as int;
                            final ended = (r['ended'] ?? 0) as int;
                            final who = ((r['peer_name'] ?? '') as String).isNotEmpty
                                ? r['peer_name'] as String
                                : (((r['peer_id'] ?? '') as String).isNotEmpty
                                    ? r['peer_id'] as String
                                    : 'Not authenticated');
                            final pid = (r['peer_id'] ?? '') as String;
                            final ip = (r['ip'] ?? '') as String;
                            final kind = (r['conn_type'] ?? '') as String;
                            final live = ended <= 0;
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                live ? Icons.circle : Icons.history,
                                size: live ? 12 : 18,
                                color: live ? Colors.green : theme.hintColor,
                              ),
                              title: Text(
                                who,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text([
                                if (pid.isNotEmpty) 'ID $pid',
                                if (ip.isNotEmpty) ip,
                                if (kind.isNotEmpty) kind,
                              ].join('  ·  ')),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_fmt(started),
                                      style: const TextStyle(fontSize: 12)),
                                  Text(_duration(started, ended),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: live
                                              ? Colors.green
                                              : theme.hintColor)),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
