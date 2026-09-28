import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../student_management/models/student_model.dart';
import 'drawer.dart';

class Helper extends ConsumerStatefulWidget {
  const Helper({super.key});

  @override
  ConsumerState<Helper> createState() => _HelperState();
}

class _HelperState extends ConsumerState<Helper> {
  String _stockMsg = 'Migrate Stock Logs (add location fields)';
  String _studentMsg = 'Migrate Student Audit Logs';
  String _staffMsg = 'Migrate Staff Audit Logs';
  String _docsMsg = 'Audit Student Documents';
  String _backfillMsg = 'Backfill Document Flags';
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: getSideDrawer(context),
      appBar: AppBar(
        title: const Text('Helper',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildButton(_stockMsg, () => _runMigration(
                ref.read(stockRepositoryProvider).migrateStockLogsLocation(),
                'Stock',
                (s) => _stockMsg = s,
              )),
              const SizedBox(height: 16),
              _buildButton(_studentMsg, () => _runMigration(
                ref.read(studentRepositoryProvider).migrateStudentAuditLogs(),
                'Student',
                (s) => _studentMsg = s,
              )),
              const SizedBox(height: 16),
              _buildButton(_staffMsg, () => _runMigration(
                ref.read(staffRepositoryProvider).migrateStaffAuditLogs(),
                'Staff',
                (s) => _staffMsg = s,
              )),
              const SizedBox(height: 16),
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
                'One-time migrations. Each can be run safely multiple times —\n'
                'existing logs are skipped. The documents audit is read-only;\n'
                'the backfill stamps the filter flags on pre-flag records\n'
                '(every later edit recomputes them automatically).',
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
