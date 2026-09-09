import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../student_management/models/student_facets.dart';
import '../student_management/models/student_model.dart';
import '../models/audit_log.dart';

abstract class StudentRepository {
  static const int pageSize = 20;

  Stream<int> watchTotalCount();

  Future<String> create(StudentModel student);
  Future<void> update(String id, StudentModel student, {bool writeLog = true});
  Future<void> delete(String id);

  Future<({List<StudentModel> students, DocumentSnapshot? lastDoc})> fetchPage({
    DocumentSnapshot? startAfter,
  });

  /// Fetches every student document at once. Used by the student records
  /// screen, which splits the students into course-group tabs and filters,
  /// sorts and paginates them client-side.
  Future<List<StudentModel>> fetchAllStudents();

  Future<List<StudentModel>> search({
    required String query,
    Set<String>? years,
    Set<String>? courses,
  });

  // ── Group-scoped (one tab) ────────────────────────────────────────────
  // Each student tab queries exactly its own course group server-side, so
  // pages are always full and totals/chips reflect the database, not the
  // loaded pages.

  /// One page of [group]'s students, newest first.
  Future<({List<StudentModel> students, DocumentSnapshot? lastDoc})>
  fetchGroupPage({required StudentGroup group, DocumentSnapshot? startAfter});

  /// Whole-collection search restricted to [group] (n-gram text index plus
  /// chip filters, all equality filters so no composite index is needed).
  Future<List<StudentModel>> searchInGroup({
    required StudentGroup group,
    required String query,
    Set<String>? years,
    Set<String>? courses,
  });

  /// Exact number of [group]'s students in the database (aggregate query).
  Future<int> countGroup(StudentGroup group);

  /// Whole-collection filter options per group (one small meta read).
  Future<StudentFacets> fetchStudentFacets();

  Future<void> uploadFiles(
    StudentModel student,
    String studentId, {
    void Function(String label, double progress)? onProgress,
  });

  Future<String?> uploadFile({
    required Uint8List localPath,
    required String storagePath,
    void Function(double progress)? onProgress,
  });

  // ── Logs ──
  Stream<List<AuditLog>> watchStudentLogs(String studentId);
  Stream<List<AuditLog>> watchAllStudentLogs();

  // ── Migration ──
  Future<int> migrateStudentAuditLogs();

  /// Backfills the denormalized `group` field on student docs that predate
  /// it and rebuilds the `_meta/studentFacets` document. Safe to re-run.
  /// Returns the number of student docs updated.
  Future<int> migrateStudentGroupsAndFacets();
}
