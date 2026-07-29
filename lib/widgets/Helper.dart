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
  String _migrationMsg = 'Migrate Stock Logs (add location fields)';
  bool _migrating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: getSideDrawer(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _migrating ? null : _runMigration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: _migrating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_migrationMsg,
                      style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 12),
            Text(
              'This is a one-time migration to add building/floor/room\n'
              'names to existing stock logs for the Global Log tab.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runMigration() async {
    setState(() {
      _migrating = true;
      _migrationMsg = 'Migrating...';
    });
    try {
      final service = ref.read(stockRepositoryProvider);
      final count = await service.migrateStockLogsLocation();
      setState(() {
        _migrationMsg = 'Done! Migrated $count log(s).';
      });
    } catch (e) {
      setState(() {
        _migrationMsg = 'Error: $e';
      });
    }
    setState(() => _migrating = false);
  }
}
