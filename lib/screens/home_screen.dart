import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../access/access_service.dart';
import '../access/app_session.dart';
import '../access/screens/access_management_screen.dart';
import '../bill_management/screens/bill_management_screen.dart';
import '../lead_management/screens/lead_management_screen.dart';
import '../models/home_analytics.dart';
import '../providers.dart';
import '../student_docs/screens/student_docs_screen.dart';
import '../student_management/screens/student_list_screen.dart';
import '../staff_management/screens/staff_list_screen.dart';
import '../stock_management/screens/buildings_screen.dart';
import '../visitor_management/screens/visitor_management_screen.dart';
import 'user_sessions_screen.dart';
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
          child: ConstrainedBox(
            // Keeps lines short and centered on wide laptop screens
            // instead of stretching edge to edge.
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Compact welcome header: one row, not a giant banner.
                  const _HomeHeader(),
                  const SizedBox(height: 16),
                  // Daily analytics (previous calendar day, IST)
                  _AnalyticsCard(analytics: analytics),
                  const SizedBox(height: 20),
                  // Navigation tiles (gated by live access flags)
                  const _ModuleTiles(),
                  // Admin tiles (visible to dishubansal@lklms.com only)
                  const _AdminTiles(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One compact header row: app mark + society name + signed-in account.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.school,
            size: 26,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lala Kundan Lal Memorial Society',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: TextStyle(
                      fontSize: 11.5, color: Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
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
          const SizedBox(height: 6),
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
                // Date pill + reset link share one compact row.
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3C6E)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _dayCaption(data.day),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A3C6E),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (selectedDay != null)
                      GestureDetector(
                        onTap: () => ref
                            .read(selectedAnalyticsDateProvider.notifier)
                            .state = null,
                        child: const Text(
                          'Back to yesterday',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF1A3C6E),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
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
                        label: 'Items Deleted',
                        value: data.itemsDeleted,
                        accounts: data.itemsDeletedAccounts,
                      ),
                      (
                        label: 'Assignments',
                        value: data.assignmentsDone,
                        accounts: data.assignmentsAccounts,
                      ),
                    ],
                  ),
                  _AnalyticsGroup(
                    title: 'DMC & Degrees',
                    icon: Icons.folder_shared_outlined,
                    color: const Color(0xFF4E342E),
                    stats: [
                      (
                        label: 'Docs Stocked',
                        value: data.docsStocked,
                        accounts: data.docsStockedAccounts,
                      ),
                      (
                        label: 'Docs Issued',
                        value: data.docsIssued,
                        accounts: data.docsIssuedAccounts,
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

/// One module group in Daily Activity: a collapsible section whose header
/// shows the group's total at a glance. Groups and metrics with zero
/// activity are hidden so quiet days stay short.
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
    final active = stats.where((s) => s.value > 0).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    final total = active.fold(0, (sum, s) => sum + s.value);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding:
            const EdgeInsets.fromLTRB(12, 0, 12, 10),
        shape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        children: [
          for (var i = 0; i < active.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 13, color: color.withValues(alpha: 0.12)),
            _MetricRow(
              label: active[i].label,
              value: active[i].value,
              accounts: active[i].accounts,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

/// One metric row: label + per-account shares on the left, total on the
/// right — e.g. "Updated … 7" with "a@x (4) · b@y (3)" beneath it.
class _MetricRow extends StatelessWidget {
  final String label;
  final int value;
  final List<AccountAmount> accounts;
  final Color color;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.accounts,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final shares = accounts
        .map((a) =>
            '${(a.account.isEmpty ? 'Unknown' : a.account)} (${a.amount})')
        .join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: Colors.grey.shade800,
                ),
              ),
              if (shares.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    shares,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Module navigation tiles (access-gated) ────────────────────────────────

/// One module's navigation target, resolved against the live session.
class _ModuleTarget {
  final IconData icon;
  final String label;
  final Color color;
  final bool Function(AppSession) visible;
  final Widget Function() open;

  const _ModuleTarget({
    required this.icon,
    required this.label,
    required this.color,
    required this.visible,
    required this.open,
  });
}

const _moduleTargets = [
  _ModuleTarget(
    icon: Icons.people_alt,
    label: 'Students',
    color: Color(0xFF1565C0),
    visible: _showStudents,
    open: StudentListScreen.new,
  ),
  _ModuleTarget(
    icon: Icons.folder_shared_outlined,
    label: 'DMC & Degrees',
    color: Color(0xFF4E342E),
    visible: _showStudentDocs,
    open: StudentDocsScreen.new,
  ),
  _ModuleTarget(
    icon: Icons.badge,
    label: 'Staff',
    color: Color(0xFF2E7D32),
    visible: _showStaff,
    open: StaffListScreen.new,
  ),
  _ModuleTarget(
    icon: Icons.inventory_2,
    label: 'Stock',
    color: Color(0xFF6A1B9A),
    visible: _showStock,
    open: BuildingsScreen.new,
  ),
  _ModuleTarget(
    icon: Icons.receipt_long,
    label: 'Bills',
    color: Color(0xFF00838F),
    visible: _showBills,
    open: BillManagementScreen.new,
  ),
  _ModuleTarget(
    icon: Icons.how_to_reg,
    label: 'Visitors',
    color: Color(0xFFAD1457),
    visible: _showVisitors,
    open: VisitorManagementScreen.new,
  ),
  _ModuleTarget(
    icon: Icons.person_search_outlined,
    label: 'Leads',
    color: Color(0xFF00695C),
    visible: _showLeads,
    open: LeadManagementScreen.new,
  ),
];

bool _showStudents(AppSession s) => s.canAccessStudents;
bool _showStudentDocs(AppSession s) => s.canAccessStudentDocs;
bool _showStaff(AppSession s) => s.canAccessStaff;
bool _showStock(AppSession s) => s.canAccessStock;
bool _showBills(AppSession s) => s.canAccessBills;
bool _showVisitors(AppSession s) => s.canAccessVisitors;
bool _showLeads(AppSession s) => s.canAccessLeads;

const _adminTargets = [
  _ModuleTarget(
    icon: Icons.access_time,
    label: 'Login Sessions',
    color: Color(0xFF4E342E),
    visible: _showAdmin,
    open: UserSessionsScreen.new,
  ),
  _ModuleTarget(
    icon: Icons.admin_panel_settings_outlined,
    label: 'Access Control',
    color: Color(0xFF37474F),
    visible: _showAdmin,
    open: AccessManagementScreen.new,
  ),
];

bool _showAdmin(AppSession s) => s.isAdmin;

class _ModuleTiles extends StatelessWidget {
  const _ModuleTiles();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSession?>(
      stream: AccessService.watchAccessShared(),
      builder: (context, snap) {
        final session = snap.data;
        final tiles = _moduleTargets
            .where((t) => session == null || t.visible(session))
            .toList();
        if (session != null && tiles.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'You currently have no module access.\nPlease contact the admin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          );
        }
        return _TileGrid(
          tiles: tiles,
          open: (t) => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => t.open()),
          ),
        );
      },
    );
  }
}

// ── Admin tiles (admin only) ─────────────────────────────────────────────────

class _AdminTiles extends StatelessWidget {
  const _AdminTiles();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSession?>(
      stream: AccessService.watchAccessShared(),
      builder: (context, snap) {
        final session = snap.data;
        final isAdmin = session?.isAdmin == true ||
            AccessService.isAdminEmail(
                FirebaseAuth.instance.currentUser?.email);
        if (!isAdmin) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Admin',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            _TileGrid(
              tiles: _adminTargets,
              open: (t) => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => t.open()),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Responsive tile layout: a compact 2-column grid on laptop/wide
/// screens, single-column rows on phones.
class _TileGrid extends StatelessWidget {
  final List<_ModuleTarget> tiles;
  final void Function(_ModuleTarget) open;

  const _TileGrid({required this.tiles, required this.open});

  @override
  Widget build(BuildContext context) {
return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _ModuleTile(
                    target: tiles[i], onTap: () => open(tiles[i])),
              ],
            ],
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 64,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, i) => _ModuleTile(
              target: tiles[i], onTap: () => open(tiles[i])),
        );
      },
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final _ModuleTarget target;
  final VoidCallback onTap;

  const _ModuleTile({required this.target, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: target.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child:
                    Icon(target.icon, color: target.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  target.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
