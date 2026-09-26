import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/session_service.dart';
import '../widgets/drawer.dart';

/// Verification screen: every login→end segment of every user, grouped by
/// day with per-user totals. Answers "User 1 says he worked 8 hours
/// yesterday — is that right?"
class UserSessionsScreen extends ConsumerStatefulWidget {
  const UserSessionsScreen({super.key});

  @override
  ConsumerState<UserSessionsScreen> createState() =>
      _UserSessionsScreenState();
}

class _UserSessionsScreenState extends ConsumerState<UserSessionsScreen> {
  DateTime _day = DateTime.now();
  String? _selectedEmail; // null = all users

  void _shiftDay(int delta) {
    setState(() {
      _day = _day.add(Duration(days: delta));
      _selectedEmail = null;
    });
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

  @override
  Widget build(BuildContext context) {
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

                // Per-user totals for the day.
                final totals = <String, Duration>{};
                for (final s in sessions) {
                  final email = (s['email'] ?? '') as String;
                  totals[email] =
                      (totals[email] ?? Duration.zero) +
                          SessionService.durationOf(s);
                }
                final emails = totals.keys.toList()..sort();
                if (_selectedEmail != null &&
                    !emails.contains(_selectedEmail)) {
                  _selectedEmail = null;
                }
                final visible = _selectedEmail == null
                    ? sessions
                    : sessions
                        .where((s) => s['email'] == _selectedEmail)
                        .toList();

                return Column(
                  children: [
                    _UserFilter(
                      emails: emails,
                      totals: totals,
                      selected: _selectedEmail,
                      onChanged: (v) =>
                          setState(() => _selectedEmail = v),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _SessionCard(session: visible[i]),
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

// ── User filter + totals ─────────────────────────────────────────────────────

class _UserFilter extends StatelessWidget {
  final List<String> emails;
  final Map<String, Duration> totals;
  final String? selected;
  final void Function(String?) onChanged;

  const _UserFilter({
    required this.emails,
    required this.totals,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final grand = totals.values
        .fold(Duration.zero, (a, b) => a + b);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline,
                  size: 16, color: Color(0xFF1A3C6E)),
              const SizedBox(width: 6),
              const Text(
                'User',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A3C6E),
                    fontSize: 13),
              ),
              const Spacer(),
              Text(
                'Day total: ${SessionService.formatDuration(grand)}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selected,
            isDense: true,
            isExpanded: true,
            style:
                const TextStyle(fontSize: 13, color: Colors.black87),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('All users')),
              for (final e in emails)
                DropdownMenuItem(
                  value: e,
                  child: Text(
                    '${e.isEmpty ? 'Unknown' : e} · ${SessionService.formatDuration(totals[e] ?? Duration.zero)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Session segment card ─────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final email = ((session['email'] ?? '') as String);
    final reason = session['endReason'] as String?;
    final duration = SessionService.durationOf(session);
    final color = reason == null ? Colors.green.shade700 : const Color(0xFF1A3C6E);
    return Card(
      elevation: 0,
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
                Expanded(
                  child: Text(
                    email.isEmpty ? 'Unknown user' : email,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    SessionService.formatDuration(duration),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.login,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  SessionService.formatClock(session['loginAt']),
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 12),
                Icon(Icons.logout,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  reason == null
                      ? 'ongoing'
                      : SessionService.formatClock(session['endAt'] ??
                          session['lastActiveAt']),
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    SessionEndReason.label(reason),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            if ((session['platform'] ?? '') != '') ...[
              const SizedBox(height: 4),
              Text(
                'Platform: ${session['platform']}',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
