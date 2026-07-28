import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../student_management/models/student_model.dart';

abstract class StudentRepository {
  static const int pageSize = 20;

  Stream<int> watchTotalCount();

  Future<String> create(StudentModel student);
  Future<void> update(String id, StudentModel student);
  Future<void> delete(String id);

  Future<({List<StudentModel> students, DocumentSnapshot? lastDoc})> fetchPage({
    DocumentSnapshot? startAfter,
  });

  Future<List<StudentModel>> search({
    required String query,
    String? course,
    String? year,
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
}
