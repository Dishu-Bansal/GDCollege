import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gd_college/utils/timestamps.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_session.dart';
import '../../providers.dart';
import '../models/student_doc_models.dart';

/// Data access for the Student Docs (DMC + Degree) module.
///
/// Records live on the student document under `docRecords` (slotKey → map)
/// so a whole batch loads with a single students query. Files (DMC/Degree
/// scans, Aadhaar photos, live webcam photos) go to
/// `students/{id}/docs/{slotKey}/...` in Storage.
class FirebaseStudentDocsService {
  FirebaseFirestore get _db => db;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const _students = 'students';

  String get _by => UserSession().currentUser?.email ?? '';

  // ── Event logs ───────────────────────────────────────────────────────────
  /// Most recent stock/issue/update events, newest first (the Logs tab).
  Stream<List<DocLogEntry>> watchRecentDocLogs({int limit = 300}) {
    return _db
        .collection('docLogs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DocLogEntry.fromMap(d.data()))
            .toList());
  }

  /// Builds a log entry stamped with the current user (or [changedByOverride]
  /// for backfilled rows, where the original actor is stored on the record).
  DocLogEntry buildLog({
    required String studentId,
    required String studentName,
    required String course,
    required String slotKey,
    required String slotLabel,
    required bool isDmc,
    required String action,
    DateTime? at,
    String collectorName = '',
    String collectorAadhar = '',
    List<DocChange> changes = const [],
    String? changedByOverride,
  }) {
    return DocLogEntry(
      studentId: studentId,
      studentName: studentName,
      course: course,
      slotKey: slotKey,
      slotLabel: slotLabel,
      isDmc: isDmc,
      action: action,
      timestamp: at ?? DateTime.now(),
      changedBy: changedByOverride ?? _by,
      collectorName: collectorName,
      collectorAadhar: collectorAadhar,
      changes: changes,
    );
  }

  /// Atomically persists one slot record together with its log rows: the
  /// student-doc update and every `docLogs` set go in a SINGLE batch, so a
  /// log can never exist without its change (or vice versa).
  Future<void> commitSlotSave({
    required String studentId,
    required String slotKey,
    required StudentDocRecord record,
    List<DocLogEntry> logs = const [],
  }) async {
    record.updatedBy = _by;
    if (record.hasFile &&
        record.collector.name.trim().isNotEmpty &&
        record.collectedAt == null) {
      record.collectedAt = DateTime.now();
    }
    final batch = _db.batch();
    batch.update(_db.collection(_students).doc(studentId), {
      'docRecords.$slotKey': record.toMap(),
      // UTC so the student's "last updated" instant is timezone-unambiguous.
      'updatedAt': timestampToWire(DateTime.now()),
    });
    for (final log in logs) {
      batch.set(_db.collection('docLogs').doc(), log.toMap());
    }
    await batch.commit();
  }

  /// One-time backfill: synthesizes `docLogs` rows for records that predate
  /// event logging. A record with a scan gets a 'stocked' row; a complete
  /// one additionally gets an 'issued' row. Dates fall back through
  /// fileUploadedAt → collectedAt → the student doc's updatedAt, so old
  /// rows land on the best-known date instead of today. Deterministic doc
  /// ids make re-runs skip already-written rows. Returns rows written.
  Future<int> backfillDocLogs() async {
    final snap = await _db.collection(_students).get();
    var written = 0;
    var batch = _db.batch();
    var pending = 0;

    Future<void> flush() async {
      if (pending == 0) return;
      await batch.commit();
      batch = _db.batch();
      pending = 0;
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final records = StudentDocRecord.recordsOf(data);
      if (records.isEmpty) continue;
      final course = (data['nameOfCourse'] ?? '').toString();
      final slots = docSlotsForCourse(course);
      final fallback = parseTimestamp(data['updatedAt']);
      for (final entry in records.entries) {
        final rec = entry.value;
        if (!rec.hasFile) continue;
        final slot = slots.where((s) => s.key == entry.key).toList();
        final label =
            slot.isEmpty ? entry.key : slot.first.label;
        final isDmc = slot.isEmpty ? true : slot.first.isDmc;
        final stockedAt = rec.fileUploadedAt ??
            rec.collectedAt ??
            fallback ??
            DateTime.now();

        Future<void> addRow(DocLogEntry entry, String action) async {
          final id = '${doc.id}_${entry.slotKey}_$action';
          final existing = await _db
              .collection('docLogs')
              .doc(id)
              .get();
          if (existing.exists) return;
          batch.set(
              _db.collection('docLogs').doc(id), entry.toMap());
          pending++;
          written++;
          if (pending == 450) await flush();
        }

        await addRow(
          buildLog(
            studentId: doc.id,
            studentName: (data['name'] ?? '').toString(),
            course: course,
            slotKey: entry.key,
            slotLabel: label,
            isDmc: isDmc,
            action: 'stocked',
            at: stockedAt,
            changedByOverride: (rec.updatedBy).toString(),
          ),
          'stocked',
        );
        if (rec.complete(isDmc: isDmc)) {
          await addRow(
            buildLog(
              studentId: doc.id,
              studentName: (data['name'] ?? '').toString(),
              course: course,
              slotKey: entry.key,
              slotLabel: label,
              isDmc: isDmc,
              action: 'issued',
              at: rec.collectedAt ?? stockedAt,
              collectorName: rec.collector.name,
              collectorAadhar: rec.collector.aadharNumber,
              changedByOverride: (rec.updatedBy).toString(),
            ),
            'issued',
          );
        }
      }
    }
    await flush();
    return written;
  }

  // ── Batch reads ──────────────────────────────────────────────────────────
  /// One batch: students of [group] + [course] + [year]. Any of
  /// [course]/[year] may be null to skip that filter. Sorted by name
  /// client-side. Each entry carries the parsed `docRecords` map so status
  /// chips render without extra reads.
  ///
  /// NOTE: multi-filter queries need a composite index on
  /// (group, nameOfCourse, yearOfAdmission). On first run Firestore throws
  /// with a console link — create it once per database (production +
  /// test-db).
  Future<List<DocBatchEntry>> fetchBatch({
    required String group,
    String? course,
    int? year,
  }) async {
    Query<Map<String, dynamic>> q =
        _db.collection(_students).where('group', isEqualTo: group);
    if (course != null) {
      q = q.where('nameOfCourse', isEqualTo: course);
    }
    if (year != null) {
      q = q.where('yearOfAdmission', isEqualTo: year);
    }
    final snap = await q.get();
    final list = snap.docs.map((d) {
      final data = d.data();
      return DocBatchEntry(
        id: d.id,
        name: (data['name'] ?? '').toString(),
        fatherName: (data['fatherName'] ?? '').toString(),
        studentId: (data['studentId'] ?? '').toString(),
        course: (data['nameOfCourse'] ?? '').toString(),
        yearOfAdmission: (data['yearOfAdmission'] as num?)?.toInt(),
        records: StudentDocRecord.recordsOf(data),
      );
    }).toList();
    list.sort((a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // ── Record writes ────────────────────────────────────────────────────────
  /// Merge-writes one slot record with no logs. Prefer [commitSlotSave]
  /// whenever the change has log rows — it commits record + logs atomically.
  Future<void> saveRecord({
    required String studentId,
    required String slotKey,
    required StudentDocRecord record,
  }) =>
      commitSlotSave(
        studentId: studentId,
        slotKey: slotKey,
        record: record,
      );

  // ── File uploads ─────────────────────────────────────────────────────────
  Future<String> _uploadBytes({
    required String studentId,
    required String slotKey,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final ref = _storage
        .ref()
        .child('students/$studentId/docs/$slotKey/$fileName');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  /// Uploads the DMC / Degree / Certificate scan.
  Future<String> uploadSlotFile({
    required String studentId,
    required String slotKey,
    required String originalName,
    required Uint8List bytes,
  }) {
    final ext = originalName.contains('.')
        ? originalName.substring(originalName.lastIndexOf('.'))
        : '';
    return _uploadBytes(
      studentId: studentId,
      slotKey: slotKey,
      fileName: 'doc$ext',
      bytes: bytes,
    );
  }

  /// Uploads a collector identity photo (`aadhar` or `live`).
  Future<String> uploadCollectorPhoto({
    required String studentId,
    required String slotKey,
    required String which,
    required Uint8List bytes,
  }) =>
      _uploadBytes(
        studentId: studentId,
        slotKey: slotKey,
        fileName: '$which.jpg',
        bytes: bytes,
      );

  Future<void> deleteUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Already gone / inaccessible — the record update still proceeds.
    }
  }
}
