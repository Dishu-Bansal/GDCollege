import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../student_management/models/student_model.dart';
import '../repositories/student_repository.dart';
import '../models/audit_log.dart';
import '../models/user_session.dart';

class FirebaseStudentRepository implements StudentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _collection = 'students';

  // ── Audit log helpers ──────────────────────────────────────────────────────

  CollectionReference _studentLogs(String studentId) =>
      _firestore.collection('students').doc(studentId).collection('studentLogs');

  Future<void> _writeLog(String studentId, String studentName, String action, String detail) async {
    await _studentLogs(studentId).add(AuditLog(
      personId: studentId,
      personName: studentName,
      action: action,
      changedBy: UserSession().currentUser?.email ?? '',
      detail: detail,
    ).toFirestore());
  }

  // ── N-gram index builder ──────────────────────────────────────────────────

  Set<String> _generateNGrams(String text) {
    final result = <String>{};
    final clean = text.toLowerCase().trim();
    if (clean.isEmpty) return result;
    for (int i = 0; i < clean.length; i++) {
      for (int j = i + 1; j <= clean.length; j++) {
        result.add(clean.substring(i, j));
      }
    }
    return result;
  }

  Map<String, bool> _buildSearchIndex(StudentModel student) {
    final ngrams = <String>{};
    ngrams.addAll(_generateNGrams(student.name));
    ngrams.addAll(_generateNGrams(student.studentId));
    ngrams.addAll(_generateNGrams(student.fatherName));
    ngrams.addAll(_generateNGrams(student.mobileNo1));
    return {for (final g in ngrams) g: true};
  }

  // ── Count helpers ─────────────────────────────────────────────────────────

  Future<void> _incrementCount() async {
    await _firestore.collection('_meta').doc('students').set(
        {'count': FieldValue.increment(1)}, SetOptions(merge: true));
  }

  Future<void> _decrementCount() async {
    await _firestore.collection('_meta').doc('students').set(
        {'count': FieldValue.increment(-1)}, SetOptions(merge: true));
  }

  @override
  Stream<int> watchTotalCount() {
    return _firestore
        .collection('_meta')
        .doc('students')
        .snapshots()
        .map((s) => (s.data()?['count'] ?? 0) as int);
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  @override
  Future<String> create(StudentModel student) async {
    final now = DateTime.now();
    student.createdAt = now;
    student.updatedAt = now;
    final data = student.toFirestore();
    data['_searchIndex'] = _buildSearchIndex(student);
    final docRef = await _firestore.collection(_collection).add(data);
    await _incrementCount();
    await _writeLog(docRef.id, student.name, 'create', 'Student created');
    return docRef.id;
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  @override
  Future<void> update(String docId, StudentModel student) async {
    // Fetch old data before writing, for audit comparison
    final oldSnap = await _firestore.collection(_collection).doc(docId).get();
    final oldData = (oldSnap.data() as Map<String, dynamic>?) ?? {};

    student.updatedAt = DateTime.now();
    student.documentVersion += 1;
    final data = student.toFirestore();
    data['_searchIndex'] = _buildSearchIndex(student);
    await _firestore.collection(_collection).doc(docId).update(data);

    final detail = _buildUpdateDetail(oldData, data);
    await _writeLog(docId, student.name, 'update', detail);
  }

  static const _fieldLabels = {
    'name': 'Name', 'fatherName': 'Father', 'motherName': 'Mother',
    'dob': 'DOB', 'gender': 'Gender', 'caste': 'Caste',
    'address': 'Address', 'village': 'Village', 'district': 'District',
    'state': 'State', 'pin': 'PIN', 'mobileNo1': 'Mobile 1', 'mobileNo2': 'Mobile 2',
    'aadharNumber': 'Aadhar', 'panCard': 'PAN', 'familyId': 'Family ID',
    'nameOfCourse': 'Course', 'yearOfAdmission': 'Year',
    'feeDetails1stYear': '1st Year Fee', 'feeDetails2ndYear': '2nd Year Fee',
    'fineIfAny': 'Fine', 'examFee': 'Exam Fee', 'placementDetails': 'Placement',
    'tenthUrl': '10th Cert', 'twelfthUrl': '12th Cert',
    'graduationUrl': 'Graduation', 'postGraduationUrl': 'Post Grad', 'diplomaUrl': 'Diploma',
    'photoUrl': 'Photo', 'aadharUrl': 'Aadhar File', 'panUrl': 'PAN File',
    'scCertificateUrl': 'SC Cert', 'bcCertificateUrl': 'BC Cert', 'sportsCertificateUrl': 'Sports Cert',
  };

  String _buildUpdateDetail(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    final changes = <String>[];
    for (final entry in _fieldLabels.entries) {
      final key = entry.key;
      // Normalize: treat null, '', 0 as equivalent empty values
      final oldVal = oldData[key];
      final newVal = newData[key];
      final oldNorm = (oldVal == null || oldVal == '' || oldVal == 0) ? null : oldVal.toString();
      final newNorm = (newVal == null || newVal == '' || newVal == 0) ? null : newVal.toString();
      if (oldNorm != newNorm) changes.add(entry.value);
    }
    return changes.isEmpty ? 'No changes detected' : 'Updated: ${changes.join(', ')}';
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  @override
  Future<void> delete(String docId) async {
    // Write log before deleting
    final doc = await _firestore.collection(_collection).doc(docId).get();
    final name = (doc.data() as Map<String, dynamic>)?['name'] ?? '';
    await _writeLog(docId, name, 'delete', 'Student deleted');
    await _firestore.collection(_collection).doc(docId).delete();
    await _decrementCount();
  }

  // ── Audit log readers ─────────────────────────────────────────────────────

  @override
  Stream<List<AuditLog>> watchStudentLogs(String studentId) =>
      _studentLogs(studentId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs
              .map((d) => AuditLog.fromFirestore(d.id, d.data() as Map<String, dynamic>))
              .toList());

  @override
  Stream<List<AuditLog>> watchAllStudentLogs() =>
      _firestore.collectionGroup('studentLogs')
          .orderBy('timestamp', descending: true)
          .limit(300)
          .snapshots()
          .map((s) => s.docs
              .map((d) => AuditLog.fromFirestore(d.id, d.data() as Map<String, dynamic>))
              .toList());

  Future<void> migrateExistingStudents() async {
    print('Starting migration...');

    // 1. Get all students
    final snapshot = await _firestore.collection(_collection).get();

    // Using a WriteBatch for better performance and atomicity (max 500 docs per batch)
    WriteBatch batch = _firestore.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();

      // Check if the search index already exists to avoid unnecessary writes
      if (!data.containsKey('_searchIndex')) {
        final student = StudentModel.fromFirestore(doc.id, data);
        await _incrementCount();

        // 2. Generate the index using your existing logic
        final searchIndex = _buildSearchIndex(student);

        // 3. Update the document
        batch.update(doc.reference, {'_searchIndex': searchIndex});
        count++;

        // Firestore batches have a 500-doc limit
        if (count % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
          print('Migrated $count records...');
        }
      }
    }

    // Commit any remaining documents in the last batch
    await batch.commit();
    print('Migration complete. Total records updated: $count');
  }
  // ── BROWSE (no filters) — cursor-based, 20 at a time ─────────────────────

  @override
  Future<({List<StudentModel> students, DocumentSnapshot? lastDoc})> fetchPage({
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(StudentRepository.pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    final students = snap.docs
        .map((d) => StudentModel.fromFirestore(
        d.id, d.data() as Map<String, dynamic>))
        .toList();

    return (
    students: students,
    lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  // ── SEARCH (filters active) — fetch all matches, return full list ─────────
  // We fetch all matching docs and let the controller paginate client-side.
  // With n-gram index this is a single indexed Firestore query.

  @override
  Future<List<StudentModel>> search({
    required String query,
    String? course,
    String? year,
  }) async {
    final clean = query.toLowerCase().trim();

    Query q = _firestore.collection(_collection);

    if (clean.isNotEmpty) {
      q = q.where('_searchIndex.$clean', isEqualTo: true);
    }
    if (course != null && course != 'All' && course.isNotEmpty) {
      q = q.where('nameOfCourse', isEqualTo: course);
    }
    if (year != null && year.isNotEmpty) {
      q = q.where('yearOfAdmission', isEqualTo: int.tryParse(year));
    }

    // If no filter at all somehow reached here, cap at 500 for safety
    if (clean.isEmpty && (course == null || course == 'All') &&
        (year == null || year.isEmpty)) {
      q = q.limit(500);
    }

    final snap = await q.get();
    return snap.docs
        .map((d) => StudentModel.fromFirestore(
        d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  // ─── FILE UPLOAD ─────────────────────────────────────────────────────────
  /// Upload a file to Firebase Storage and return its download URL.
  @override
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
  @override
  Future<void> uploadFiles(
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
