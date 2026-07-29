import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
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
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: getSideDrawer(context),
      body: Center(
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
            const SizedBox(height: 12),
            Text(
              'One-time migrations. Each can be run safely multiple times —\n'
              'existing logs are skipped.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
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
    Future<int> future, String kind, void Function(String) setMsg) async {
    setState(() => _running = true);
    setMsg('Migrating $kind...');
    try {
      final count = await future;
      setMsg('$kind: Done! Migrated $count log(s).');
    } catch (e) {
      setMsg('$kind: Error — $e');
    }
    setState(() => _running = false);
  }
}
