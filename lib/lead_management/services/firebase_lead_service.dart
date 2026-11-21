import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gd_college/providers.dart';
import 'package:gd_college/utils/timestamps.dart';
import '../../models/user_session.dart';
import '../models/lead_model.dart';
import '../repositories/lead_repository.dart';

class FirebaseLeadRepository implements LeadRepository {
  final FirebaseFirestore _db = db;

  CollectionReference<Map<String, dynamic>> get _leads =>
      _db.collection('leads');

  CollectionReference<Map<String, dynamic>> get _leadLogs =>
      _db.collection('leadLogs');

  String get _currentUser => UserSession().currentUser?.email ?? '';

  @override
  Stream<List<LeadModel>> watchLeads() => _leads
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => LeadModel.fromFirestore(d.id, d.data()))
          .toList());

  @override
  Stream<List<LeadLog>> watchAllLeadLogs() => _leadLogs
      .orderBy('timestamp', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs
          .map((d) => LeadLog.fromFirestore(d.id, d.data()))
          .toList());

  @override
  Future<String> createLead(LeadModel lead) async {
    final docRef = _leads.doc();
    lead.id = docRef.id;
    lead.createdBy = _currentUser;
    lead.updatedBy = _currentUser;
    final data = lead.toFirestore();
    // createdAt/updatedAt are server-stamped below: a client clock must not
    // decide audit dates. The model is refreshed from the server afterwards.
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    // Lead and its 'create' log share one commit.
    final batch = _db.batch();
    batch.set(docRef, data);
    batch.set(
        _leadLogs.doc(),
        _logData(
            docRef.id,
            lead.name,
            'create',
            'Lead created (${lead.source}${lead.courses.isNotEmpty ? ', ${lead.courses.join(', ')}' : ''}).'));
    await batch.commit();
    // Refresh the model with the server-stamped instants: the list sorts by
    // createdAt immediately, so the in-memory copy must match the commit.
    final fresh = await docRef.get();
    final freshData = fresh.data();
    lead.createdAt =
        parseTimestamp(freshData?['createdAt']) ?? lead.createdAt;
    lead.updatedAt =
        parseTimestamp(freshData?['updatedAt']) ?? lead.updatedAt;
    return docRef.id;
  }

  @override
  Future<void> updateLead(LeadModel lead) async {
    final id = lead.id;
    if (id == null) return;
    lead.updatedBy = _currentUser;
    final data = lead.toFirestore();
    // Never re-write the creation instant on an edit: the stored value (or a
    // legacy string) is the record's true origin, while the model's copy is
    // a client-side serialisation. Merge keeps the stored createdAt intact.
    data.remove('createdAt');
    // updatedAt is the server's, never the device's.
    data['updatedAt'] = FieldValue.serverTimestamp();
    final docRef = _leads.doc(id);
    // Lead and its 'update' log share one commit.
    final batch = _db.batch();
    batch.set(docRef, data, SetOptions(merge: true));
    batch.set(_leadLogs.doc(), _logData(id, lead.name, 'update', 'Lead updated.'));
    await batch.commit();
    final fresh = await docRef.get();
    lead.updatedAt =
        parseTimestamp(fresh.data()?['updatedAt']) ?? lead.updatedAt;
  }

  @override
  Future<void> updateLeadStatus(LeadModel lead, String status) async {
    final id = lead.id;
    if (id == null || lead.status == status) return;
    final old = lead.status;
    lead.status = status;
    lead.updatedBy = _currentUser;
    final data = lead.toFirestore();
    // Same as updateLead: preserve the stored creation instant, stamp the
    // edit on the server.
    data.remove('createdAt');
    data['updatedAt'] = FieldValue.serverTimestamp();
    final docRef = _leads.doc(id);
    // Status change and its log share one commit.
    final batch = _db.batch();
    batch.set(docRef, data, SetOptions(merge: true));
    batch.set(
        _leadLogs.doc(),
        _logData(id, lead.name, 'status', 'Status changed: $old → $status.'));
    await batch.commit();
    final fresh = await docRef.get();
    lead.updatedAt =
        parseTimestamp(fresh.data()?['updatedAt']) ?? lead.updatedAt;
  }

  @override
  Future<void> deleteLead(LeadModel lead) async {
    final id = lead.id;
    if (id == null) return;
    // Removal and its 'delete' log share one commit: a failed delete leaves
    // no phantom log, and a successful one can never go unlogged.
    final batch = _db.batch();
    batch.delete(_leads.doc(id));
    batch.set(_leadLogs.doc(), _logData(id, lead.name, 'delete', 'Lead deleted.'));
    await batch.commit();
  }

  /// One-time backfill: converts legacy ISO-8601 STRING instants for this
  /// module's stamped fields into native Firestore [Timestamp] values,
  /// preserving the exact instant (as [parseTimestamp] interprets it, the
  /// same reading display/sort code already uses). Covers:
  /// - `leads`: `createdAt`, `updatedAt`;
  /// - `leadLogs`: `timestamp`.
  /// `followUpAt` and `followUps[].date` are user-picked calendar dates
  /// stored as `yyyy-MM-dd` strings by design and are intentionally NOT
  /// converted. Already-native values, nulls and unparseable strings are
  /// left untouched. Reads go in 500-doc pages (ordered by document id);
  /// writes go in 500-doc batches. Returns per-collection docs updated.
  /// Not wired to any UI; run once from a console/script.
  @override
  Future<Map<String, int>> backfillTimestampsToNative() async {
    Future<int> backfillCollection(
      CollectionReference<Map<String, dynamic>> collection,
      List<String> fields,
    ) async {
      var updatedDocs = 0;
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        var query = collection
            .orderBy(FieldPath.documentId)
            .limit(500);
        if (cursor != null) query = query.startAfterDocument(cursor);
        final page = await query.get();
        if (page.docs.isEmpty) break;
        final batch = _db.batch();
        var pageDirty = 0;
        for (final doc in page.docs) {
          final data = doc.data();
          final updates = <String, Object>{};
          for (final f in fields) {
            final v = data[f];
            if (v is String) {
              final parsed = parseTimestamp(v);
              if (parsed != null) {
                updates[f] = Timestamp.fromDate(parsed);
              }
            }
          }
          if (updates.isNotEmpty) {
            batch.update(doc.reference, updates);
            updatedDocs++;
            pageDirty++;
          }
        }
        if (pageDirty > 0) await batch.commit();
        if (page.docs.length < 500) break;
        cursor = page.docs.last;
      }
      return updatedDocs;
    }

    final leadsUpdated =
        await backfillCollection(_leads, const ['createdAt', 'updatedAt']);
    final logsUpdated =
        await backfillCollection(_leadLogs, const ['timestamp']);
    return {
      'leads': leadsUpdated,
      'leadLogs': logsUpdated,
    };
  }

  Map<String, dynamic> _logData(
      String leadId, String leadName, String action, String detail) {
    final payload = LeadLog(
      leadId: leadId,
      leadName: leadName,
      action: action,
      changedBy: _currentUser,
      detail: detail,
    ).toFirestore();
    // Log times are the server's, never the device's — audit times must not
    // be forgeable by setting a client clock.
    payload['timestamp'] = FieldValue.serverTimestamp();
    return payload;
  }
}
