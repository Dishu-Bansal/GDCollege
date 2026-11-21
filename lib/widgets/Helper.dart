import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../access/access_service.dart';
import '../providers.dart';
import '../student_docs/services/firebase_student_docs_service.dart';
import '../student_management/models/student_model.dart';
import 'drawer.dart';

/// Maintenance screen: the document-completeness tools plus the one-time
/// server-time backfills (run once per database after the serverTimestamp
/// rollout, so legacy ISO-string instants become native Timestamps and
/// ordering stays correct).

/// Maintenance screen. Only the two document-completeness tools live here:
/// the read-only audit and the flag backfill.
class Helper extends ConsumerStatefulWidget {
  const Helper({super.key});

  @override
  ConsumerState<Helper> createState() => _HelperState();
}

class _HelperState extends ConsumerState<Helper> {
  String _docsMsg = 'Audit Student Documents';
  String _backfillMsg = 'Backfill Document Flags';
  String _tsMsg = 'Backfill Server-Time Stamps';
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: getSideDrawer(context),
      appBar: AppBar(
        title: const Text('Tools',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildButton(_docsMsg, _runDocsAudit),
              const SizedBox(height: 16),
              _buildButton(_backfillMsg, () => _runMigration(
                ref.read(studentRepositoryProvider).backfillDocsFlags(),
                'Docs flags',
                (s) => _backfillMsg = s,
                unit: 'record(s)',
              )),
              const SizedBox(height: 12),
              Text(
                'Rules: Aadhar number + card for 2016+ admissions; PAN number '
                '+ card for everyone; 10th & 12th files; caste certificates; '
                'Haryana Family ID + residence; ABC ID for 2024+ admissions.\n\n'
                'The documents audit is read-only; the backfill stamps the '
                'filter flags (every later edit recomputes them automatically).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              _buildButton(_tsMsg, _runTimestampBackfills),
              const SizedBox(height: 12),
              Text(
                'One-time: converts legacy date-strings to native timestamps '
                'for Students, Staff, Stock, Bills, Visitors, Leads, Docs and '
                'Access — run once per database after updating the app, so '
                'new server-stamped rows sort correctly with old rows.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: _running ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  Future<void> _runMigration(
    Future<int> future,
    String kind,
    void Function(String) setMsg, {
    String unit = 'log(s)',
  }) async {
    setState(() => _running = true);
    setMsg('Migrating $kind...');
    try {
      final count = await future;
      setMsg('$kind: Done! Updated $count $unit.');
    } catch (e) {
      setMsg('$kind: Error — $e');
    }
    setState(() => _running = false);
  }

  /// One-time server-time backfill across every module. Runs the per-module
  /// converters sequentially and reports per-collection counts.
  Future<void> _runTimestampBackfills() async {
    if (_running) return;
    setState(() {
      _running = true;
      _tsMsg = 'Converting timestamps...';
    });
    try {
      final total = <String, int>{};
      void merge(Map<String, int> m) =>
          m.forEach((k, v) => total[k] = (total[k] ?? 0) + v);

      merge(await ref
          .read(studentRepositoryProvider)
          .backfillTimestampsToNative());
      merge(await ref
          .read(staffRepositoryProvider)
          .backfillTimestampsToNative());
      merge(await ref
          .read(stockRepositoryProvider)
          .backfillTimestampsToNative());
      merge(await ref
          .read(billRepositoryProvider)
          .backfillTimestampsToNative());
      merge(await ref
          .read(visitorRepositoryProvider)
          .backfillTimestampsToNative());
      merge(await ref
          .read(leadRepositoryProvider)
          .backfillTimestampsToNative());
      merge(
          await FirebaseStudentDocsService().backfillTimestampsToNative());
      merge(await AccessService().backfillTimestampsToNative());

      final summary = total.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
      if (!mounted) return;
      setState(() {
        _running = false;
        _tsMsg = summary.isEmpty
            ? 'Backfill Server-Time Stamps (nothing to convert)'
            : 'Backfill done — $summary';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _tsMsg = 'Backfill Server-Time Stamps';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Timestamp backfill failed: $e')),
      );
    }
  }

  /// Read-only completeness audit over every student, driven by the stored
  /// denormalized flags (run the backfill first for pre-flag records).
  Future<void> _runDocsAudit() async {
    if (_running) return;
    setState(() {
      _running = true;
      _docsMsg = 'Auditing documents...';
    });
    try {
      final all =
          await ref.read(studentRepositoryProvider).fetchAllStudents();
      final incomplete = <MapEntry<StudentModel, List<String>>>[];
      for (final s in all) {
        if (s.missingDocsCount > 0) {
          incomplete.add(MapEntry(s, s.missingDocs));
        }
      }
      incomplete.sort((a, b) => a.key.name.compareTo(b.key.name));
      if (!mounted) return;
      setState(() {
        _running = false;
        _docsMsg =
            'Audit Student Documents (${incomplete.length}/${all.length} incomplete)';
      });
      _showAuditDialog(all.length, incomplete);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _docsMsg = 'Audit Student Documents';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audit failed: $e')),
      );
    }
  }

  void _showAuditDialog(int total,
      List<MapEntry<StudentModel, List<String>>> incomplete) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '${incomplete.length} of $total students\nmissing documents',
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: incomplete.isEmpty
              ? const Text('All complete.',
                  style: TextStyle(color: Colors.grey))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: incomplete.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = incomplete[i].key;
                    final missing = incomplete[i].value;
                    final name =
                        s.name.isEmpty ? '(unnamed)' : s.name;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      subtitle: Text(
                        missing.join(', '),
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
