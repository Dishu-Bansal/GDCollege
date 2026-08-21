/// Units selectable for bill line items.
const List<String> stockUnits = [
  'Pieces',
  'kg',
  'gram',
  'metre',
  'litres',
  'dozen',
  'pack',
  'box',
  'roll',
  'set',
];

// ── Bill line item ─────────────────────────────────────────────────────────────

class BillItem {
  String name;
  int quantity;
  double pricePerUnit;
  String unit;
  String? catalogItemId;

  BillItem({
    this.name = '',
    this.quantity = 0,
    this.pricePerUnit = 0,
    this.unit = 'Pieces',
    this.catalogItemId,
  });

  double get total => pricePerUnit * quantity;

  factory BillItem.fromMap(Map<String, dynamic> d) => BillItem(
    name: d['name'] ?? '',
    quantity: (d['quantity'] ?? 0) as int,
    pricePerUnit: (d['pricePerUnit'] ?? 0).toDouble(),
    unit: d['unit'] ?? 'Pieces',
    catalogItemId: d['catalogItemId'],
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'pricePerUnit': pricePerUnit,
    'unit': unit,
    if (catalogItemId != null) 'catalogItemId': catalogItemId,
  };
}

// ── Bill ───────────────────────────────────────────────────────────────────────

class BillModel {
  String? id;
  String billNumber;
  String storeName;
  DateTime billDate;
  DateTime? paymentDate;
  String paymentBy;
  DateTime? reimbursementDate;
  String reimbursedBy;
  bool reimbursementRequired;
  bool paid;
  String? photoUrl;
  List<BillItem> items;
  DateTime createdAt;
  DateTime updatedAt;
  String createdBy;
  String updatedBy;

  BillModel({
    this.id,
    this.billNumber = '',
    this.storeName = '',
    DateTime? billDate,
    this.paymentDate,
    this.paymentBy = '',
    this.reimbursementDate,
    this.reimbursedBy = '',
    this.reimbursementRequired = false,
    this.paid = false,
    this.photoUrl,
    this.items = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  })  : billDate = billDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get totalAmount =>
      items.fold(0, (sum, i) => sum + i.total);

  bool get isPaymentPending => reimbursementRequired && !paid;

  factory BillModel.fromFirestore(String id, Map<String, dynamic> d) =>
      BillModel(
        id: id,
        billNumber: d['billNumber'] ?? '',
        storeName: d['storeName'] ?? '',
        billDate: d['billDate'] != null
            ? DateTime.tryParse(d['billDate']) ?? DateTime.now()
            : DateTime.now(),
        paymentDate: d['paymentDate'] != null
            ? DateTime.tryParse(d['paymentDate'])
            : null,
        paymentBy: d['paymentBy'] ?? '',
        reimbursementDate: d['reimbursementDate'] != null
            ? DateTime.tryParse(d['reimbursementDate'])
            : null,
        reimbursedBy: d['reimbursedBy'] ?? '',
        reimbursementRequired: d['reimbursementRequired'] ?? false,
        paid: d['paid'] ?? false,
        photoUrl: d['photoUrl'],
        items: (d['items'] as List<dynamic>? ?? [])
            .map((e) => BillItem.fromMap(e as Map<String, dynamic>))
            .toList(),
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
    'billNumber': billNumber,
    'storeName': storeName,
    'billDate': billDate.toIso8601String(),
    'paymentDate': paymentDate?.toIso8601String(),
    'paymentBy': paymentBy,
    'reimbursementDate': reimbursementDate?.toIso8601String(),
    'reimbursedBy': reimbursedBy,
    'reimbursementRequired': reimbursementRequired,
    'paid': paid,
    'photoUrl': photoUrl,
    'items': items.map((e) => e.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'createdBy': createdBy,
    'updatedBy': updatedBy,
  };
}

// ── Bill log ───────────────────────────────────────────────────────────────────

class BillLog {
  String? id;
  String billId;
  String billNumber;
  String action; // 'create' | 'update' | 'pay'
  String changedBy;
  String detail;
  DateTime timestamp;

  BillLog({
    this.id,
    this.billId = '',
    this.billNumber = '',
    this.action = 'create',
    this.changedBy = '',
    this.detail = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory BillLog.fromFirestore(String id, Map<String, dynamic> d) =>
      BillLog(
        id: id,
        billId: d['billId'] ?? '',
        billNumber: d['billNumber'] ?? '',
        action: d['action'] ?? 'create',
        changedBy: d['changedBy'] ?? '',
        detail: d['detail'] ?? '',
        timestamp: d['timestamp'] != null
            ? DateTime.tryParse(d['timestamp']) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
    'billId': billId,
    'billNumber': billNumber,
    'action': action,
    'changedBy': changedBy,
    'detail': detail,
    'timestamp': timestamp.toIso8601String(),
  };
}
