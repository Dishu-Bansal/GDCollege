import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gd_college/providers.dart';
import 'package:gd_college/utils/timestamps.dart';
import '../models/home_analytics.dart';
import '../repositories/analytics_repository.dart';

class FirebaseAnalyticsRepository implements AnalyticsRepository {
  final FirebaseFirestore _db = db;

  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// The IST calendar day containing [instant], as a pair of real instants:
  /// IST midnight boundaries expressed in UTC.
  static ({DateTime start, DateTime end}) _istDayOf(DateTime instant) {
    final ist = instant.toUtc().add(_istOffset);
    final startUtc =
        DateTime.utc(ist.year, ist.month, ist.day).subtract(_istOffset);
    return (start: startUtc, end: startUtc.add(const Duration(days: 1)));
  }

  /// The IST calendar day described by the y/m/d of [istDay].
  static ({DateTime start, DateTime end}) _istDayRange(DateTime istDay) {
    final startUtc =
        DateTime.utc(istDay.year, istDay.month, istDay.day)
            .subtract(_istOffset);
    return (start: startUtc, end: startUtc.add(const Duration(days: 1)));
  }

  /// True when [raw] (a stored timestamp of any supported shape) falls inside
  /// the [start]..[end) UTC window.
  static bool _inWindow(Object? raw, DateTime start, DateTime end) {
    final at = parseTimestamp(raw)?.toUtc();
    return at != null && !at.isBefore(start) && at.isBefore(end);
  }

  /// Widened string bounds used to select candidate rows server-side.
  ///
  /// New records are UTC strings, but legacy rows hold naive local wall-clock
  /// strings, so a lexicographic comparison with the exact UTC window can sit
  /// nearly a timezone away from the true instant. A one-day pad on both sides
  /// plus the [parseTimestamp]-based [_inWindow] filter keeps the result exact
  /// for both shapes while staying on existing single-field indexes.
  static ({String start, String end}) _queryBounds(DateTime start, DateTime end) => (
        start: start.subtract(const Duration(days: 1)).toIso8601String(),
        end: end.add(const Duration(days: 1)).toIso8601String(),
      );

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
    final today = _istDayOf(DateTime.now());
    final previousDayStart = today.start.subtract(const Duration(days: 1));
    return _fetchForRange(previousDayStart, today.start);
  }

  @override
  Future<HomeAnalytics> fetchDayAnalytics(DateTime istDay) async {
    final day = _istDayRange(istDay);
    return _fetchForRange(day.start, day.end);
  }

  Future<HomeAnalytics> _fetchForRange(DateTime start, DateTime end) async {
    final bounds = _queryBounds(start, end);

    final inspectionsFuture = _countCompletedInspections(start, end, bounds);
    // The range filters order by the same field, descending, so the queries
    // reuse the existing COLLECTION_GROUP DESCENDING indexes on `timestamp`
    // (the ones the app's global-log screens already rely on). docLogs is
    // a top-level collection: range + orderBy on the single `timestamp`
    // field needs no composite index.
    final results = await Future.wait([
      _db
          .collectionGroup('studentLogs')
          .where('timestamp', isGreaterThanOrEqualTo: bounds.start)
          .where('timestamp', isLessThan: bounds.end)
          .orderBy('timestamp', descending: true)
          .get(),
      _db
          .collectionGroup('staffLogs')
          .where('timestamp', isGreaterThanOrEqualTo: bounds.start)
          .where('timestamp', isLessThan: bounds.end)
          .orderBy('timestamp', descending: true)
          .get(),
      _db
          .collectionGroup('stockLogs')
          .where('timestamp', isGreaterThanOrEqualTo: bounds.start)
          .where('timestamp', isLessThan: bounds.end)
          .orderBy('timestamp', descending: true)
          .get(),
      _db
          .collection('consumableAssignments')
          .where('assignedAt', isGreaterThanOrEqualTo: bounds.start)
          .where('assignedAt', isLessThan: bounds.end)
          .orderBy('assignedAt', descending: true)
          .get(),
      _db
          .collection('docLogs')
          .where('timestamp', isGreaterThanOrEqualTo: bounds.start)
          .where('timestamp', isLessThan: bounds.end)
          .orderBy('timestamp', descending: true)
          .get(),
    ]);
    final inspectionsDone = await inspectionsFuture;

    final studentLogs = results[0]
        .docs
        .where((d) => _inWindow(d.data()['timestamp'], start, end))
        .toList();
    final staffLogs = results[1]
        .docs
        .where((d) => _inWindow(d.data()['timestamp'], start, end))
        .toList();
    final stockLogs = results[2]
        .docs
        .where((d) => _inWindow(d.data()['timestamp'], start, end))
        .toList();
    final assignments = results[3]
        .docs
        .where((d) => _inWindow(d.data()['assignedAt'], start, end))
        .toList();
    final docLogs = results[4]
        .docs
        .where((d) => _inWindow(d.data()['timestamp'], start, end))
        .toList();

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
    // records the acting account). Inspection completions, consumable
    // assignments and item deletions also write a dedicated stock log
    // entry, which lets us attribute those activities to an account too.
    //
    // Items Added / Items Removed count events (log entries), not units:
    // adding 50 notebooks in one action contributes 1, not 50.
    final itemsAddedBy = <String, int>{};
    final itemsRemovedBy = <String, int>{};
    final inspectionsLoggedBy = <String, int>{};
    final assignmentsLoggedBy = <String, int>{};
    final itemsDeletedBy = <String, int>{};
    for (final d in stockLogs) {
      final data = d.data();
      final actor = _actorOf(d);
      final type = data['type'];
      final qty = (data['quantity'] as num?)?.toInt() ?? 0;
      final note = (data['note'] as String?) ?? '';
      if (type == 'increase' && qty > 0) {
        _add(itemsAddedBy, actor, 1);
      } else if (type == 'decrease' && qty > 0) {
        _add(itemsRemovedBy, actor, 1);
      }
      if (type == 'inspection' && note.startsWith('Inspection completed')) {
        _add(inspectionsLoggedBy, actor, 1);
      } else if (type == 'decrease' && note.startsWith('Assigned to ')) {
        _add(assignmentsLoggedBy, actor, 1);
      } else if (type == 'decrease' &&
          note.startsWith('Item removed from room')) {
        // Item deletions write a 'decrease' log with this note (quantity
        // is whatever the item held, possibly 0), so they are detected by
        // note rather than by quantity.
        _add(itemsDeletedBy, actor, 1);
      }
    }

    // Inspections/assignments totals come from their own collections (which
    // do not always record an actor); attribute what the daily logs explain
    // and fold any remainder into the unknown-account bucket.
    final inspectionsBy = Map<String, int>.of(inspectionsLoggedBy);
    _foldUnattributed(inspectionsBy, inspectionsDone);
    final assignmentsBy = Map<String, int>.of(assignmentsLoggedBy);
    _foldUnattributed(assignmentsBy, assignments.length);

    // ── Student Docs: DMC/Degree scans arriving (stocked) vs handed
    // over to collectors (issued), each attributed to the acting account ──
    final docsStockedBy = <String, int>{};
    final docsIssuedBy = <String, int>{};
    for (final d in docLogs) {
      final data = d.data();
      final actor = (data['changedBy'] as String?) ?? '';
      switch (data['action']) {
        case 'stocked':
          _add(docsStockedBy, actor, 1);
        case 'issued':
          _add(docsIssuedBy, actor, 1);
        default:
          break;
      }
    }

    // The UI compares [HomeAnalytics.day] against today's (and yesterday's)
    // calendar date, so report the IST calendar day of the window rather than
    // the UTC instant that starts it.
    final istStart = start.toUtc().add(_istOffset);
    return HomeAnalytics(
      day: DateTime(istStart.year, istStart.month, istStart.day),
      studentsCreated: _sum(studentsCreatedBy),
      studentsUpdated: _sum(studentsUpdatedBy),
      studentsDeleted: _sum(studentsDeletedBy),
      staffCreated: _sum(staffCreatedBy),
      staffUpdated: _sum(staffUpdatedBy),
      staffDeleted: _sum(staffDeletedBy),
      inspectionsDone: inspectionsDone,
      itemsAdded: _sum(itemsAddedBy),
      itemsRemoved: _sum(itemsRemovedBy),
      itemsDeleted: _sum(itemsDeletedBy),
      assignmentsDone: assignments.length,
      docsStocked: _sum(docsStockedBy),
      docsIssued: _sum(docsIssuedBy),
      studentsCreatedAccounts: accountSharesFromTally(studentsCreatedBy),
      studentsUpdatedAccounts: accountSharesFromTally(studentsUpdatedBy),
      studentsDeletedAccounts: accountSharesFromTally(studentsDeletedBy),
      staffCreatedAccounts: accountSharesFromTally(staffCreatedBy),
      staffUpdatedAccounts: accountSharesFromTally(staffUpdatedBy),
      staffDeletedAccounts: accountSharesFromTally(staffDeletedBy),
      inspectionsAccounts: accountSharesFromTally(inspectionsBy),
      itemsAddedAccounts: accountSharesFromTally(itemsAddedBy),
      itemsRemovedAccounts: accountSharesFromTally(itemsRemovedBy),
      itemsDeletedAccounts: accountSharesFromTally(itemsDeletedBy),
      assignmentsAccounts: accountSharesFromTally(assignmentsBy),
      docsStockedAccounts: accountSharesFromTally(docsStockedBy),
      docsIssuedAccounts: accountSharesFromTally(docsIssuedBy),
    );
  }

  /// Counts inspections completed during the [start]..[end) window.
  ///
  /// Inspections live in `rooms/{roomId}/inspections` subcollections and are
  /// stamped `status: 'completed'` with `completedAt` on completion, so we
  /// walk the building → floor → room tree and read each room's inspections.
  /// Candidate rows are fetched with the widened [bounds] and then filtered on
  /// the true instant, so legacy local strings and new UTC strings both count
  /// correctly.
  Future<int> _countCompletedInspections(
      DateTime start, DateTime end, ({String start, String end}) bounds) async {
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
                .where('completedAt', isGreaterThanOrEqualTo: bounds.start)
                .where('completedAt', isLessThan: bounds.end)
                .get(),
          );
        }
      }
    }

    final snapshots = await Future.wait(roomQueries);
    var count = 0;
    for (final snap in snapshots) {
      for (final d in snap.docs) {
        if (d.data()['status'] != 'completed') continue;
        if (_inWindow(d.data()['completedAt'], start, end)) count++;
      }
    }
    return count;
  }
}
