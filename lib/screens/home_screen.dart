import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bill_management/screens/bill_management_screen.dart';
import '../models/home_analytics.dart';
import '../providers.dart';
import '../student_management/screens/student_list_screen.dart';
import '../staff_management/screens/staff_list_screen.dart';
import '../stock_management/screens/buildings_screen.dart';
import '../widgets/drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(homeAnalyticsProvider);
    return Scaffold(
      drawer: getSideDrawer(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Welcome header
                Icon(
                  Icons.school,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lala Kundan Lal\nMemorial Society',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // Daily analytics (previous calendar day, IST)
                _AnalyticsCard(analytics: analytics),
                const SizedBox(height: 24),
                // Navigation cards
                _NavCard(
                  icon: Icons.people_alt,
                  label: 'Student Management',
                  color: const Color(0xFF1565C0),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentListScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _NavCard(
                  icon: Icons.badge,
                  label: 'Staff Management',
                  color: const Color(0xFF2E7D32),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffListScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _NavCard(
                  icon: Icons.inventory_2,
                  label: 'Stock Management',
                  color: const Color(0xFF6A1B9A),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const BuildingsScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _NavCard(
                  icon: Icons.receipt_long,
                  label: 'Bill Management',
                  color: const Color(0xFF00838F),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BillManagementScreen()),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Daily Analytics ───────────────────────────────────────────────────────────

class _AnalyticsCard extends ConsumerWidget {
  final AsyncValue<HomeAnalytics> analytics;

  const _AnalyticsCard({required this.analytics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF1A3C6E).withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3C6E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.query_stats,
                  size: 18, color: Color(0xFF1A3C6E)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Daily Activity',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1A3C6E),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () =>
                  ref.invalidate(homeAnalyticsProvider),
            ),
          ]),
          const SizedBox(height: 2),
          analytics.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Icon(Icons.error_outline, size: 18, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Could not load analytics: $e',
                    style: TextStyle(
                        fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              ]),
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yesterday · ${_fmtDay(data.day)} (IST)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 12),
                if (!data.hasAnyActivity)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No activity recorded for yesterday.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500),
                    ),
                  )
                else ...[
                  _AnalyticsGroup(
                    title: 'Students',
                    icon: Icons.people_alt,
                    color: const Color(0xFF1565C0),
                    stats: [
                      (label: 'Created', value: data.studentsCreated),
                      (label: 'Updated', value: data.studentsUpdated),
                      (label: 'Deleted', value: data.studentsDeleted),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _AnalyticsGroup(
                    title: 'Staff',
                    icon: Icons.badge,
                    color: const Color(0xFF2E7D32),
                    stats: [
                      (label: 'Created', value: data.staffCreated),
                      (label: 'Updated', value: data.staffUpdated),
                      (label: 'Deleted', value: data.staffDeleted),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _AnalyticsGroup(
                    title: 'Stock',
                    icon: Icons.inventory_2,
                    color: const Color(0xFF6A1B9A),
                    stats: [
                      (label: 'Inspections', value: data.inspectionsDone),
                      (label: 'Items Added', value: data.itemsAdded),
                      (label: 'Items Removed', value: data.itemsRemoved),
                      (label: 'Assignments', value: data.assignmentsDone),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDay(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}

class _AnalyticsGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<({String label, int value})> stats;

  const _AnalyticsGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in stats) _StatChip(label: s.label, value: s.value, color: color),
          ]),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '$value',
          style: TextStyle(
              fontWeight: FontWeight.w700, color: color, fontSize: 13),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.75)),
        ),
      ]),
    );
  }
}
class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
