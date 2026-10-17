import '../models/lead_model.dart';

abstract class LeadRepository {
  Stream<List<LeadModel>> watchLeads();
  Stream<List<LeadLog>> watchAllLeadLogs();

  Future<String> createLead(LeadModel lead);
  Future<void> updateLead(LeadModel lead);
  Future<void> updateLeadStatus(LeadModel lead, String status);
  Future<void> deleteLead(LeadModel lead);
}
