class AuditLog {
  String? id;
  String personId;
  String personName;
  String action; // 'create', 'update', 'delete'
  String changedBy;
  String detail;
  DateTime timestamp;

  AuditLog({
    this.id,
    this.personId = '',
    this.personName = '',
    this.action = 'update',
    this.changedBy = '',
    this.detail = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AuditLog.fromFirestore(String id, Map<String, dynamic> d) =>
      AuditLog(
        id: id,
        personId: d['personId'] ?? '',
        personName: d['personName'] ?? '',
        action: d['action'] ?? 'update',
        changedBy: d['changedBy'] ?? '',
        detail: d['detail'] ?? '',
        timestamp: d['timestamp'] != null
            ? DateTime.tryParse(d['timestamp']) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
    'personId': personId,
    'personName': personName,
    'action': action,
    'changedBy': changedBy,
    'detail': detail,
    'timestamp': timestamp.toIso8601String(),
  };
}
