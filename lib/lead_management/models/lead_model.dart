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

/// Interested-course options for the multi-select picker.
const List<String> leadCourseOptions = [
  'B.ed',
  'M.ed',
  'D.P.ed',
  'D.El.Ed',
  'ANM',
  'GNM',
  'Skill India',
  'Other',
];

/// One follow-up reminder on a lead: a note plus the date it is due.
class FollowUpNote {
  String note;
  DateTime date;

  FollowUpNote({this.note = '', DateTime? date})
      : date = date ?? DateTime.now();

  factory FollowUpNote.fromMap(Map<String, dynamic> m) => FollowUpNote(
        note: m['note'] ?? '',
        date: m['date'] != null
            ? DateTime.tryParse(m['date']) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'note': note,
        'date': date.toIso8601String(),
      };
}

class LeadModel {
  String? id;
  String name;
  String phone;
  String location;

  /// Interested courses (multi-select). Old docs carry a single `course`
  /// string, which reads as a one-item list.
  List<String> courses;
  String source;
  String status;
  String notes;

  /// Follow-up reminders, each a note plus a due date.
  List<FollowUpNote> followUps;
  DateTime? followUpAt;
  DateTime createdAt;
  DateTime updatedAt;
  String createdBy;
  String updatedBy;

  LeadModel({
    this.id,
    this.name = '',
    this.phone = '',
    this.location = '',
    this.courses = const [],
    this.source = 'Walk-in',
    this.status = 'New',
    this.notes = '',
    this.followUps = const [],
    this.followUpAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// The next pending follow-up (earliest dated entry), if any.
  FollowUpNote? get nextFollowUp {
    if (followUps.isEmpty) return null;
    final sorted = List<FollowUpNote>.of(followUps)
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted.first;
  }

  bool get needsFollowUp =>
      nextFollowUp != null && status != 'Admitted' && status != 'Lost';

  factory LeadModel.fromFirestore(String id, Map<String, dynamic> d) {
    final rawCourses = d['courses'];
    final courses = rawCourses is List
        ? rawCourses.map((e) => e.toString()).toList()
        : (d['course'] is String && (d['course'] as String).isNotEmpty
            ? [(d['course'] as String)]
            : <String>[]);
    final rawFollowUps = d['followUps'];
    var followUps = rawFollowUps is List
        ? rawFollowUps
            .map((e) => FollowUpNote.fromMap((e as Map).cast<String, dynamic>()))
            .toList()
        : <FollowUpNote>[];
    // Legacy single follow-up date reads as one undated entry.
    if (followUps.isEmpty && d['followUpAt'] != null) {
      final legacy = DateTime.tryParse(d['followUpAt']);
      if (legacy != null) followUps = [FollowUpNote(date: legacy)];
    }
    return LeadModel(
      id: id,
      name: d['name'] ?? '',
      phone: d['phone'] ?? '',
      location: d['location'] ?? '',
      courses: courses,
      source: d['source'] ?? 'Walk-in',
      status: d['status'] ?? 'New',
      notes: d['notes'] ?? '',
      followUps: followUps,
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
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'phone': phone,
        'location': location,
        'courses': courses,
        'source': source,
        'status': status,
        'notes': notes,
        'followUps': followUps.map((f) => f.toMap()).toList(),
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
