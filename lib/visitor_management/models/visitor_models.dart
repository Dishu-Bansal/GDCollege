// ── Visitor (unique external person) ──────────────────────────────────────────

/// A unique external visitor. One doc per person — repeat visits reuse the
/// same doc so visit history can be aggregated.
class VisitorModel {
  String? id;
  String name;
  int visitCount;
  DateTime? firstVisitAt;
  DateTime? lastVisitAt;

  /// Last known car license plate (used for autocomplete suggestions).
  String vehicleNumber;

  /// Last known place the visitor comes from (autocomplete suggestions).
  String fromPlace;

  VisitorModel({
    this.id,
    this.name = '',
    this.visitCount = 0,
    this.firstVisitAt,
    this.lastVisitAt,
    this.vehicleNumber = '',
    this.fromPlace = '',
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
        vehicleNumber: d['vehicleNumber'] ?? '',
        fromPlace: d['fromPlace'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    // Lower-cased copy so repeat visitors can be matched case-insensitively
    // without a client-side scan.
    'nameLower': name.toLowerCase(),
    'visitCount': visitCount,
    'firstVisitAt': firstVisitAt?.toIso8601String(),
    'lastVisitAt': lastVisitAt?.toIso8601String(),
    'vehicleNumber': vehicleNumber,
    'fromPlace': fromPlace,
  };
}

// ── Visitor Visit (check-in / check-out record) ──────────────────────────────

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
