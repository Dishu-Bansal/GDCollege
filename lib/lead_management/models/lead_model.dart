/// Admission-lead statuses, in pipeline order.
const List<String> leadStatuses = [
  'New',
  'Contacted',
  'Interested',
  'Admitted',
  'Lost',
];

/// Where the lead came from.
const List<String> leadSources = [
  'Walk-in',
  'Call',
  'Online',
  'Reference',
  'Other',
];

class LeadModel {
  String? id;
  String name;
  String phone;
  String course;
  String source;
  String status;
  String notes;
  DateTime? followUpAt;
  DateTime createdAt;
  DateTime updatedAt;
  String createdBy;
  String updatedBy;

  LeadModel({
    this.id,
    this.name = '',
    this.phone = '',
    this.course = '',
    this.source = 'Walk-in',
    this.status = 'New',
    this.notes = '',
    this.followUpAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get needsFollowUp =>
      followUpAt != null && status != 'Admitted' && status != 'Lost';

  factory LeadModel.fromFirestore(String id, Map<String, dynamic> d) =>
      LeadModel(
        id: id,
        name: d['name'] ?? '',
        phone: d['phone'] ?? '',
        course: d['course'] ?? '',
        source: d['source'] ?? 'Walk-in',
        status: d['status'] ?? 'New',
        notes: d['notes'] ?? '',
        followUpAt: d['followUpAt'] != null
            ? DateTime.tryParse(d['followUpAt'])
            : null,
        createdAt: d['createdAt'] != null
            ? DateTime.tryParse(d['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: d['updatedAt'] != null
            ? DateTime.tryParse(d['updatedAt']) ?? DateTime.now()
            : DateTime.now(),
        createdBy: d['createdBy'] ?? '',
        updatedBy: d['updatedBy'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'phone': phone,
        'course': course,
        'source': source,
        'status': status,
        'notes': notes,
        'followUpAt': followUpAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdBy': createdBy,
        'updatedBy': updatedBy,
      };
}

// ── Lead log ─────────────────────────────────────────────────────────────────

class LeadLog {
  String? id;
  String leadId;
  String leadName;
  String action; // 'create' | 'update' | 'status' | 'delete'
  String changedBy;
  String detail;
  DateTime timestamp;

  LeadLog({
    this.id,
    this.leadId = '',
    this.leadName = '',
    this.action = 'create',
    this.changedBy = '',
    this.detail = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LeadLog.fromFirestore(String id, Map<String, dynamic> d) =>
      LeadLog(
        id: id,
        leadId: d['leadId'] ?? '',
        leadName: d['leadName'] ?? '',
        action: d['action'] ?? 'create',
        changedBy: d['changedBy'] ?? '',
        detail: d['detail'] ?? '',
        timestamp: d['timestamp'] != null
            ? DateTime.tryParse(d['timestamp']) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
        'leadId': leadId,
        'leadName': leadName,
        'action': action,
        'changedBy': changedBy,
        'detail': detail,
        'timestamp': timestamp.toIso8601String(),
      };
}
