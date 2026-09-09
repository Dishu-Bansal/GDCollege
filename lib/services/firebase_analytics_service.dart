import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gd_college/providers.dart';
import '../models/home_analytics.dart';
import '../repositories/analytics_repository.dart';

class FirebaseAnalyticsRepository implements AnalyticsRepository {
  final FirebaseFirestore _db = db;

  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// Boundaries of the previous calendar day in IST.
  ///
  /// Stored timestamps are ISO-8601 wall-clock strings (no timezone offset),
  /// so we compare against IST wall-clock boundaries.
  ({DateTime start, DateTime end}) _previousIstDay() {
    final nowIst = DateTime.now().toUtc().add(_istOffset);
    final start = DateTime(nowIst.year, nowIst.month, nowIst.day - 1);
    final end = DateTime(nowIst.year, nowIst.month, nowIst.day);
    return (start: start, end: end);
  }

  /// Boundaries of an arbitrary IST calendar day (time ignored).
  ({DateTime start, DateTime end}) _istDayRange(DateTime istDay) {
    final start = DateTime(istDay.year, istDay.month, istDay.day);
    final end = DateTime(istDay.year, istDay.month, istDay.day + 1);
    return (start: start, end: end);
  }

  /// Email of the user who performed the activity, or '' when unknown.
  String _actorOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      (doc.data()['changedBy'] as String?) ?? '';

  static void _add(Map<String, int> tally, String account, int amount) {
    tally[account] = (tally[account] ?? 0) + amount;
  }

  static int _sum(Map<String, int> tally) =>
      tally.values.fold(0, (a, b) => a + b);

  /// Folds the difference between [total] and what [tally] already accounts
  /// for into the '' (unknown-account) bucket, so breakdowns always add up
  /// to their total even when part of the source data lacks an actor.
  static void _foldUnattributed(Map<String, int> tally, int total) {
    final rest = total - _sum(tally);
    if (rest > 0) _add(tally, '', rest);
  }

  @override
  Future<HomeAnalytics> fetchPreviousDayAnalytics() async {
    final day = _previousIstDay();
    return _fetchForRange(day.start, day.end);
  }

  @override
  Future<HomeAnalytics> fetchDayAnalytics(DateTime istDay) async {
    final day = _istDayRange(istDay);
    return _fetchForRange(day.start, day.end);
  }

  Future<HomeAnalytics> _fetchForRange(DateTime start, DateTime end) async {
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final inspectionsFuture = _countCompletedInspections(startIso, endIso);
    // The range filters order by the same field, descending, so the queries
    // reuse the existing COLLECTION_GROUP DESCENDING indexes on `timestamp`
    // (the ones the app's global-log screens already rely on).
    final results = await Future.wait([
      _db
          .collectionGroup('studentLogs')
          .where('timestamp', isGreaterThanOrEqualTo: startIso)
          .where('timestamp', isLessThan: endIso)
          .orderBy('timestamp', descending: true)
          .get(),
      _db
          .collectionGroup('staffLogs')
          .where('timestamp', isGreaterThanOrEqualTo: startIso)
          .where('timestamp', isLessThan: endIso)
          .orderBy('timestamp', descending: true)
          .get(),
      _db
          .collectionGroup('stockLogs')
          .where('timestamp', isGreaterThanOrEqualTo: startIso)
          .where('timestamp', isLessThan: endIso)
          .orderBy('timestamp', descending: true)
          .get(),
      _db
          .collection('consumableAssignments')
          .where('assignedAt', isGreaterThanOrEqualTo: startIso)
          .where('assignedAt', isLessThan: endIso)
          .orderBy('assignedAt', descending: true)
          .get(),
    ]);
    final inspectionsDone = await inspectionsFuture;

    final studentLogs = results[0].docs;
    final staffLogs = results[1].docs;
    final stockLogs = results[2].docs;
    final assignments = results[3].docs;

    // ── Students: tally each create/update/delete by the acting account ──
    final studentsCreatedBy = <String, int>{};
    final studentsUpdatedBy = <String, int>{};
    final studentsDeletedBy = <String, int>{};
    for (final d in studentLogs) {
      final actor = _actorOf(d);
      switch (d.data()['action']) {
        case 'create':
          _add(studentsCreatedBy, actor, 1);
        case 'update':
          _add(studentsUpdatedBy, actor, 1);
        case 'delete':
          _add(studentsDeletedBy, actor, 1);
        default:
          break;
      }
    }

    // ── Staff: same as students ──────────────────────────────────────────
    final staffCreatedBy = <String, int>{};
    final staffUpdatedBy = <String, int>{};
    final staffDeletedBy = <String, int>{};
    for (final d in staffLogs) {
      final actor = _actorOf(d);
      switch (d.data()['action']) {
        case 'create':
          _add(staffCreatedBy, actor, 1);
        case 'update':
          _add(staffUpdatedBy, actor, 1);
        case 'delete':
          _add(staffDeletedBy, actor, 1);
        default:
          break;
      }
    }

    // ── Stock ────────────────────────────────────────────────────────────
    // The stockLogs of a day carry every item increase/decrease (each log
    // records the acting account). Inspection completions and consumable
    // assignments also write a dedicated stock log entry, which lets us
    // attribute those activities to an account too.
    final itemsAddedBy = <String, int>{};
    final itemsRemovedBy = <String, int>{};
    final inspectionsLoggedBy = <String, int>{};
    final assignmentsLoggedBy = <String, int>{};
    for (final d in stockLogs) {
      final data = d.data();
      final actor = _actorOf(d);
      final type = data['type'];
      final qty = (data['quantity'] as num?)?.toInt() ?? 0;
      final note = (data['note'] as String?) ?? '';
      if (type == 'increase' && qty > 0) {
        _add(itemsAddedBy, actor, qty);
      } else if (type == 'decrease' && qty > 0) {
        _add(itemsRemovedBy, actor, qty);
      }
      if (type == 'inspection' && note.startsWith('Inspection completed')) {
        _add(inspectionsLoggedBy, actor, 1);
      } else if (type == 'decrease' && note.startsWith('Assigned to ')) {
        _add(assignmentsLoggedBy, actor, 1);
      }
    }

    // Inspections/assignments totals come from their own collections (which
    // do not always record an actor); attribute what the daily logs explain
    // and fold any remainder into the unknown-account bucket.
    final inspectionsBy = Map<String, int>.of(inspectionsLoggedBy);
    _foldUnattributed(inspectionsBy, inspectionsDone);
    final assignmentsBy = Map<String, int>.of(assignmentsLoggedBy);
    _foldUnattributed(assignmentsBy, assignments.length);

    return HomeAnalytics(
      day: start,
      studentsCreated: _sum(studentsCreatedBy),
      studentsUpdated: _sum(studentsUpdatedBy),
      studentsDeleted: _sum(studentsDeletedBy),
      staffCreated: _sum(staffCreatedBy),
      staffUpdated: _sum(staffUpdatedBy),
      staffDeleted: _sum(staffDeletedBy),
      inspectionsDone: inspectionsDone,
      itemsAdded: _sum(itemsAddedBy),
      itemsRemoved: _sum(itemsRemovedBy),
      assignmentsDone: assignments.length,
      studentsCreatedAccounts: accountSharesFromTally(studentsCreatedBy),
      studentsUpdatedAccounts: accountSharesFromTally(studentsUpdatedBy),
      studentsDeletedAccounts: accountSharesFromTally(studentsDeletedBy),
      staffCreatedAccounts: accountSharesFromTally(staffCreatedBy),
      staffUpdatedAccounts: accountSharesFromTally(staffUpdatedBy),
      staffDeletedAccounts: accountSharesFromTally(staffDeletedBy),
      inspectionsAccounts: accountSharesFromTally(inspectionsBy),
      itemsAddedAccounts: accountSharesFromTally(itemsAddedBy),
      itemsRemovedAccounts: accountSharesFromTally(itemsRemovedBy),
      assignmentsAccounts: accountSharesFromTally(assignmentsBy),
    );
  }

  /// Counts inspections completed during [startIso]..[endIso].
  ///
  /// Inspections live in `rooms/{roomId}/inspections` subcollections and are
  /// stamped `status: 'completed'` with `completedAt` on completion, so we
  /// walk the building → floor → room tree and read each room's inspections.
  Future<int> _countCompletedInspections(String startIso, String endIso) async {
    final buildings = await _db.collection('buildings').get();
    final roomQueries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final b in buildings.docs) {
      final floors = await _db
          .collection('buildings')
          .doc(b.id)
          .collection('floors')
          .get();
      for (final f in floors.docs) {
        final rooms = await _db
            .collection('buildings')
            .doc(b.id)
            .collection('floors')
            .doc(f.id)
            .collection('rooms')
            .get();
        for (final r in rooms.docs) {
          roomQueries.add(
            _db
                .collection('buildings')
                .doc(b.id)
                .collection('floors')
                .doc(f.id)
                .collection('rooms')
                .doc(r.id)
                .collection('inspections')
                .where('completedAt', isGreaterThanOrEqualTo: startIso)
                .where('completedAt', isLessThan: endIso)
                .get(),
          );
        }
      }
    }

    final snapshots = await Future.wait(roomQueries);
    var count = 0;
    for (final snap in snapshots) {
      for (final d in snap.docs) {
        if (d.data()['status'] == 'completed') count++;
      }
    }
    return count;
  }
}
