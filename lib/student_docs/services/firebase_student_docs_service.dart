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
  /// The [at] instant is a local placeholder: live rows committed via
  /// [commitSlotSave] take server time in the write map.
  DocLogEntry buildLog({
    required String studentId,
    required String studentName,
    String rollNo = '',
    int? yearOfAdmission,
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
      rollNo: rollNo,
      yearOfAdmission: yearOfAdmission,
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

  /// Reads the currently stored slot record, or null when the student doc or
  /// the slot entry is missing/unreadable. Used to tell fresh stamps apart
  /// from historical ones so unrelated edits never move old dates.
  Future<StudentDocRecord?> _storedSlot(
      DocumentReference<Map<String, dynamic>> ref, String slotKey) async {
    try {
      final snap = await ref.get();
      final data = snap.data();
      if (data == null) return null;
      return StudentDocRecord.recordsOf(data)[slotKey];
    } catch (_) {
      return null;
    }
  }

  /// True when [incoming] is a freshly stamped instant: set now while a
  /// different instant (or nothing) was stored. Untouched historical values
  /// compare equal and return false, so they keep their exact instant.
  bool _isNewStamp(DateTime? incoming, DateTime? stored) {
    if (incoming == null) return false;
    if (stored == null) return true;
    return incoming.microsecondsSinceEpoch !=
        stored.microsecondsSinceEpoch;
  }

  /// Atomically persists one slot record together with its log rows: the
  /// student-doc update and every `docLogs` set go in a SINGLE batch, so a
  /// log can never exist without its change (or vice versa).
  ///
  /// Audit instants take Firestore server time: `updatedAt` and every live
  /// log `timestamp` are always [FieldValue.serverTimestamp()], and
  /// `fileUploadedAt` / `collectedAt` take server time when newly stamped
  /// (previously absent or changed since the stored slot). Historical stamps
  /// that pass through untouched keep whatever the model serialised.
  /// After commit the written slot is re-read and the server-resolved
  /// instants are folded back onto [record] (the caller's live object), so
  /// sort/display code immediately sees exact values.
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
      // Local placeholder until the server stamp below resolves; refreshed
      // from the re-read after commit.
      record.collectedAt = DateTime.now();
    }
    final studentRef = _db.collection(_students).doc(studentId);
    final needsCheck =
        record.fileUploadedAt != null || record.collectedAt != null;
    final stored =
        needsCheck ? await _storedSlot(studentRef, slotKey) : null;
    final recordMap = record.toMap();
    if (_isNewStamp(record.fileUploadedAt, stored?.fileUploadedAt)) {
      recordMap['fileUploadedAt'] = FieldValue.serverTimestamp();
    }
    if (_isNewStamp(record.collectedAt, stored?.collectedAt)) {
      recordMap['collectedAt'] = FieldValue.serverTimestamp();
    }
    final batch = _db.batch();
    batch.update(studentRef, {
      'docRecords.$slotKey': recordMap,
      // Server time so the student's "last updated" instant never depends
      // on the writing device's clock.
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final log in logs) {
      // Live stock/issue/update events happened now: server time,
      // overriding the client placeholder the model serialised.
      final logMap = log.toMap();
      logMap['timestamp'] = FieldValue.serverTimestamp();
      batch.set(_db.collection('docLogs').doc(), logMap);
    }
    await batch.commit();

    // The caller keeps using `record` (sort/display) — refresh the
    // server-stamped instants so it shows the exact committed values.
    try {
      final fresh = await studentRef.get();
      final freshData = fresh.data();
      if (freshData != null) {
        final freshRec =
            StudentDocRecord.recordsOf(freshData)[slotKey];
        if (freshRec != null) {
          record.fileUploadedAt = freshRec.fileUploadedAt;
          record.collectedAt = freshRec.collectedAt;
        }
      }
    } catch (_) {
      // Offline/permission edge: the caller keeps the local placeholders.
    }
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
      final backfillRoll = (data['studentId'] ?? '').toString();
      final backfillYear = (data['yearOfAdmission'] as num?)?.toInt();
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
            rollNo: backfillRoll,
            yearOfAdmission: backfillYear,
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
              rollNo: backfillRoll,
              yearOfAdmission: backfillYear,
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

  /// One-time migration: converts legacy ISO-8601 STRING instants for this
  /// module's stamped fields into native Firestore [Timestamp] values,
  /// preserving the exact instant (as [parseTimestamp] interprets it, the
  /// same reading display/sort code already uses). Covers:
  /// - `students`: `updatedAt`, plus per-slot
  ///   `docRecords.<slotKey>.fileUploadedAt` / `.collectedAt`;
  /// - `docLogs`: `timestamp`.
  /// `meta/subjectNames` holds no timestamps and is skipped. Already-native
  /// values, nulls and unparseable strings are left untouched. Writes go in
  /// 500-doc batches. Returns per-collection docs updated. No UI calls this;
  /// run once from console/tooling.
  Future<Map<String, int>> backfillTimestampsToNative() async {
    final counts = {'students': 0, 'docLogs': 0};

    Timestamp? nativeOf(Object? value) {
      if (value is! String) return null;
      final parsed = parseTimestamp(value);
      if (parsed == null) return null;
      return Timestamp.fromDate(parsed);
    }

    var batch = _db.batch();
    var pending = 0;

    Future<void> flush() async {
      if (pending == 0) return;
      await batch.commit();
      batch = _db.batch();
      pending = 0;
    }

    final students = await _db.collection(_students).get();
    for (final doc in students.docs) {
      final data = doc.data();
      final updates = <String, Object>{};
      final stampedUpdatedAt = nativeOf(data['updatedAt']);
      if (stampedUpdatedAt != null) {
        updates['updatedAt'] = stampedUpdatedAt;
      }
      final rawRecords = data['docRecords'];
      if (rawRecords is Map) {
        for (final entry in rawRecords.entries) {
          if (entry.value is! Map) continue;
          final slot = entry.key.toString();
          final rec = (entry.value as Map).cast<String, dynamic>();
          final stampedUploaded = nativeOf(rec['fileUploadedAt']);
          if (stampedUploaded != null) {
            updates['docRecords.$slot.fileUploadedAt'] = stampedUploaded;
          }
          final stampedCollected = nativeOf(rec['collectedAt']);
          if (stampedCollected != null) {
            updates['docRecords.$slot.collectedAt'] = stampedCollected;
          }
        }
      }
      if (updates.isNotEmpty) {
        batch.update(doc.reference, updates);
        pending++;
        counts['students'] = counts['students']! + 1;
        if (pending >= 500) await flush();
      }
    }
    await flush();

    final logs = await _db.collection('docLogs').get();
    for (final doc in logs.docs) {
      final stamped = nativeOf(doc.data()['timestamp']);
      if (stamped == null) continue;
      batch.update(doc.reference, {'timestamp': stamped});
      pending++;
      counts['docLogs'] = counts['docLogs']! + 1;
      if (pending >= 500) await flush();
    }
    await flush();

    return counts;
  }

  // ── Subject-name vocabulary ──────────────────────────────────────────
  /// Shared subject-name list behind the DMC subject autocomplete: every
  /// name ever saved on any DMC. Read once per detail screen; extended on
  /// every save via [rememberSubjectNames].
  ///
  /// The first call seeds it by scanning all students once, so historical
  /// names are suggested from day one. Later calls are a single small doc
  /// read.
  Future<List<String>> fetchSubjectNames() async {
    final ref = _db.collection('meta').doc('subjectNames');
    final snap = await ref.get();
    final known = (snap.data()?['names'] as List? ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (known.isNotEmpty) {
      known.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return known;
    }
    final students = await _db.collection(_students).get();
    final seeded = <String>{};
    for (final d in students.docs) {
      for (final rec in StudentDocRecord.recordsOf(d.data()).values) {
        for (final s in rec.subjects) {
          final name = s.subject.trim();
          if (name.isNotEmpty) seeded.add(name);
        }
      }
    }
    final list = seeded.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (list.isNotEmpty) {
      await ref.set({'names': list}, SetOptions(merge: true));
    }
    return list;
  }

  /// Adds any unfamiliar subject names to the shared vocabulary so the
  /// next DMC suggests them. Best-effort: never throws.
  Future<void> rememberSubjectNames(List<String> names) async {
    final fresh = names
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (fresh.isEmpty) return;
    try {
      await _db.collection('meta').doc('subjectNames').set(
        {'names': FieldValue.arrayUnion(fresh)},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('rememberSubjectNames failed: $e');
    }
  }

  // ── Batch reads ──────────────────────────────────────────────────────────
  /// One batch: students of [group] + [course] + [year]. Any of
  /// [course]/[year] may be null to skip that filter. Sorted by student ID
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
    list.sort(_compareByStudentId);
    return list;
  }

  /// Student-ID order: numeric when both IDs parse as numbers (so "2"
  /// comes before "10"), plain string order otherwise. Empty IDs sort last.
  static int _compareByStudentId(DocBatchEntry a, DocBatchEntry b) {
    final ai = a.studentId.trim();
    final bi = b.studentId.trim();
    if (ai.isEmpty && bi.isEmpty) return 0;
    if (ai.isEmpty) return 1;
    if (bi.isEmpty) return -1;
    final an = int.tryParse(ai);
    final bn = int.tryParse(bi);
    if (an != null && bn != null) return an.compareTo(bn);
    return ai.toLowerCase().compareTo(bi.toLowerCase());
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
