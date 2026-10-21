import 'package:gd_college/utils/timestamps.dart';

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
        timestamp: parseTimestamp(d['timestamp']) ?? DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
    'personId': personId,
    'personName': personName,
    'action': action,
    'changedBy': changedBy,
    'detail': detail,
    // Instants are stored in UTC so a log entry never depends on the writer's
    // clock zone; readers normalise every historical shape back to local.
    'timestamp': timestampToWire(timestamp),
  };
}
