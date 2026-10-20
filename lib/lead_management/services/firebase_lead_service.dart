import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gd_college/providers.dart';
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
    final now = DateTime.now();
    final docRef = _leads.doc();
    lead.id = docRef.id;
    lead.createdAt = now;
    lead.updatedAt = now;
    lead.createdBy = _currentUser;
    lead.updatedBy = _currentUser;
    // Lead and its 'create' log share one commit.
    final batch = _db.batch();
    batch.set(docRef, lead.toFirestore());
    batch.set(
        _leadLogs.doc(),
        _logData(
            docRef.id,
            lead.name,
            'create',
            'Lead created (${lead.source}${lead.courses.isNotEmpty ? ', ${lead.courses.join(', ')}' : ''}).'));
    await batch.commit();
    return docRef.id;
  }

  @override
  Future<void> updateLead(LeadModel lead) async {
    final id = lead.id;
    if (id == null) return;
    lead.updatedAt = DateTime.now();
    lead.updatedBy = _currentUser;
    // Lead and its 'update' log share one commit.
    final batch = _db.batch();
    batch.set(_leads.doc(id), lead.toFirestore());
    batch.set(_leadLogs.doc(), _logData(id, lead.name, 'update', 'Lead updated.'));
    await batch.commit();
  }

  @override
  Future<void> updateLeadStatus(LeadModel lead, String status) async {
    final id = lead.id;
    if (id == null || lead.status == status) return;
    final old = lead.status;
    lead.status = status;
    lead.updatedAt = DateTime.now();
    lead.updatedBy = _currentUser;
    // Status change and its log share one commit.
    final batch = _db.batch();
    batch.set(_leads.doc(id), lead.toFirestore());
    batch.set(
        _leadLogs.doc(),
        _logData(id, lead.name, 'status', 'Status changed: $old → $status.'));
    await batch.commit();
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

  Map<String, dynamic> _logData(
      String leadId, String leadName, String action, String detail) {
    return LeadLog(
      leadId: leadId,
      leadName: leadName,
      action: action,
      changedBy: _currentUser,
      detail: detail,
    ).toFirestore();
  }
}
