import 'package:cloud_firestore/cloud_firestore.dart';
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
  /// Merge-writes one slot record. Old students simply gain the
  /// `docRecords.{slotKey}` map — nothing else is touched.
  Future<void> saveRecord({
    required String studentId,
    required String slotKey,
    required StudentDocRecord record,
  }) async {
    record.updatedBy = _by;
    if (record.hasFile &&
        record.collector.name.trim().isNotEmpty &&
        record.collectedAt == null) {
      record.collectedAt = DateTime.now();
    }
    await _db.collection(_students).doc(studentId).update({
      'docRecords.$slotKey': record.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

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
