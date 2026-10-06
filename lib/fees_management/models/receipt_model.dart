/// One fee type that a receipt's amount was applied to (Year 1 → 2 → 3 →
/// miscellaneous order).
class ReceiptAllocation {
  final String type;
  final double amount;

  const ReceiptAllocation({required this.type, required this.amount});

  factory ReceiptAllocation.fromMap(Map<String, dynamic> m) =>
      ReceiptAllocation(
        type: m['type'] ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {'type': type, 'amount': amount};
}

class ReceiptModel {
  String? id;
  String receiptNumber;
  String studentId;
  String studentName;
  String rollNo;
  String college;
  String course;
  int admissionYear;
  double amount;
  String mode; // 'Cash' | 'Account-XXXX'
  String photoUrl;
  List<ReceiptAllocation> allocations;
  DateTime createdAt;
  String createdBy;

  ReceiptModel({
    this.id,
    this.receiptNumber = '',
    this.studentId = '',
    this.studentName = '',
    this.rollNo = '',
    this.college = '',
    this.course = '',
    this.admissionYear = 0,
    this.amount = 0,
    this.mode = 'Cash',
    this.photoUrl = '',
    this.allocations = const [],
    DateTime? createdAt,
    this.createdBy = '',
  }) : createdAt = createdAt ?? DateTime.now();

  factory ReceiptModel.fromFirestore(
      String id, Map<String, dynamic> d) =>
      ReceiptModel(
        id: id,
        receiptNumber: d['receiptNumber'] ?? '',
        studentId: d['studentId'] ?? '',
        studentName: d['studentName'] ?? '',
        rollNo: d['rollNo'] ?? '',
        college: d['college'] ?? '',
        course: d['course'] ?? '',
        admissionYear: (d['admissionYear'] as num?)?.toInt() ?? 0,
        amount: (d['amount'] as num?)?.toDouble() ?? 0,
        mode: d['mode'] ?? 'Cash',
        photoUrl: d['photoUrl'] ?? '',
        allocations: (d['allocations'] as List<dynamic>? ?? [])
            .map((a) => ReceiptAllocation.fromMap(
                (a as Map).cast<String, dynamic>()))
            .toList(),
        createdAt: d['createdAt'] != null
            ? DateTime.tryParse(d['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        createdBy: d['createdBy'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'receiptNumber': receiptNumber,
    'studentId': studentId,
    'studentName': studentName,
    'rollNo': rollNo,
    'college': college,
    'course': course,
    'admissionYear': admissionYear,
    'amount': amount,
    'mode': mode,
    'photoUrl': photoUrl,
    'allocations': allocations.map((a) => a.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
  };
}

/// Audit record for receipt actions.
class ReceiptLog {
  String? id;
  String receiptNumber;
  String studentName;
  String action; // 'create'
  String changedBy;
  String detail;
  DateTime timestamp;

  ReceiptLog({
    this.id,
    this.receiptNumber = '',
    this.studentName = '',
    this.action = 'create',
    this.changedBy = '',
    this.detail = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ReceiptLog.fromFirestore(
      String id, Map<String, dynamic> d) =>
      ReceiptLog(
        id: id,
        receiptNumber: d['receiptNumber'] ?? '',
        studentName: d['studentName'] ?? '',
        action: d['action'] ?? 'create',
        changedBy: d['changedBy'] ?? '',
        detail: d['detail'] ?? '',
        timestamp: d['timestamp'] != null
            ? DateTime.tryParse(d['timestamp']) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
    'receiptNumber': receiptNumber,
    'studentName': studentName,
    'action': action,
    'changedBy': changedBy,
    'detail': detail,
    'timestamp': timestamp.toIso8601String(),
  };
}
