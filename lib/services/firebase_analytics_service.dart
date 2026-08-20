import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/home_analytics.dart';
import '../repositories/analytics_repository.dart';

class FirebaseAnalyticsRepository implements AnalyticsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  @override
  Future<HomeAnalytics> fetchPreviousDayAnalytics() async {
    final day = _previousIstDay();
    final startIso = day.start.toIso8601String();
    final endIso = day.end.toIso8601String();

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

    int studentsCreated = 0, studentsUpdated = 0, studentsDeleted = 0;
    for (final d in studentLogs) {
      switch (d.data()['action']) {
        case 'create':
          studentsCreated++;
        case 'update':
          studentsUpdated++;
        case 'delete':
          studentsDeleted++;
        default:
          break;
      }
    }

    int staffCreated = 0, staffUpdated = 0, staffDeleted = 0;
    for (final d in staffLogs) {
      switch (d.data()['action']) {
        case 'create':
          staffCreated++;
        case 'update':
          staffUpdated++;
        case 'delete':
          staffDeleted++;
        default:
          break;
      }
    }

    int itemsAdded = 0, itemsRemoved = 0;
    for (final d in stockLogs) {
      final data = d.data();
      final type = data['type'];
      final qty = (data['quantity'] as num?)?.toInt() ?? 0;
      if (type == 'increase') {
        itemsAdded += qty;
      } else if (type == 'decrease') {
        itemsRemoved += qty;
      }
    }

    return HomeAnalytics(
      day: day.start,
      studentsCreated: studentsCreated,
      studentsUpdated: studentsUpdated,
      studentsDeleted: studentsDeleted,
      staffCreated: staffCreated,
      staffUpdated: staffUpdated,
      staffDeleted: staffDeleted,
      inspectionsDone: inspectionsDone,
      itemsAdded: itemsAdded,
      itemsRemoved: itemsRemoved,
      assignmentsDone: assignments.length,
    );
  }

  /// Counts inspections completed during [startIso]..[endIso].
  ///
  /// Inspections live in `rooms/{roomId}/inspections` subcollections and are
  /// stamped `status: 'completed'` with `completedAt` on completion, so we
  /// walk the building → floor → room tree and read each room's inspections.
  Future<int> _countCompletedInspections(
      String startIso, String endIso) async {
    final buildings = await _db.collection('buildings').get();
    final roomQueries =
        <Future<QuerySnapshot<Map<String, dynamic>>>>[];
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
          roomQueries.add(_db
              .collection('buildings')
              .doc(b.id)
              .collection('floors')
              .doc(f.id)
              .collection('rooms')
              .doc(r.id)
              .collection('inspections')
              .where('completedAt', isGreaterThanOrEqualTo: startIso)
              .where('completedAt', isLessThan: endIso)
              .get());
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
