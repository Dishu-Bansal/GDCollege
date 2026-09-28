import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/widgets/access_gate.dart';
import '../services/session_service.dart';
import '../widgets/drawer.dart';

/// Verification screen: one consolidated row per user (total online time
/// for the day). Tapping a user opens a popup with each individual session.
/// Answers "User 1 says he worked 8 hours yesterday — is that right?"
class UserSessionsScreen extends ConsumerStatefulWidget {
  const UserSessionsScreen({super.key});

  @override
  ConsumerState<UserSessionsScreen> createState() =>
      _UserSessionsScreenState();
}

class _UserSessionsScreenState extends ConsumerState<UserSessionsScreen> {
  DateTime _day = DateTime.now();

  void _shiftDay(int delta) {
    setState(() => _day = _day.add(Duration(days: delta)));
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final diff = today.difference(d).inDays;
    final date = '${d.day}/${d.month}/${d.year}';
    if (diff == 0) return 'Today · $date';
    if (diff == 1) return 'Yesterday · $date';
    return date;
  }

  void _showUserSessions(
      String email, List<Map<String, dynamic>> sessions) {
    final total = sessions.fold(
        Duration.zero, (a, s) => a + SessionService.durationOf(s));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sessions',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 2),
            Text(
              '${email.isEmpty ? 'Unknown user' : email} · '
              '${SessionService.formatDuration(total)} total',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: sessions.isEmpty
              ? const Text('No sessions.',
                  style: TextStyle(color: Colors.grey))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _SessionCard(session: sessions[i]),
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

  @override
  Widget build(BuildContext context) {
    return AccessGate(
      module: 'User Sessions',
      canAccess: (s) => s.isAdmin,
      drawer: getSideDrawer(context),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final service = ref.watch(sessionServiceProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('User Sessions',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      drawer: getSideDrawer(context),
      body: Column(
        children: [
          _DayBar(dayLabel: _dayLabel(_day), onShift: _shiftDay),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: service.watchDay(_day),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFF1A3C6E)),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)),
                  );
                }
                final sessions = snapshot.data ?? [];
                if (sessions.isEmpty) {
                  return _emptyDay();
                }

                // Consolidate: one row per user with day total.
                final byUser = <String, List<Map<String, dynamic>>>{};
                for (final s in sessions) {
                  final email = ((s['email'] ?? '') as String);
                  (byUser[email] ??= []).add(s);
                }
                final emails = byUser.keys.toList()..sort();
                final grand = sessions.fold(Duration.zero,
                    (a, s) => a + SessionService.durationOf(s));

                return Column(
                  children: [
                    _GrandTotal(total: grand),
                    Expanded(
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: emails.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final email = emails[i];
                          final userSessions = byUser[email]!;
                          final total = userSessions.fold(
                              Duration.zero,
                              (a, s) =>
                                  a + SessionService.durationOf(s));
                          return _UserRow(
                            email: email,
                            total: total,
                            sessionCount: userSessions.length,
                            onTap: () => _showUserSessions(
                                email, userSessions),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyDay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No sessions on this day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Logins are recorded automatically',
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ── Day selector ─────────────────────────────────────────────────────────────

class _DayBar extends StatelessWidget {
  final String dayLabel;
  final void Function(int) onShift;
  const _DayBar({required this.dayLabel, required this.onShift});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onShift(-1),
            tooltip: 'Previous day',
          ),
          Expanded(
            child: Text(
              dayLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF1A3C6E),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onShift(1),
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}

// ── Grand day total ──────────────────────────────────────────────────────────

class _GrandTotal extends StatelessWidget {
  final Duration total;
  const _GrandTotal({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.people_outline,
              size: 16, color: Color(0xFF1A3C6E)),
          const SizedBox(width: 6),
          const Text(
            'All users',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A3C6E),
                fontSize: 13),
          ),
          const Spacer(),
          Text(
            'Day total: ${SessionService.formatDuration(total)}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

// ── Consolidated user row ────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  final String email;
  final Duration total;
  final int sessionCount;
  final VoidCallback onTap;

  const _UserRow({
    required this.email,
    required this.total,
    required this.sessionCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1A3C6E),
          child: Text(
            email.isNotEmpty ? email[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          email.isEmpty ? 'Unknown user' : email,
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$sessionCount session${sessionCount == 1 ? '' : 's'} · tap for details',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3C6E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF1A3C6E).withValues(alpha: 0.3)),
          ),
          child: Text(
            SessionService.formatDuration(total),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A3C6E),
                fontSize: 13),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── Session segment card (used inside the popup) ─────────────────────────────

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final reason = session['endReason'] as String?;
    final duration = SessionService.durationOf(session);
    final color = reason == null
        ? Colors.green.shade700
        : const Color(0xFF1A3C6E);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.login,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  SessionService.formatClock(session['loginAt']),
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600),
                ),
                const Text('  →  ',
                    style: TextStyle(color: Colors.grey)),
                Icon(Icons.logout,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  reason == null
                      ? 'ongoing'
                      : SessionService.formatClock(session['endAt'] ??
                          session['lastActiveAt']),
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  SessionService.formatDuration(duration),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                SessionEndReason.label(reason),
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
