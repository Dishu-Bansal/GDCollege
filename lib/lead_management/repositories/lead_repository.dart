import '../models/lead_model.dart';

abstract class LeadRepository {
  Stream<List<LeadModel>> watchLeads();
  Stream<List<LeadLog>> watchAllLeadLogs();

  Future<String> createLead(LeadModel lead);
  Future<void> updateLead(LeadModel lead);
  Future<void> updateLeadStatus(LeadModel lead, String status);
  Future<void> deleteLead(LeadModel lead);

  /// One-time backfill converting legacy ISO-8601 STRING instants
  /// (`leads` createdAt/updatedAt, `leadLogs` timestamp) into native
  /// Firestore Timestamps. Safe to re-run; returns per-collection docs
  /// updated. Not wired to any UI.
  Future<Map<String, int>> backfillTimestampsToNative();
}
