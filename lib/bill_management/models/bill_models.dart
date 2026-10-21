import 'dart:typed_data';

import 'package:gd_college/utils/timestamps.dart';

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

  /// Transient item photo picked in the bill form for free-text items. Not
  /// persisted on the bill; when the stock sync creates/matches a catalog
  /// entry for the item, the photo is uploaded and its URL saved on it.
  Uint8List? photoBytes;
  String? photoName;

  BillItem({
    this.name = '',
    this.quantity = 0,
    this.pricePerUnit = 0,
    this.unit = 'Pieces',
    this.catalogItemId,
    this.photoBytes,
    this.photoName,
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

  /// 'stock' (items synced into stock) or 'service' (no physical product —
  /// items stay on the bill only, never touch stock). Old docs lack the key
  /// and read as 'stock', which matches how they were created.
  String billType;
  DateTime billDate;
  DateTime? receivedDate;
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
    this.billType = 'stock',
    DateTime? billDate,
    this.receivedDate,
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

  bool get isService => billType == 'service';

  bool get isPaymentPending => reimbursementRequired && !paid;

  factory BillModel.fromFirestore(String id, Map<String, dynamic> d) =>
      BillModel(
        id: id,
        billNumber: d['billNumber'] ?? '',
        storeName: d['storeName'] ?? '',
        billType: d['billType'] ?? 'stock',
        billDate: parseDate(d['billDate']) ?? DateTime.now(),
        receivedDate: parseDate(d['receivedDate']),
        paymentDate: parseDate(d['paymentDate']),
        paymentBy: d['paymentBy'] ?? '',
        reimbursementDate: parseDate(d['reimbursementDate']),
        reimbursedBy: d['reimbursedBy'] ?? '',
        reimbursementRequired: d['reimbursementRequired'] ?? false,
        paid: d['paid'] ?? false,
        photoUrl: d['photoUrl'],
        items: (d['items'] as List<dynamic>? ?? [])
            .map((e) => BillItem.fromMap(e as Map<String, dynamic>))
            .toList(),
        createdAt: parseTimestamp(d['createdAt']) ?? DateTime.now(),
        updatedAt: parseTimestamp(d['updatedAt']) ?? DateTime.now(),
        createdBy: d['createdBy'] ?? '',
        updatedBy: d['updatedBy'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'billNumber': billNumber,
    'storeName': storeName,
    'billType': billType,
    // Bill/received/payment/reimbursement are calendar dates: stored as
    // yyyy-MM-dd, so no timezone can shift them.
    'billDate': dateToWire(billDate),
    'receivedDate': dateToWire(receivedDate),
    'paymentDate': dateToWire(paymentDate),
    'paymentBy': paymentBy,
    'reimbursementDate': dateToWire(reimbursementDate),
    'reimbursedBy': reimbursedBy,
    'reimbursementRequired': reimbursementRequired,
    'paid': paid,
    'photoUrl': photoUrl,
    'items': items.map((e) => e.toMap()).toList(),
    'createdAt': timestampToWire(createdAt),
    'updatedAt': timestampToWire(updatedAt),
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
        timestamp: parseTimestamp(d['timestamp']) ?? DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
    'billId': billId,
    'billNumber': billNumber,
    'action': action,
    'changedBy': changedBy,
    'detail': detail,
    'timestamp': timestampToWire(timestamp),
  };
}
