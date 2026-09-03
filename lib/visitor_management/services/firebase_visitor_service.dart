import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_session.dart';
import '../../providers.dart';
import '../models/visitor_models.dart';
import '../repositories/visitor_repository.dart';

class FirebaseVisitorRepository implements VisitorRepository {
  final FirebaseFirestore _db = db;

  CollectionReference get _visits => _db.collection('visits');
  CollectionReference get _visitors => _db.collection('visitors');

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
    required List<String> accompanyingPeople,
  }) async {
    final now = DateTime.now();
    final batch = _db.batch();

    final String personRefId;
    if (isStaff) {
      // Staff entries are linked to the staff document id.
      personRefId = staffId!;
    } else if (visitorId != null && visitorId.isNotEmpty) {
      // The user explicitly picked this visitor from the autocomplete list:
      // reuse their profile and remember the latest car plate / from-place.
      final update = <String, dynamic>{
        'visitCount': FieldValue.increment(1),
        'lastVisitAt': now.toIso8601String(),
      };
      if (vehicleNumber.trim().isNotEmpty) {
        update['vehicleNumber'] = vehicleNumber.trim();
      }
      if (fromPlace.trim().isNotEmpty) {
        update['fromPlace'] = fromPlace.trim();
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
        vehicleNumber: vehicleNumber.trim(),
        fromPlace: fromPlace.trim(),
      ).toFirestore());
      personRefId = ref.id;
    }

    final visitRef = _visits.doc();
    batch.set(
        visitRef,
        VisitorVisitModel(
          personType: isStaff ? 'staff' : 'visitor',
          personRefId: personRefId,
          name: name.trim(),
          vehicleNumber: vehicleNumber.trim(),
          purpose: purpose.trim(),
          fromPlace: fromPlace.trim(),
          accompanyingPeople: accompanyingPeople
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          checkInAt: now,
          checkedInBy: UserSession().currentUser?.email ?? '',
        ).toFirestore());

    await batch.commit();
  }

  @override
  Future<void> checkOut(String visitId) async {
    await _visits.doc(visitId).update({
      'inside': false,
      'checkOutAt': DateTime.now().toIso8601String(),
      'checkedOutBy': UserSession().currentUser?.email ?? '',
    });
  }
}
