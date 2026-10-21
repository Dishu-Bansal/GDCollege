import 'package:gd_college/utils/timestamps.dart';

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

  /// Set when the visitor is captured as an admission lead (admin-only
  /// "Add as Lead" on the detail screen). Old docs lack the key and read
  /// as false.
  bool addedAsLead;

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
    this.addedAsLead = false,
  });

  factory VisitorModel.fromFirestore(String id, Map<String, dynamic> d) =>
      VisitorModel(
        id: id,
        name: d['name'] ?? '',
        visitCount: (d['visitCount'] as num?)?.toInt() ?? 0,
        firstVisitAt: parseTimestamp(d['firstVisitAt']),
        lastVisitAt: parseTimestamp(d['lastVisitAt']),
        lastCheckOutAt: parseTimestamp(d['lastCheckOutAt']),
        vehicleNumber: d['vehicleNumber'] ?? '',
        fromPlace: d['fromPlace'] ?? '',
        phone: d['phone'] ?? '',
        addedAsLead: d['addedAsLead'] ?? false,
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    // Lower-cased copy so repeat visitors can be matched case-insensitively
    // without a client-side scan.
    'nameLower': name.toLowerCase(),
    'visitCount': visitCount,
    'firstVisitAt': timestampToWire(firstVisitAt),
    'lastVisitAt': timestampToWire(lastVisitAt),
    'lastCheckOutAt': timestampToWire(lastCheckOutAt),
    'vehicleNumber': vehicleNumber,
    'fromPlace': fromPlace,
    'phone': phone,
    'addedAsLead': addedAsLead,
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

  /// Business time of the check-out for single-row completed entries.
  /// Null for plain entry/exit rows.
  DateTime? outAt;
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
    this.outAt,
    this.accompanyingPeople = const [],
    this.by = '',
  })  : at = at ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  bool get isEntry => type == 'entry';

  /// A one-step completed entry (check-in + check-out logged together as a
  /// single 'Entry added' row).
  bool get isCompleted => type == 'completed';
  bool get isStaff => personType == 'staff';

  factory VisitorEventModel.fromFirestore(String id, Map<String, dynamic> d) =>
      VisitorEventModel(
        id: id,
        type: d['type'] ?? 'entry',
        at: parseTimestamp(d['at']) ?? DateTime.now(),
        // Pre-createdAt events fall back to their business time.
        createdAt: parseTimestamp(d['createdAt']) ??
            parseTimestamp(d['at']) ??
            DateTime.now(),
        visitId: d['visitId'] ?? '',
        personType: d['personType'] ?? 'visitor',
        personRefId: d['personRefId'] ?? '',
        name: d['name'] ?? '',
        vehicleNumber: d['vehicleNumber'] ?? '',
        purpose: d['purpose'] ?? '',
        fromPlace: d['fromPlace'] ?? '',
        phone: d['phone'] ?? '',
        outAt: parseTimestamp(d['outAt']),
        accompanyingPeople: List<String>.from(d['accompanyingPeople'] ?? []),
        by: d['by'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'type': type,
    'at': timestampToWire(at),
    'createdAt': timestampToWire(createdAt),
    'visitId': visitId,
    'personType': personType,
    'personRefId': personRefId,
    'name': name,
    'vehicleNumber': vehicleNumber,
    'purpose': purpose,
    'fromPlace': fromPlace,
    'phone': phone,
    'outAt': timestampToWire(outAt),
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

  /// True when the visit was registered complete in one step (check-in +
  /// check-out entered together), so the log keeps a single 'Entry added'
  /// row instead of separate entry/exit rows. Old docs lack the key.
  bool completedAtEntry;
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
    this.completedAtEntry = false,
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
        checkInAt: parseTimestamp(d['checkInAt']) ?? DateTime.now(),
        checkOutAt: parseTimestamp(d['checkOutAt']),
        completedAtEntry: d['completedAtEntry'] == true,
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
    'checkInAt': timestampToWire(checkInAt),
    'checkOutAt': timestampToWire(checkOutAt),
    'completedAtEntry': completedAtEntry,
    // Explicit boolean so the "currently inside" query can use a reliable
    // equality filter (null-equality filters don't re-evaluate reliably when
    // a doc's field changes from missing to a value).
    'inside': checkOutAt == null,
    'checkedInBy': checkedInBy,
    'checkedOutBy': checkedOutBy,
  };
}
