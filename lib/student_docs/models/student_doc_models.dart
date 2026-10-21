/// Data model for the Student Docs (DMC + Degree) tracking module.
///
/// DMC slots are derived from the student's course — yearly courses get one
/// slot per year, semester courses one per semester:
/// - B.ED (yearly): Year 1, Year 2
/// - D.ED / D.El.Ed (yearly): Year 1, Year 2
/// - M.ED (semester): Sem 1–4
/// - D.P.ED (semester): Sem 1–4
/// - ANM (yearly): Year 1, Year 2
/// - GNM (yearly): Year 1, Year 2, Year 3
/// - Anything else (Skill India): a single Certificate slot, no DMCs.
///
/// Every slot (plus the Degree) stores the document file, per-subject marks
/// and the collector's identity: name, phone, Aadhaar number + Aadhaar photo
/// and a live webcam photo taken at handover.
///
/// Records live on the student document itself under `docRecords`
/// (slotKey → record map) so a whole batch loads with one students query.

/// One trackable slot: a DMC, the Degree, or the Skill India Certificate.
class DocSlot {
  final String key;
  final String label;
  final bool isDmc;

  const DocSlot({
    required this.key,
    required this.label,
    this.isDmc = true,
  });
}

/// DMC slots + terminal slot for a course. Old/unknown courses fall back to
/// the single Certificate slot (Skill India behaviour).
List<DocSlot> docSlotsForCourse(String course) {
  String norm(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  DocSlot degree(String courseLabel) =>
      DocSlot(key: 'degree', label: '$courseLabel Degree', isDmc: false);

  switch (norm(course)) {
    case 'BED':
      return [
        const DocSlot(key: 'bed-y1', label: 'B.Ed Year 1 DMC'),
        const DocSlot(key: 'bed-y2', label: 'B.Ed Year 2 DMC'),
        degree('B.Ed'),
      ];
    case 'DED':
    case 'DELED':
      return [
        const DocSlot(key: 'ded-y1', label: 'D.El.Ed Year 1 DMC'),
        const DocSlot(key: 'ded-y2', label: 'D.El.Ed Year 2 DMC'),
        degree('D.El.Ed'),
      ];
    case 'MED':
      return [
        for (var i = 1; i <= 4; i++)
          DocSlot(key: 'med-s$i', label: 'M.Ed Sem $i DMC'),
        degree('M.Ed'),
      ];
    case 'DPED':
      return [
        for (var i = 1; i <= 4; i++)
          DocSlot(key: 'dped-s$i', label: 'D.P.Ed Sem $i DMC'),
        degree('D.P.Ed'),
      ];
    case 'ANM':
      return [
        const DocSlot(key: 'anm-y1', label: 'ANM Year 1 DMC'),
        const DocSlot(key: 'anm-y2', label: 'ANM Year 2 DMC'),
        degree('ANM'),
      ];
    case 'GNM':
      return [
        for (var i = 1; i <= 3; i++)
          DocSlot(key: 'gnm-y$i', label: 'GNM Year $i DMC'),
        degree('GNM'),
      ];
    default:
      final label = course.trim().isEmpty ? 'Course' : course.trim();
      return [DocSlot(key: 'certificate', label: '$label Certificate')];
  }
}

/// Marks in one subject of a DMC.
class SubjectMark {
  String subject;
  double? obtained;
  double? max;

  SubjectMark({this.subject = '', this.obtained, this.max});

  factory SubjectMark.fromMap(Map<String, dynamic> m) => SubjectMark(
        subject: (m['subject'] ?? '').toString(),
        obtained: (m['obtained'] as num?)?.toDouble(),
        max: (m['max'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'subject': subject,
        'obtained': obtained,
        'max': max,
      };
}

/// Who physically collected the DMC / Degree from the office.
class CollectorInfo {
  String name;
  String phone;
  String aadharNumber;
  String? aadharUrl;
  String? livePhotoUrl;

  CollectorInfo({
    this.name = '',
    this.phone = '',
    this.aadharNumber = '',
    this.aadharUrl,
    this.livePhotoUrl,
  });

  factory CollectorInfo.fromMap(Map<String, dynamic> m) => CollectorInfo(
        name: (m['name'] ?? '').toString(),
        phone: (m['phone'] ?? '').toString(),
        aadharNumber: (m['aadharNumber'] ?? '').toString(),
        aadharUrl: m['aadharUrl'] as String?,
        livePhotoUrl: m['livePhotoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'aadharNumber': aadharNumber,
        'aadharUrl': aadharUrl,
        'livePhotoUrl': livePhotoUrl,
      };

  bool get isComplete =>
      name.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      aadharNumber.trim().isNotEmpty &&
      (aadharUrl ?? '').isNotEmpty &&
      (livePhotoUrl ?? '').isNotEmpty;
}

/// The stored record for one slot: document file, subject marks and the
/// collector who took it. Old students have no entry and read as empty.
class StudentDocRecord {
  String? fileUrl;
  String? fileName;

  /// When the current scan was uploaded (office receipt = stock date).
  /// Older records predate the field and read null.
  DateTime? fileUploadedAt;
  List<SubjectMark> subjects;
  CollectorInfo collector;
  DateTime? collectedAt;
  String updatedBy;

  StudentDocRecord({
    this.fileUrl,
    this.fileName,
    this.fileUploadedAt,
    this.subjects = const [],
    CollectorInfo? collector,
    this.collectedAt,
    this.updatedBy = '',
  }) : collector = collector ?? CollectorInfo();

  bool get hasFile => (fileUrl ?? '').isNotEmpty;

  /// In stock = the scan sits with the office (physical doc received).
  bool get inStock => hasFile;

  /// Issued = a collector with full identity took the document.
  bool issued({required bool isDmc}) => complete(isDmc: isDmc);

  double get totalObtained => subjects.fold(
      0, (sum, s) => sum + (s.obtained ?? 0));
  double get totalMax =>
      subjects.fold(0, (sum, s) => sum + (s.max ?? 0));
  double? get percentage =>
      totalMax > 0 ? totalObtained / totalMax * 100 : null;

  /// A slot counts as fully done when the document, at least the
  /// collector's identity, and (for DMCs) marks are present.
  bool complete({required bool isDmc}) {
    if (!hasFile || !collector.isComplete) return false;
    if (isDmc) {
      if (subjects.isEmpty) return false;
      for (final s in subjects) {
        if (s.subject.trim().isEmpty ||
            s.obtained == null ||
            s.max == null) {
          return false;
        }
      }
    }
    return true;
  }

  factory StudentDocRecord.fromMap(Map<String, dynamic> m) =>
      StudentDocRecord(
        fileUrl: m['fileUrl'] as String?,
        fileName: m['fileName'] as String?,
        // Legacy values are naive local strings; newer/UTC values carry a
        // zone suffix — normalise both to the device's local zone.
        fileUploadedAt: m['fileUploadedAt'] != null
            ? DateTime.tryParse(m['fileUploadedAt'].toString())?.toLocal()
            : null,
        subjects: (m['subjects'] as List? ?? [])
            .map((e) =>
                SubjectMark.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
        collector: CollectorInfo.fromMap(
            ((m['collector'] as Map?) ?? {}).cast<String, dynamic>()),
        collectedAt: m['collectedAt'] != null
            ? DateTime.tryParse(m['collectedAt'].toString())?.toLocal()
            : null,
        updatedBy: (m['updatedBy'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileUploadedAt': fileUploadedAt?.toIso8601String(),
        'subjects': subjects.map((s) => s.toMap()).toList(),
        'collector': collector.toMap(),
        'collectedAt': collectedAt?.toIso8601String(),
        'updatedBy': updatedBy,
      };

  /// Reads the `docRecords` map off a raw student document. Missing (old
  /// students) reads as an empty map — nothing breaks.
  static Map<String, StudentDocRecord> recordsOf(
      Map<String, dynamic> studentData) {
    final raw = studentData['docRecords'];
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(),
        StudentDocRecord.fromMap((v as Map).cast<String, dynamic>())));
  }
}

/// One row of a batch list: the student plus their parsed doc records.
class DocBatchEntry {
  final String id;
  final String name;
  final String fatherName;
  final String studentId;
  final String course;
  final int? yearOfAdmission;
  final Map<String, StudentDocRecord> records;

  const DocBatchEntry({
    required this.id,
    required this.name,
    this.fatherName = '',
    this.studentId = '',
    required this.course,
    required this.yearOfAdmission,
    required this.records,
  });

  /// DMC slots done / total for the student's course.
  (int, int) dmcProgress() {
    final slots = docSlotsForCourse(course).where((s) => s.isDmc).toList();
    final done = slots
        .where((s) =>
            (records[s.key]?.complete(isDmc: true) ?? false))
        .length;
    return (done, slots.length);
  }

  /// Whether the terminal (Degree / Certificate) slot is complete.
  bool terminalDone() {
    final terminal =
        docSlotsForCourse(course).where((s) => !s.isDmc).toList();
    if (terminal.isEmpty) return false;
    return records[terminal.first.key]
            ?.complete(isDmc: false) ??
        false;
  }
}

/// One field-level change inside an 'updated' log row. Text changes carry
/// old/new values; file and photo changes carry old/new URLs (rendered as
/// side-by-side previews in the Logs tab).
class DocChange {
  final String field;
  final String oldValue;
  final String newValue;
  final String? oldUrl;
  final String? newUrl;

  const DocChange({
    required this.field,
    this.oldValue = '',
    this.newValue = '',
    this.oldUrl,
    this.newUrl,
  });

  bool get isFileChange =>
      (oldUrl ?? '').isNotEmpty || (newUrl ?? '').isNotEmpty;

  factory DocChange.fromMap(Map<String, dynamic> m) => DocChange(
        field: (m['field'] ?? '').toString(),
        oldValue: (m['oldValue'] ?? '').toString(),
        newValue: (m['newValue'] ?? '').toString(),
        oldUrl: m['oldUrl'] as String?,
        newUrl: m['newUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'field': field,
        'oldValue': oldValue,
        'newValue': newValue,
        'oldUrl': oldUrl,
        'newUrl': newUrl,
      };
}

/// One stock/issue/update event from the top-level `docLogs` collection.
class DocLogEntry {
  final String studentId;
  final String studentName;
  final String course;
  final String slotKey;
  final String slotLabel;
  final bool isDmc;
  final String action; // 'stocked' | 'issued' | 'updated'
  final DateTime timestamp;
  final String changedBy;

  /// Collector identity snapshot (populated on 'issued' rows).
  final String collectorName;
  final String collectorAadhar;

  /// Field diffs (populated on 'updated' rows).
  final List<DocChange> changes;

  const DocLogEntry({
    required this.studentId,
    required this.studentName,
    required this.course,
    required this.slotKey,
    required this.slotLabel,
    required this.isDmc,
    required this.action,
    required this.timestamp,
    required this.changedBy,
    this.collectorName = '',
    this.collectorAadhar = '',
    this.changes = const [],
  });

  bool get stocked => action == 'stocked';
  bool get issued => action == 'issued';

  factory DocLogEntry.fromMap(Map<String, dynamic> m) => DocLogEntry(
        studentId: (m['studentId'] ?? '').toString(),
        studentName: (m['studentName'] ?? '').toString(),
        course: (m['course'] ?? '').toString(),
        slotKey: (m['slotKey'] ?? '').toString(),
        slotLabel: (m['slotLabel'] ?? '').toString(),
        isDmc: m['isDmc'] ?? true,
        action: (m['action'] ?? '').toString(),
        timestamp: (m['timestamp'] != null
                ? DateTime.tryParse(m['timestamp'].toString())
                : null)
                ?.toLocal() ??
            DateTime.now(),
        changedBy: (m['changedBy'] ?? '').toString(),
        collectorName: (m['collectorName'] ?? '').toString(),
        collectorAadhar: (m['collectorAadhar'] ?? '').toString(),
        changes: (m['changes'] as List? ?? [])
            .map((e) =>
                DocChange.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        'course': course,
        'slotKey': slotKey,
        'slotLabel': slotLabel,
        'isDmc': isDmc,
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'changedBy': changedBy,
        'collectorName': collectorName,
        'collectorAadhar': collectorAadhar,
        'changes': changes.map((c) => c.toMap()).toList(),
      };
}
