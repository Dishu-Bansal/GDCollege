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
    await docRef.set(lead.toFirestore());
    await _writeLog(docRef.id, lead.name, 'create',
        'Lead created (${lead.source}${lead.course.isNotEmpty ? ', ${lead.course}' : ''}).');
    return docRef.id;
  }

  @override
  Future<void> updateLead(LeadModel lead) async {
    final id = lead.id;
    if (id == null) return;
    lead.updatedAt = DateTime.now();
    lead.updatedBy = _currentUser;
    await _leads.doc(id).set(lead.toFirestore());
    await _writeLog(id, lead.name, 'update', 'Lead updated.');
  }

  @override
  Future<void> updateLeadStatus(LeadModel lead, String status) async {
    final id = lead.id;
    if (id == null || lead.status == status) return;
    final old = lead.status;
    lead.status = status;
    lead.updatedAt = DateTime.now();
    lead.updatedBy = _currentUser;
    await _leads.doc(id).set(lead.toFirestore());
    await _writeLog(
        id, lead.name, 'status', 'Status changed: $old → $status.');
  }

  @override
  Future<void> deleteLead(LeadModel lead) async {
    final id = lead.id;
    if (id == null) return;
    await _leads.doc(id).delete();
    await _writeLog(id, lead.name, 'delete', 'Lead deleted.');
  }

  Future<void> _writeLog(
      String leadId, String leadName, String action, String detail) async {
    await _leadLogs.add(LeadLog(
      leadId: leadId,
      leadName: leadName,
      action: action,
      changedBy: _currentUser,
      detail: detail,
    ).toFirestore());
  }
}
