import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_session.dart';
import '../providers.dart';
import '../screens/login_screen.dart';

/// Global navigator key so the inactivity timeout can send the user back to
/// the login screen from anywhere (no BuildContext needed).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Idle time after which the user is signed out automatically.
const Duration kInactivityTimeout = Duration(minutes: 5);

/// How often an active session refreshes its `lastActiveAt` stamp while the
/// app is in the foreground. Session length is accurate to about this
/// granularity when a tab is killed without warning.
const Duration kSessionHeartbeat = Duration(minutes: 1);

/// Why a session segment ended. Shown verbatim in the verification screen.
class SessionEndReason {
  static const String logout = 'logout';
  static const String timeout = 'timeout';
  static const String backgrounded = 'backgrounded';
  static const String closed = 'closed';

  static String label(String? reason) {
    switch (reason) {
      case logout:
        return 'Logged out';
      case timeout:
        return 'Auto logout (idle 5 min)';
      case backgrounded:
        return 'Tab backgrounded';
      case closed:
        return 'Tab closed';
      default:
        return 'Active';
    }
  }
}

/// Records one login→end segment per user in the `userSessions` collection
/// and signs the user out after [kInactivityTimeout] without interaction.
///
/// Document shape:
/// ```json
/// { "userId": "...", "email": "...",
///   "loginAt": <Timestamp>, "lastActiveAt": <Timestamp>,
///   "endAt": <Timestamp|null>, "endReason": "logout|timeout|backgrounded|closed|null",
///   "platform": "android|ios|windows|web|..." }
/// ```
/// Segment length = (endAt ?? lastActiveAt ?? loginAt) − loginAt.
class SessionService with WidgetsBindingObserver {
  SessionService._();
  static final SessionService instance = SessionService._();

  final FirebaseFirestore _firestore = db;

  String? _sessionId;
  Timer? _heartbeat;
  Timer? _inactivity;
  DateTime _lastActivity = DateTime.now();
  bool _attached = false;

  // ── Lifecycle wiring ───────────────────────────────────────────────────

  /// Call once from main() after Firebase init.
  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  bool _onKey(KeyEvent event) {
    markActivity();
    return false; // never swallow the key
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Web: tab hidden → `hidden`; mobile: app backgrounded → paused/inactive.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _onBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onBackgrounded() async {
    _inactivity?.cancel();
    _heartbeat?.cancel();
    await endSession(SessionEndReason.backgrounded);
  }

  Future<void> _onResumed() async {
    // Still signed in (Firebase Auth persists) but the previous segment was
    // closed when the tab went away — open a fresh segment.
    if (UserSession().currentUser != null && _sessionId == null) {
      await startSession(resumed: true);
    }
  }

  // ── Session recording ────────────────────────────────────────────────

  /// Opens a new segment for the signed-in user. Any segment left open
  /// (previous tab closed without notice) is first closed as `closed` so
  /// hours never double-count.
  Future<void> startSession({bool resumed = false}) async {
    final user = UserSession().currentUser;
    if (user == null) return;
    await _closeStragglers(user.uid);
    final now = DateTime.now();
    final doc = await _firestore.collection('userSessions').add({
      'userId': user.uid,
      'email': user.email ?? '',
      'loginAt': Timestamp.fromDate(now),
      'lastActiveAt': Timestamp.fromDate(now),
      'endAt': null,
      'endReason': null,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'resumed': resumed,
    });
    _sessionId = doc.id;
    _lastActivity = now;
    _startHeartbeat();
    _resetInactivityTimer();
  }

  /// Closes open segments of [uid] left behind by killed tabs/windows.
  /// Their length is bounded by the last heartbeat (~1 min granularity).
  Future<void> _closeStragglers(String uid) async {
    try {
      final open = await _firestore
          .collection('userSessions')
          .where('userId', isEqualTo: uid)
          .where('endAt', isNull: true)
          .get();
      for (final d in open.docs) {
        final data = d.data();
        final lastActive =
            (data['lastActiveAt'] as Timestamp?)?.toDate() ??
                (data['loginAt'] as Timestamp?)?.toDate() ??
                DateTime.now();
        await d.reference.update({
          'endAt': Timestamp.fromDate(lastActive),
          'endReason': SessionEndReason.closed,
        });
      }
    } catch (_) {
      // Best effort — a failed cleanup must never block login.
    }
  }

  /// Ends the current segment, if any.
  Future<void> endSession(String reason) async {
    final id = _sessionId;
    _sessionId = null;
    _heartbeat?.cancel();
    _inactivity?.cancel();
    if (id == null) return;
    try {
      await _firestore.collection('userSessions').doc(id).update({
        'endAt': Timestamp.fromDate(DateTime.now()),
        'endReason': reason,
      });
    } catch (_) {
      // Best effort (e.g. tab already gone) — never crash logout.
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(kSessionHeartbeat, (_) async {
      final id = _sessionId;
      if (id == null || UserSession().currentUser == null) return;
      try {
        await _firestore.collection('userSessions').doc(id).update({
          'lastActiveAt': Timestamp.fromDate(DateTime.now()),
        });
      } catch (_) {
        // Offline / gone tab — the next successful write bounds the segment.
      }
    });
  }

  // ── Inactivity auto logout ───────────────────────────────────────────

  /// Call on every user interaction (pointer, key, scroll). Throttled to
  /// avoid rebuilding the timer on every mouse-move event.
  void markActivity() {
    final now = DateTime.now();
    if (now.difference(_lastActivity) < const Duration(seconds: 1)) return;
    _lastActivity = now;
    if (_sessionId != null) _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivity?.cancel();
    _inactivity = Timer(kInactivityTimeout, _onTimeout);
  }

  Future<void> _onTimeout() async {
    if (_sessionId == null || UserSession().currentUser == null) return;
    await endSession(SessionEndReason.timeout);
    await UserSession().logOut();
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginPage(
          notice: 'You were signed out after 5 minutes of inactivity.',
        ),
      ),
      (_) => false,
    );
  }

  /// Manual logout: closes the segment, then signs out.
  Future<void> logout() async {
    await endSession(SessionEndReason.logout);
    await UserSession().logOut();
  }

  // ── Verification reads ─────────────────────────────────────────────

  /// All segments whose login falls inside [day] (local calendar day),
  /// newest first. Filter by user client-side (volume is tiny).
  Stream<List<Map<String, dynamic>>> watchDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _firestore
        .collection('userSessions')
        .where('loginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('loginAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('loginAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .handleError((_) => <Map<String, dynamic>>[]);
  }

  /// Segment length. Open segments are measured to their last heartbeat.
  static Duration durationOf(Map<String, dynamic> session) {
    DateTime? ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.tryParse('$v');
    final login = ts(session['loginAt']);
    if (login == null) return Duration.zero;
    final end = ts(session['endAt']) ??
        ts(session['lastActiveAt']) ??
        login;
    final d = end.difference(login);
    return d.isNegative ? Duration.zero : d;
  }

  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  static String formatClock(dynamic ts) {
    DateTime? dt =
        ts is Timestamp ? ts.toDate() : DateTime.tryParse('$ts');
    if (dt == null) return '—';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

final sessionServiceProvider = Provider<SessionService>((_) => SessionService.instance);

// ── App-wide interaction detector ──────────────────────────────────────────
// Wrap the whole app (MaterialApp.builder) so taps, mouse moves, scrolls and
// keys on ANY route reset the inactivity timer.

class SessionActivityDetector extends StatelessWidget {
  final Widget? child;
  const SessionActivityDetector({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => SessionService.instance.markActivity(),
      onPointerMove: (_) => SessionService.instance.markActivity(),
      onPointerHover: (_) => SessionService.instance.markActivity(),
      onPointerSignal: (_) => SessionService.instance.markActivity(),
      child: child,
    );
  }
}
