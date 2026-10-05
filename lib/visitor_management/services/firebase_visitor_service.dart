import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_session.dart';
import '../../providers.dart';
import '../models/visitor_models.dart';
import '../repositories/visitor_repository.dart';

class FirebaseVisitorRepository implements VisitorRepository {
  final FirebaseFirestore _db = db;

  CollectionReference get _visits => _db.collection('visits');
  CollectionReference get _visitors => _db.collection('visitors');
  CollectionReference get _events => _db.collection('visitEvents');

  /// Old visit docs may store times as ISO strings (current) or Firestore
  /// Timestamps (legacy). A Timestamp's .toString() does not parse, and the
  /// old code fell back to DateTime.now() — floating those events to the
  /// top of the time-sorted log.
  static DateTime? _parseAt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  // ── Streams ─────────────────────────────────────────────────────────────

  @override
  Stream<List<VisitorVisitModel>> watchInside() {
    // Single boolean equality filter (avoids a composite index and behaves
    // reliably when a document moves out of the result set on check-out);
    // sorted client-side.
    return _visits
        .where('inside', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                VisitorVisitModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.checkInAt.compareTo(a.checkInAt)))
        .handleError((_) => <VisitorVisitModel>[]);
  }

  @override
  Stream<List<VisitorModel>> watchVisitors() {
    return _visitors
        .orderBy('lastVisitAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                VisitorModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
            .toList())
        .handleError((_) => <VisitorModel>[]);
  }

  @override
  Stream<List<VisitorVisitModel>> watchAllVisits() {
    return _visits
        .orderBy('checkInAt', descending: true)
        .limit(500)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                VisitorVisitModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
            .toList())
        .handleError((_) => <VisitorVisitModel>[]);
  }

  @override
  Stream<List<VisitorEventModel>> watchVisitEvents() {
    // Sorted by creation time (single-field orderBy — no composite index
    // needed), so a backdated entry surfaces at the top as a late log.
    return _events
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                VisitorEventModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
            .toList())
        .handleError((_) => <VisitorEventModel>[]);
  }

  @override
  Stream<List<VisitorVisitModel>> watchVisitorVisits(String visitorId) {
    return _visits
        .where('personRefId', isEqualTo: visitorId)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                VisitorVisitModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.checkInAt.compareTo(a.checkInAt)))
        .handleError((_) => <VisitorVisitModel>[]);
  }

  // ── Mutations ───────────────────────────────────────────────────────────

  @override
  Future<void> checkIn({
    required bool isStaff,
    required String? staffId,
    required String? visitorId,
    required String name,
    required String vehicleNumber,
    required String purpose,
    required String fromPlace,
    required String phone,
    required List<String> accompanyingPeople,
    DateTime? at,
    DateTime? checkOutAt,
  }) async {
    final now = at ?? DateTime.now();
    if (checkOutAt != null && checkOutAt.isBefore(now)) {
      throw ArgumentError('Check-out time cannot be before check-in time.');
    }
    final batch = _db.batch();

    final String personRefId;
    if (isStaff) {
      // Staff entries are linked to the staff document id.
      personRefId = staffId!;
    } else if (visitorId != null && visitorId.isNotEmpty) {
      // The user explicitly picked this visitor from the autocomplete list:
      // reuse their profile. Timestamps and remembered details only move
      // forward: a backdated entry must not drag lastVisitAt (which drives
      // the Visitors tab order) or the remembered car/place/phone back.
      final prevSnap = await _visitors.doc(visitorId).get();
      final prev = prevSnap.data() as Map<String, dynamic>?;
      final prevIn = _parseAt(prev?['lastVisitAt']);
      final isLatest = prevIn == null || !now.isBefore(prevIn);
      final update = <String, dynamic>{
        'visitCount': FieldValue.increment(1),
      };
      if (isLatest) {
        update['lastVisitAt'] = now.toIso8601String();
        if (vehicleNumber.trim().isNotEmpty) {
          update['vehicleNumber'] = vehicleNumber.trim();
        }
        if (fromPlace.trim().isNotEmpty) {
          update['fromPlace'] = fromPlace.trim();
        }
        if (phone.trim().isNotEmpty) {
          update['phone'] = phone.trim();
        }
      } else {
        // Backdated entry: still fill details the profile lacks, but never
        // overwrite what a later visit already recorded.
        if (vehicleNumber.trim().isNotEmpty &&
            (prev?['vehicleNumber'] ?? '').toString().isEmpty) {
          update['vehicleNumber'] = vehicleNumber.trim();
        }
        if (fromPlace.trim().isNotEmpty &&
            (prev?['fromPlace'] ?? '').toString().isEmpty) {
          update['fromPlace'] = fromPlace.trim();
        }
        if (phone.trim().isNotEmpty &&
            (prev?['phone'] ?? '').toString().isEmpty) {
          update['phone'] = phone.trim();
        }
      }
      if (checkOutAt != null) {
        final prevOut = _parseAt(prev?['lastCheckOutAt']);
        if (prevOut == null || checkOutAt.isAfter(prevOut)) {
          update['lastCheckOutAt'] = checkOutAt.toIso8601String();
        }
      }
      batch.update(_visitors.doc(visitorId), update);
      personRefId = visitorId;
    } else {
      // No suggestion was picked: always create a new visitor, even when
      // the name matches an existing one (two visitors can share a name).
      final ref = _visitors.doc();
      batch.set(ref, VisitorModel(
        name: name.trim(),
        visitCount: 1,
        firstVisitAt: now,
        lastVisitAt: now,
        lastCheckOutAt: checkOutAt,
        vehicleNumber: vehicleNumber.trim(),
        fromPlace: fromPlace.trim(),
        phone: phone.trim(),
      ).toFirestore());
      personRefId = ref.id;
    }

    final visitRef = _visits.doc();
    final visit = VisitorVisitModel(
      personType: isStaff ? 'staff' : 'visitor',
      personRefId: personRefId,
      name: name.trim(),
      vehicleNumber: vehicleNumber.trim(),
      purpose: purpose.trim(),
      fromPlace: fromPlace.trim(),
      phone: phone.trim(),
      accompanyingPeople: accompanyingPeople
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      checkInAt: now,
      checkOutAt: checkOutAt,
      completedAtEntry: checkOutAt != null,
      checkedInBy: UserSession().currentUser?.email ?? '',
    );
    batch.set(visitRef, visit.toFirestore());
    // The global log row for this check-in — a separate doc from the visit
    // session. createdAt is the log moment (now); at is the business time.
    // A one-step completed visit logs a single 'Entry added' row carrying
    // both times instead of separate entry/exit rows.
    batch.set(
        _events.doc('${visitRef.id}_entry'),
        VisitorEventModel(
          type: checkOutAt == null ? 'entry' : 'completed',
          at: now,
          createdAt: DateTime.now(),
          visitId: visitRef.id,
          personType: visit.personType,
          personRefId: personRefId,
          name: visit.name,
          vehicleNumber: visit.vehicleNumber,
          purpose: visit.purpose,
          fromPlace: visit.fromPlace,
          phone: visit.phone,
          outAt: checkOutAt,
          accompanyingPeople: visit.accompanyingPeople,
          by: visit.checkedInBy,
        ).toFirestore());

    await batch.commit();
  }

  @override
  Future<void> checkOut(String visitId, {DateTime? at}) async {
    final chosen = at ?? DateTime.now();

    // Enforce that a check-out cannot be before its check-in. The stored
    // timestamps are ISO-8601 wall-clock strings, parsed back to local time.
    final snap = await _visits.doc(visitId).get();
    if (!snap.exists) {
      throw ArgumentError('Visit no longer exists.');
    }
    final data = snap.data() as Map<String, dynamic>? ?? {};
    final checkIn = _parseAt(data['checkInAt']);
    if (checkIn != null && chosen.isBefore(checkIn)) {
      throw ArgumentError('Check-out time cannot be before check-in time.');
    }

    final by = UserSession().currentUser?.email ?? '';
    final batch = _db.batch();
    batch.update(_visits.doc(visitId), {
      'inside': false,
      'checkOutAt': chosen.toIso8601String(),
      'checkedOutBy': by,
    });
    // The global log's exit row — a separate doc so it sorts by its own time.
    // createdAt is the log moment (now); at is the manually picked time.
    batch.set(
        _events.doc('${visitId}_exit'),
        VisitorEventModel(
          type: 'exit',
          at: chosen,
          createdAt: DateTime.now(),
          visitId: visitId,
          personType: (data['personType'] ?? 'visitor').toString(),
          personRefId: (data['personRefId'] ?? '').toString(),
          name: (data['name'] ?? '').toString(),
          vehicleNumber: (data['vehicleNumber'] ?? '').toString(),
          purpose: (data['purpose'] ?? '').toString(),
          fromPlace: (data['fromPlace'] ?? '').toString(),
          phone: (data['phone'] ?? '').toString(),
          accompanyingPeople:
              List<String>.from(data['accompanyingPeople'] ?? []),
          by: by,
        ).toFirestore());

    // Keep the visitor profile's last check-out in step so the Visitors
    // tab can show it without reading the visit log. Staff check-ins have
    // no visitor profile (personRefId is the staff doc), so skip those.
    if (data['personType'] != 'staff') {
      final refId = (data['personRefId'] ?? '').toString();
      if (refId.isNotEmpty) {
        batch.update(_visitors.doc(refId), {
          'lastCheckOutAt': chosen.toIso8601String(),
        });
      }
    }
    await batch.commit();
  }

  @override
  Future<int> backfillVisitEvents() async {
    // Deterministic doc ids make this safe to re-run. It also repairs
    // events stamped with the wrong time (e.g. from the first backfill run
    // before legacy Timestamp parsing): an existing event whose `at` is
    // more than a minute off the visit's time is corrected.
    final snap = await _visits.get();
    var written = 0;
    var batch = _db.batch();
    var pending = 0;
    Future<void> flush() async {
      if (pending == 0) return;
      await batch.commit();
      batch = _db.batch();
      pending = 0;
    }

    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>? ?? {};
      final personType = (data['personType'] ?? 'visitor').toString();
      final personRefId = (data['personRefId'] ?? '').toString();
      final name = (data['name'] ?? '').toString();
      final vehicleNumber = (data['vehicleNumber'] ?? '').toString();
      final purpose = (data['purpose'] ?? '').toString();
      final fromPlace = (data['fromPlace'] ?? '').toString();
      final phone = (data['phone'] ?? '').toString();
      final accompanying =
          List<String>.from(data['accompanyingPeople'] ?? []);
      final checkInAt = _parseAt(data['checkInAt']);
      final checkOutAt = _parseAt(data['checkOutAt']);
      final completedAtEntry = data['completedAtEntry'] == true;

      if (checkInAt != null) {
        pending += await _ensureEvent(
          batch,
          ref: _events.doc('${d.id}_entry'),
          expected: VisitorEventModel(
            type: completedAtEntry ? 'completed' : 'entry',
            at: checkInAt,
            // Historical reconstruction: true creation time is unknown, so
            // legacy rows keep business-time ordering among themselves.
            createdAt: checkInAt,
            visitId: d.id,
            personType: personType,
            personRefId: personRefId,
            name: name,
            vehicleNumber: vehicleNumber,
            purpose: purpose,
            fromPlace: fromPlace,
            phone: phone,
            outAt: completedAtEntry ? checkOutAt : null,
            accompanyingPeople: accompanying,
            by: (data['checkedInBy'] ?? '').toString(),
          ),
          onWrite: () => written++,
        );
      }
      if (checkOutAt != null && !completedAtEntry) {
        pending += await _ensureEvent(
          batch,
          ref: _events.doc('${d.id}_exit'),
          expected: VisitorEventModel(
            type: 'exit',
            at: checkOutAt,
            createdAt: checkOutAt,
            visitId: d.id,
            personType: personType,
            personRefId: personRefId,
            name: name,
            vehicleNumber: vehicleNumber,
            purpose: purpose,
            fromPlace: fromPlace,
            phone: phone,
            accompanyingPeople: accompanying,
            by: (data['checkedOutBy'] ?? '').toString(),
          ),
          onWrite: () => written++,
        );
      }
      if (pending >= 400) await flush();
    }
    await flush();
    return written;
  }

  /// Creates [ref] with [expected] when missing, corrects its `at` when it
  /// drifted, and stamps `createdAt` on legacy events missing it. Returns 1
  /// when a write was queued, else 0.
  Future<int> _ensureEvent(
    WriteBatch batch, {
    required DocumentReference ref,
    required VisitorEventModel expected,
    required void Function() onWrite,
  }) async {
    final existing = await ref.get();
    if (!existing.exists) {
      batch.set(ref, expected.toFirestore());
      onWrite();
      return 1;
    }
    final data = existing.data() as Map<String, dynamic>?;
    final current =
        _parseAt(data?['at']);
    if (current == null ||
        current.difference(expected.at).abs() > const Duration(minutes: 1)) {
      batch.update(ref, {'at': expected.at.toIso8601String()});
      onWrite();
      return 1;
    }
    if (data?['createdAt'] == null) {
      batch.update(ref, {
        'createdAt': expected.createdAt.toIso8601String(),
      });
      onWrite();
      return 1;
    }
    return 0;
  }
}
