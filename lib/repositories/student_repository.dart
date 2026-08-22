import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<List<StudentModel>> search({
    required String query,
    Set<String>? years,
    Set<String>? courses,
  });

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
}
