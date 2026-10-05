// ── Visitor (unique external person) ──────────────────────────────────────────

/// A unique external visitor. One doc per person — repeat visits reuse the
/// same doc so visit history can be aggregated.
class VisitorModel {
  String? id;
  String name;
  int visitCount;
  DateTime? firstVisitAt;
  DateTime? lastVisitAt;

  /// Last check-out time (null while the visitor is inside or has never
  /// checked out through a tracked visit).
  DateTime? lastCheckOutAt;

  /// Last known car license plate (used for autocomplete suggestions).
  String vehicleNumber;

  /// Last known place the visitor comes from (autocomplete suggestions).
  String fromPlace;

  /// Last known phone number (autofills the check-in form on pick).
  /// Added after launch: old docs lack the key and read as ''.
  String phone;

  VisitorModel({
    this.id,
    this.name = '',
    this.visitCount = 0,
    this.firstVisitAt,
    this.lastVisitAt,
    this.lastCheckOutAt,
    this.vehicleNumber = '',
    this.fromPlace = '',
    this.phone = '',
  });

  factory VisitorModel.fromFirestore(String id, Map<String, dynamic> d) =>
      VisitorModel(
        id: id,
        name: d['name'] ?? '',
        visitCount: (d['visitCount'] as num?)?.toInt() ?? 0,
        firstVisitAt: d['firstVisitAt'] != null
            ? DateTime.tryParse(d['firstVisitAt'])
            : null,
        lastVisitAt: d['lastVisitAt'] != null
            ? DateTime.tryParse(d['lastVisitAt'])
            : null,
        lastCheckOutAt: d['lastCheckOutAt'] != null
            ? DateTime.tryParse(d['lastCheckOutAt'])
            : null,
        vehicleNumber: d['vehicleNumber'] ?? '',
        fromPlace: d['fromPlace'] ?? '',
        phone: d['phone'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    // Lower-cased copy so repeat visitors can be matched case-insensitively
    // without a client-side scan.
    'nameLower': name.toLowerCase(),
    'visitCount': visitCount,
    'firstVisitAt': firstVisitAt?.toIso8601String(),
    'lastVisitAt': lastVisitAt?.toIso8601String(),
    'lastCheckOutAt': lastCheckOutAt?.toIso8601String(),
    'vehicleNumber': vehicleNumber,
    'fromPlace': fromPlace,
    'phone': phone,
  };
}

// ── Visitor Event (global log record) ───────────────────────────────────────
// One doc per entry and one per exit, so the global log lists check-outs as
// their own time-sorted rows instead of merging them into the entry row.

/// A single check-in ('entry') or check-out ('exit') log event.
class VisitorEventModel {
  String? id;

  /// 'entry' or 'exit'.
  String type;

  /// When the event happened (manually entered check-in/check-out time).
  DateTime at;

  /// When the event doc was created (system time). The global log sorts by
  /// this, so a backdated entry surfaces at the top as a late log.
  DateTime createdAt;

  /// The visit session this event belongs to.
  String visitId;

  /// 'staff' or 'visitor'.
  String personType;
  String personRefId;
  String name;
  String vehicleNumber;
  String purpose;
  String fromPlace;
  String phone;
  List<String> accompanyingPeople;

  /// Staff email that recorded the event.
  String by;

  VisitorEventModel({
    this.id,
    this.type = 'entry',
    DateTime? at,
    DateTime? createdAt,
    this.visitId = '',
    this.personType = 'visitor',
    this.personRefId = '',
    this.name = '',
    this.vehicleNumber = '',
    this.purpose = '',
    this.fromPlace = '',
    this.phone = '',
    this.accompanyingPeople = const [],
    this.by = '',
  })  : at = at ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  bool get isEntry => type == 'entry';
  bool get isStaff => personType == 'staff';

  factory VisitorEventModel.fromFirestore(String id, Map<String, dynamic> d) =>
      VisitorEventModel(
        id: id,
        type: d['type'] ?? 'entry',
        at: d['at'] != null
            ? DateTime.tryParse(d['at']) ?? DateTime.now()
            : DateTime.now(),
        // Pre-createdAt events fall back to their business time.
        createdAt: d['createdAt'] != null
            ? DateTime.tryParse(d['createdAt']) ?? DateTime.now()
            : (d['at'] != null
                ? DateTime.tryParse(d['at']) ?? DateTime.now()
                : DateTime.now()),
        visitId: d['visitId'] ?? '',
        personType: d['personType'] ?? 'visitor',
        personRefId: d['personRefId'] ?? '',
        name: d['name'] ?? '',
        vehicleNumber: d['vehicleNumber'] ?? '',
        purpose: d['purpose'] ?? '',
        fromPlace: d['fromPlace'] ?? '',
        phone: d['phone'] ?? '',
        accompanyingPeople: List<String>.from(d['accompanyingPeople'] ?? []),
        by: d['by'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'type': type,
    'at': at.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'visitId': visitId,
    'personType': personType,
    'personRefId': personRefId,
    'name': name,
    'vehicleNumber': vehicleNumber,
    'purpose': purpose,
    'fromPlace': fromPlace,
    'phone': phone,
    'accompanyingPeople': accompanyingPeople,
    'by': by,
  };
}

// ── Visitor Visit (check-in / check-out session) ─────────────────────────────

/// One check-in / check-out session, for both staff members and external
/// visitors.
class VisitorVisitModel {
  String? id;

  /// 'staff' or 'visitor'.
  String personType;

  /// Staff document id (for staff entries) or [VisitorModel] id (for
  /// visitor entries).
  String personRefId;

  String name;
  String vehicleNumber;
  String purpose;
  String fromPlace;
  String phone;
  List<String> accompanyingPeople;
  DateTime checkInAt;
  DateTime? checkOutAt;
  String checkedInBy;
  String checkedOutBy;

  VisitorVisitModel({
    this.id,
    this.personType = 'visitor',
    this.personRefId = '',
    this.name = '',
    this.vehicleNumber = '',
    this.purpose = '',
    this.fromPlace = '',
    this.phone = '',
    this.accompanyingPeople = const [],
    DateTime? checkInAt,
    this.checkOutAt,
    this.checkedInBy = '',
    this.checkedOutBy = '',
  }) : checkInAt = checkInAt ?? DateTime.now();

  /// True while the person has not checked out yet.
  bool get isInside => checkOutAt == null;

  bool get isStaff => personType == 'staff';

  factory VisitorVisitModel.fromFirestore(String id, Map<String, dynamic> d) =>
      VisitorVisitModel(
        id: id,
        personType: d['personType'] ?? 'visitor',
        personRefId: d['personRefId'] ?? '',
        name: d['name'] ?? '',
        vehicleNumber: d['vehicleNumber'] ?? '',
        purpose: d['purpose'] ?? '',
        fromPlace: d['fromPlace'] ?? '',
        phone: d['phone'] ?? '',
        accompanyingPeople: List<String>.from(d['accompanyingPeople'] ?? []),
        checkInAt: d['checkInAt'] != null
            ? DateTime.tryParse(d['checkInAt']) ?? DateTime.now()
            : DateTime.now(),
        checkOutAt: d['checkOutAt'] != null
            ? DateTime.tryParse(d['checkOutAt'])
            : null,
        checkedInBy: d['checkedInBy'] ?? '',
        checkedOutBy: d['checkedOutBy'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'personType': personType,
    'personRefId': personRefId,
    'name': name,
    'vehicleNumber': vehicleNumber,
    'purpose': purpose,
    'fromPlace': fromPlace,
    'phone': phone,
    'accompanyingPeople': accompanyingPeople,
    'checkInAt': checkInAt.toIso8601String(),
    'checkOutAt': checkOutAt?.toIso8601String(),
    // Explicit boolean so the "currently inside" query can use a reliable
    // equality filter (null-equality filters don't re-evaluate reliably when
    // a doc's field changes from missing to a value).
    'inside': checkOutAt == null,
    'checkedInBy': checkedInBy,
    'checkedOutBy': checkedOutBy,
  };
}
