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
    } else {
      personRefId = await _resolveOrCreateVisitor(
        name: name.trim(),
        now: now,
        batch: batch,
        vehicleNumber: vehicleNumber.trim(),
        fromPlace: fromPlace.trim(),
      );
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

  /// Reuses an existing visitor doc when the name matches an earlier visitor
  /// (case-insensitive), otherwise creates a new one. Returns the doc id.
  /// The latest car plate / from-place are remembered on the visitor doc so
  /// the entry form can autofill them next time.
  Future<String> _resolveOrCreateVisitor({
    required String name,
    required DateTime now,
    required WriteBatch batch,
    required String vehicleNumber,
    required String fromPlace,
  }) async {
    final existing = await _visitors
        .where('nameLower', isEqualTo: name.toLowerCase())
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final update = <String, dynamic>{
        'visitCount': FieldValue.increment(1),
        'lastVisitAt': now.toIso8601String(),
      };
      // Only overwrite remembered details when this visit provides them.
      if (vehicleNumber.isNotEmpty) {
        update['vehicleNumber'] = vehicleNumber;
      }
      if (fromPlace.isNotEmpty) {
        update['fromPlace'] = fromPlace;
      }
      batch.update(doc.reference, update);
      return doc.id;
    }
    final ref = _visitors.doc();
    batch.set(ref, VisitorModel(
      name: name,
      visitCount: 1,
      firstVisitAt: now,
      lastVisitAt: now,
      vehicleNumber: vehicleNumber,
      fromPlace: fromPlace,
    ).toFirestore());
    return ref.id;
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
