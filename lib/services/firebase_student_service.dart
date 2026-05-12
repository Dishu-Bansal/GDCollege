import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../student_management/models/student_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _collection = 'students';

  // ─── CREATE ──────────────────────────────────────────────────────────────

  Future<String> saveStudent(StudentModel student) async {
    final now = DateTime.now();
    student.createdAt = now;
    student.updatedAt = now;
    final docRef =
    await _firestore.collection(_collection).add(student.toFirestore());
    return docRef.id;
  }

  // ─── UPDATE ──────────────────────────────────────────────────────────────

  Future<void> updateStudent(String docId, StudentModel student) async {
    student.updatedAt = DateTime.now();
    student.documentVersion += 1;
    await _firestore
        .collection(_collection)
        .doc(docId)
        .update(student.toFirestore());
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────

  Future<void> deleteStudent(String docId) async {
    await _firestore.collection(_collection).doc(docId).delete();
  }

  // ─── READ (stream) ───────────────────────────────────────────────────────

  static const int pageSize = 20;

  Future<({List<StudentModel> students, DocumentSnapshot? lastDoc})> fetchStudentsPage({
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    final students = snap.docs
        .map((d) => StudentModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
        .toList();

    return (
    students: students,
    lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  Stream<List<StudentModel>> studentsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => StudentModel.fromFirestore(
        d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  // ─── FILE UPLOAD ─────────────────────────────────────────────────────────
  /// Upload a file to Firebase Storage and return its download URL.
  Future<String?> uploadFile({
    required Uint8List localPath,
    required String storagePath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final file = File.fromRawPath(localPath);
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putData(localPath);

      uploadTask.snapshotEvents.listen((snap) {
        if (onProgress != null) {
          final progress = snap.bytesTransferred / snap.totalBytes;
          onProgress(progress);
        }
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  /// Save a student record to Firestore. Returns the document ID.
  // Future<String> saveStudent(StudentModel student) async {
  //   final now = DateTime.now();
  //   student.createdAt = now;
  //   student.updatedAt = now;
  //
  //   final docRef = await _firestore
  //       .collection(_collection)
  //       .add(student.toFirestore());
  //   return docRef.id;
  // }

  /// Update an existing student document.
  // Future<void> updateStudent(String docId, StudentModel student) async {
  //   student.updatedAt = DateTime.now();
  //   student.documentVersion += 1;
  //   await _firestore
  //       .collection(_collection)
  //       .doc(docId)
  //       .update(student.toFirestore());
  // }

  /// Upload all pending files for a student and populate URL fields.
  Future<void> uploadStudentFiles(
    StudentModel student,
    String studentId, {
    void Function(String label, double progress)? onProgress,
  }) async {
    final base = 'students/$studentId';

    if (student.photoData != null) {
      onProgress?.call('Photo', 0);
      student.photoUrl = await uploadFile(
        localPath: student.photoData!,
        storagePath: '$base/photo${_ext(student.photoName!)}',
        onProgress: (p) => onProgress?.call('Photo', p),
      );
    }

    if (student.aadharData != null) {
      onProgress?.call('Aadhar', 0);
      student.aadharUrl = await uploadFile(
        localPath: student.aadharData!,
        storagePath: '$base/aadhar${_ext(student.aadharName!)}',
        onProgress: (p) => onProgress?.call('Aadhar', p),
      );
    }

    if (student.panData != null) {
      onProgress?.call('PAN', 0);
      student.panUrl = await uploadFile(
        localPath: student.panData!,
        storagePath: '$base/pan${_ext(student.panName!)}',
        onProgress: (p) => onProgress?.call('PAN', p),
      );
    }

    if (student.tenthData != null) {
      onProgress?.call('10th', 0);
      student.tenthUrl = await uploadFile(
        localPath: student.tenthData!,
        storagePath: '$base/tenth${_ext(student.tenthName!)}',
        onProgress: (p) => onProgress?.call('10th', p),
      );
    }

    if (student.twelfthData != null) {
      onProgress?.call('12th', 0);
      student.twelfthUrl = await uploadFile(
        localPath: student.twelfthData!,
        storagePath: '$base/twelfth${_ext(student.twelfthName!)}',
        onProgress: (p) => onProgress?.call('12th', p),
      );
    }

    if (student.graduationData != null) {
      onProgress?.call('Graduation', 0);
      student.graduationUrl = await uploadFile(
        localPath: student.graduationData!,
        storagePath: '$base/graduation${_ext(student.graduationName!)}',
        onProgress: (p) => onProgress?.call('Graduation', p),
      );
    }

    if (student.postGraduationData != null) {
      onProgress?.call('Post Graduation', 0);
      student.postGraduationUrl = await uploadFile(
        localPath: student.postGraduationData!,
        storagePath: '$base/postgraduation${_ext(student.postGraduationName!)}',
        onProgress: (p) => onProgress?.call('Post Graduation', p),
      );
    }

    if (student.diplomaData != null) {
      onProgress?.call('Diploma', 0);
      student.diplomaUrl = await uploadFile(
        localPath: student.diplomaData!,
        storagePath: '$base/diploma${_ext(student.diplomaName!)}',
        onProgress: (p) => onProgress?.call('Diploma', p),
      );
    }

    if (student.scCertificateData != null) {
      student.scCertificateUrl = await uploadFile(
        localPath: student.scCertificateData!,
        storagePath: '$base/sc_certificate${_ext(student.scCertificateName!)}',
        onProgress: (p) => onProgress?.call('SC Certificate', p),
      );
    }

    if (student.bcCertificateData != null) {
      student.bcCertificateUrl = await uploadFile(
        localPath: student.bcCertificateData!,
        storagePath: '$base/bc_certificate${_ext(student.bcCertificateName!)}',
        onProgress: (p) => onProgress?.call('BC Certificate', p),
      );
    }

    if (student.sportsCertificateData != null) {
      student.sportsCertificateUrl = await uploadFile(
        localPath: student.sportsCertificateData!,
        storagePath:
            '$base/sports_certificate${_ext(student.sportsCertificateName!)}',
        onProgress: (p) => onProgress?.call('Sports Certificate', p),
      );
    }

    final urls = <String>[];
    for (int i = 0; i < student.otherFileData.length; i++) {
      final path = student.otherFileData[i];
      final url = await uploadFile(
        localPath: path,
        storagePath: '$base/files/${student.otherFileNames[i]}',
        onProgress: (p) => onProgress?.call('${student.otherFileNames[i]}', p),
      );
      if (url != null) urls.add(url);
    }
    student.otherFileUrls = urls;
  }

  String _ext(String path) {
    final idx = path.lastIndexOf('.');
    return idx >= 0 ? path.substring(idx) : '';
  }

  /// Fetch all students (for listing / search).
  // Stream<QuerySnapshot> studentsStream() =>
  //     _firestore.collection(_collection).orderBy('createdAt', descending: true).snapshots();
}
