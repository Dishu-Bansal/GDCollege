import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bill_management/screens/bill_management_screen.dart';
import '../models/home_analytics.dart';
import '../providers.dart';
import '../student_management/screens/student_list_screen.dart';
import '../staff_management/screens/staff_list_screen.dart';
import '../stock_management/screens/buildings_screen.dart';
import '../visitor_management/screens/visitor_management_screen.dart';
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
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
                    MaterialPageRoute(
                      builder: (_) => const StudentListScreen(),
                    ),
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
                      builder: (_) => const BillManagementScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _NavCard(
                  icon: Icons.how_to_reg,
                  label: 'Visitor Management',
                  color: const Color(0xFFAD1457),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VisitorManagementScreen(),
                    ),
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
    final selectedDay = ref.watch(selectedAnalyticsDateProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1A3C6E).withValues(alpha: 0.15),
        ),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3C6E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.query_stats,
                  size: 18,
                  color: Color(0xFF1A3C6E),
                ),
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
                tooltip: 'Choose date',
                icon: const Icon(Icons.calendar_month, size: 20),
                onPressed: () => _pickDay(context, ref),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => ref.invalidate(homeAnalyticsProvider),
              ),
            ],
          ),
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
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Could not load analytics: $e',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayCaption(data.day),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                    if (selectedDay != null)
                      GestureDetector(
                        onTap: () => ref
                            .read(selectedAnalyticsDateProvider.notifier)
                            .state = null,
                        child: Text(
                          'Back to yesterday',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF1A3C6E),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!data.hasAnyActivity)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No activity recorded ${_dayPreposition(data.day)}.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                else ...[
                  _AnalyticsGroup(
                    title: 'Students',
                    icon: Icons.people_alt,
                    color: const Color(0xFF1565C0),
                    stats: [
                      (
                        label: 'Created',
                        value: data.studentsCreated,
                        accounts: data.studentsCreatedAccounts,
                      ),
                      (
                        label: 'Updated',
                        value: data.studentsUpdated,
                        accounts: data.studentsUpdatedAccounts,
                      ),
                      (
                        label: 'Deleted',
                        value: data.studentsDeleted,
                        accounts: data.studentsDeletedAccounts,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _AnalyticsGroup(
                    title: 'Staff',
                    icon: Icons.badge,
                    color: const Color(0xFF2E7D32),
                    stats: [
                      (
                        label: 'Created',
                        value: data.staffCreated,
                        accounts: data.staffCreatedAccounts,
                      ),
                      (
                        label: 'Updated',
                        value: data.staffUpdated,
                        accounts: data.staffUpdatedAccounts,
                      ),
                      (
                        label: 'Deleted',
                        value: data.staffDeleted,
                        accounts: data.staffDeletedAccounts,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _AnalyticsGroup(
                    title: 'Stock',
                    icon: Icons.inventory_2,
                    color: const Color(0xFF6A1B9A),
                    stats: [
                      (
                        label: 'Inspections',
                        value: data.inspectionsDone,
                        accounts: data.inspectionsAccounts,
                      ),
                      (
                        label: 'Items Added',
                        value: data.itemsAdded,
                        accounts: data.itemsAddedAccounts,
                      ),
                      (
                        label: 'Items Removed',
                        value: data.itemsRemoved,
                        accounts: data.itemsRemovedAccounts,
                      ),
                      (
                        label: 'Assignments',
                        value: data.assignmentsDone,
                        accounts: data.assignmentsAccounts,
                      ),
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

  String _fmtDay(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static const _istOffset = Duration(hours: 5, minutes: 30);

  /// Today in IST, truncated to the calendar day.
  DateTime _todayIst() {
    final nowIst = DateTime.now().toUtc().add(_istOffset);
    return DateTime(nowIst.year, nowIst.month, nowIst.day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Header caption for the analytics day, e.g. "Yesterday · 8/9/2026 (IST)"
  /// or "7/9/2026 (IST)". Keeps the old "Yesterday" wording as the default.
  String _dayCaption(DateTime day) {
    final today = _todayIst();
    final yesterday =
        DateTime(today.year, today.month, today.day - 1);
    if (_isSameDay(day, yesterday)) {
      return 'Yesterday · ${_fmtDay(day)} (IST)';
    }
    if (_isSameDay(day, today)) {
      return 'Today · ${_fmtDay(day)} (IST)';
    }
    return '${_fmtDay(day)} (IST)';
  }

  /// "for yesterday" / "for today" / "on 7/9/2026" for the empty state.
  String _dayPreposition(DateTime day) {
    final today = _todayIst();
    final yesterday =
        DateTime(today.year, today.month, today.day - 1);
    if (_isSameDay(day, yesterday)) return 'for yesterday';
    if (_isSameDay(day, today)) return 'for today';
    return 'on ${_fmtDay(day)}';
  }

  /// Opens a date picker (past days up to today, IST) and stores the
  /// chosen day so [homeAnalyticsProvider] reloads for it.
  Future<void> _pickDay(BuildContext context, WidgetRef ref) async {
    final today = _todayIst();
    final current = ref.read(selectedAnalyticsDateProvider) ??
        DateTime(today.year, today.month, today.day - 1);
    final initial = current.isAfter(today) ? today : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year, today.month, today.day - 180),
      lastDate: today,
      helpText: 'Show activity for',
    );
    if (picked != null) {
      ref.read(selectedAnalyticsDateProvider.notifier).state =
          DateTime(picked.year, picked.month, picked.day);
    }
  }
}

class _AnalyticsGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<({String label, int value, List<AccountAmount> accounts})> stats;

  const _AnalyticsGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final hasBreakdowns = stats.any((s) => s.accounts.isNotEmpty);
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
          Row(
            children: [
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
            ],
          ),
          const SizedBox(height: 8),
          if (!hasBreakdowns)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in stats)
                  _StatChip(label: s.label, value: s.value, color: color),
              ],
            )
          else
            for (var i = 0; i < stats.length; i++) ...[
              _ActivityBox(
                label: stats[i].label,
                value: stats[i].value,
                accounts: stats[i].accounts,
                color: color,
              ),
              if (i != stats.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// One activity in a single box: the total on the first row and the
/// account-wise breakdown (each account's share) listed beneath it, e.g.
/// "Total 20" followed by "email1 13 / email2 4 / email3 3".
class _ActivityBox extends StatelessWidget {
  final String label;
  final int value;
  final List<AccountAmount> accounts;
  final Color color;

  const _ActivityBox({
    required this.label,
    required this.value,
    required this.accounts,
    required this.color,
  });

  String _accountLabel(String account) =>
      account.isEmpty ? 'Unknown account' : account;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total row: activity name on the left, "Total" + count on the right.
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: color,
                  ),
                ),
              ),
              Text(
                'Total',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 6),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          if (accounts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(height: 1, color: color.withValues(alpha: 0.15)),
            const SizedBox(height: 2),
            for (final a in accounts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _accountLabel(a.account),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${a.amount}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
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
