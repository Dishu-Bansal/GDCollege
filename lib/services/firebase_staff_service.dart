import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../staff_management/models/staff_model.dart';
import '../repositories/staff_repository.dart';
import '../models/audit_log.dart';
import '../models/user_session.dart';

class FirebaseStaffRepository implements StaffRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _collection = 'staff';

  // ── Audit log helpers ──────────────────────────────────────────────────────

  CollectionReference _staffLogs(String staffId) =>
      _firestore.collection('staff').doc(staffId).collection('staffLogs');

  Future<void> _writeLog(String staffId, String staffName, String action, String detail) async {
    await _staffLogs(staffId).add(AuditLog(
      personId: staffId,
      personName: staffName,
      action: action,
      changedBy: UserSession().currentUser?.email ?? '',
      detail: detail,
    ).toFirestore());
  }

  // ─── CREATE ──────────────────────────────────────────────────────────────

  @override
  Future<String> create(StaffModel staff) async {
    final now = DateTime.now();
    staff.createdAt = now;
    staff.updatedAt = now;
    final docRef =
    await _firestore.collection(_collection).add(staff.toFirestore());
    final createDetail = 'Created: ${staff.name}, ${staff.designation ?? '—'}';
    await _writeLog(docRef.id, staff.name, 'create', createDetail);
    return docRef.id;
  }

  // ─── UPDATE ──────────────────────────────────────────────────────────────

  @override
  Future<void> update(String docId, StaffModel staff) async {
    // Fetch old data before writing, for audit comparison
    final oldSnap = await _firestore.collection(_collection).doc(docId).get();
    final oldData = (oldSnap.data() as Map<String, dynamic>?) ?? {};

    staff.updatedAt = DateTime.now();
    staff.documentVersion += 1;
    final data = staff.toFirestore();
    await _firestore.collection(_collection).doc(docId).update(data);

    final detail = _buildUpdateDetail(oldData, data);
    await _writeLog(docId, staff.name, 'update', detail);
  }

  static const _fieldLabels = {
    'name': 'Name', 'fatherName': 'Father', 'motherName': 'Mother',
    'dob': 'DOB', 'gender': 'Gender', 'caste': 'Caste',
    'address': 'Address', 'village': 'Village', 'district': 'District',
    'state': 'State', 'pin': 'PIN', 'mobileNo1': 'Mobile 1', 'mobileNo2': 'Mobile 2',
    'aadharNumber': 'Aadhar', 'panCard': 'PAN', 'familyId': 'Family ID',
    'designation': 'Designation', 'course': 'Course', 'salary': 'Salary',
    'dateOfJoining': 'Joining Date', 'dateOfRelieving': 'Relieving Date',
    'tenthUrl': '10th Cert', 'twelfthUrl': '12th Cert',
    'graduationUrl': 'Graduation', 'postGraduationUrl': 'Post Grad', 'diplomaUrl': 'Diploma',
    'netUrl': 'NET', 'phdUrl': 'PhD',
    'photoUrl': 'Photo', 'aadharUrl': 'Aadhar File', 'panUrl': 'PAN File',
    'scCertificateUrl': 'SC Cert', 'bcCertificateUrl': 'BC Cert', 'sportsCertificateUrl': 'Sports Cert',
    'appointmentLetterUrl': 'Appt Letter', 'joiningLetterUrl': 'Joining Letter',
    'universityApprovalUrl': 'Univ Approval', 'resignationLetterUrl': 'Resignation Letter',
  };

  String _buildUpdateDetail(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    final changes = <String>[];
    for (final entry in _fieldLabels.entries) {
      final key = entry.key;
      final oldVal = oldData[key];
      final newVal = newData[key];
      final oldNorm = (oldVal == null || oldVal == '' || oldVal == 0) ? null : oldVal.toString();
      final newNorm = (newVal == null || newVal == '' || newVal == 0) ? null : newVal.toString();
      if (oldNorm != newNorm) changes.add(entry.value);
    }
    return changes.isEmpty ? 'No changes detected' : 'Updated: ${changes.join(', ')}';
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────

  @override
  Future<void> delete(String docId) async {
    // Write log before deleting
    final doc = await _firestore.collection(_collection).doc(docId).get();
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final name = data['name'] ?? '';
    final designation = data['designation'] ?? '';
    final deleteDetail = 'Deleted: $name, ${designation.isNotEmpty ? designation : '—'}';
    await _writeLog(docId, name, 'delete', deleteDetail);
    await _firestore.collection(_collection).doc(docId).delete();
  }

  // ── Audit log readers ─────────────────────────────────────────────────────

  @override
  Stream<List<AuditLog>> watchStaffLogs(String staffId) =>
      _staffLogs(staffId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs
              .map((d) => AuditLog.fromFirestore(d.id, d.data() as Map<String, dynamic>))
              .toList())
          .handleError((_) => <AuditLog>[]);

  @override
  Stream<List<AuditLog>> watchAllStaffLogs() =>
      _firestore.collectionGroup('staffLogs')
          .orderBy('timestamp', descending: true)
          .limit(300)
          .snapshots()
          .map((s) => s.docs
              .map((d) => AuditLog.fromFirestore(d.id, d.data() as Map<String, dynamic>))
              .toList())
          .handleError((_) => <AuditLog>[]);

  // ─── READ (stream) ───────────────────────────────────────────────────────

  @override
  Stream<List<StaffModel>> watchAll() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => StaffModel.fromFirestore(
        d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  @override
  Stream<List<StaffModel>> watchNames() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => StaffModel.fromFirestore(
        d.id, d.data() as Map<String, dynamic>))
        .toList());
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

  /// Upload all pending files for a staff and populate URL fields.
  @override
  Future<void> uploadFiles(
    StaffModel staff,
    String staffId, {
    void Function(String label, double progress)? onProgress,
  }) async {
    final base = 'staff/$staffId';

    if (staff.photoData != null) {
      onProgress?.call('Photo', 0);
      staff.photoUrl = await uploadFile(
        localPath: staff.photoData!,
        storagePath: '$base/photo${_ext(staff.photoName!)}',
        onProgress: (p) => onProgress?.call('Photo', p),
      );
    }

    if (staff.aadharData != null) {
      onProgress?.call('Aadhar', 0);
      staff.aadharUrl = await uploadFile(
        localPath: staff.aadharData!,
        storagePath: '$base/aadhar${_ext(staff.aadharName!)}',
        onProgress: (p) => onProgress?.call('Aadhar', p),
      );
    }

    if (staff.panData != null) {
      onProgress?.call('PAN', 0);
      staff.panUrl = await uploadFile(
        localPath: staff.panData!,
        storagePath: '$base/pan${_ext(staff.panName!)}',
        onProgress: (p) => onProgress?.call('PAN', p),
      );
    }

    if (staff.tenthData != null) {
      onProgress?.call('10th', 0);
      staff.tenthUrl = await uploadFile(
        localPath: staff.tenthData!,
        storagePath: '$base/tenth${_ext(staff.tenthName!)}',
        onProgress: (p) => onProgress?.call('10th', p),
      );
    }

    if (staff.twelfthData != null) {
      onProgress?.call('12th', 0);
      staff.twelfthUrl = await uploadFile(
        localPath: staff.twelfthData!,
        storagePath: '$base/twelfth${_ext(staff.twelfthName!)}',
        onProgress: (p) => onProgress?.call('12th', p),
      );
    }

    if (staff.graduationData != null) {
      onProgress?.call('Graduation', 0);
      staff.graduationUrl = await uploadFile(
        localPath: staff.graduationData!,
        storagePath: '$base/graduation${_ext(staff.graduationName!)}',
        onProgress: (p) => onProgress?.call('Graduation', p),
      );
    }

    if (staff.postGraduationData != null) {
      onProgress?.call('Post Graduation', 0);
      staff.postGraduationUrl = await uploadFile(
        localPath: staff.postGraduationData!,
        storagePath: '$base/postgraduation${_ext(staff.postGraduationName!)}',
        onProgress: (p) => onProgress?.call('Post Graduation', p),
      );
    }

    if (staff.diplomaData != null) {
      onProgress?.call('Diploma', 0);
      staff.diplomaUrl = await uploadFile(
        localPath: staff.diplomaData!,
        storagePath: '$base/diploma${_ext(staff.diplomaName!)}',
        onProgress: (p) => onProgress?.call('Diploma', p),
      );
    }

    if (staff.scCertificateData != null) {
      staff.scCertificateUrl = await uploadFile(
        localPath: staff.scCertificateData!,
        storagePath: '$base/sc_certificate${_ext(staff.scCertificateName!)}',
        onProgress: (p) => onProgress?.call('SC Certificate', p),
      );
    }

    if (staff.bcCertificateData != null) {
      staff.bcCertificateUrl = await uploadFile(
        localPath: staff.bcCertificateData!,
        storagePath: '$base/bc_certificate${_ext(staff.bcCertificateName!)}',
        onProgress: (p) => onProgress?.call('BC Certificate', p),
      );
    }

    if (staff.netData != null) {
      staff.netUrl = await uploadFile(
        localPath: staff.netData!,
        storagePath:
            '$base/net_certificate${_ext(staff.netName!)}',
        onProgress: (p) => onProgress?.call('NET Certificate', p),
      );
    }

    if (staff.phdData != null) {
      staff.phdUrl = await uploadFile(
        localPath: staff.phdData!,
        storagePath:
        '$base/PHD_certificate${_ext(staff.phdName!)}',
        onProgress: (p) => onProgress?.call('PHD Certificate', p),
      );
    }

    final urls = <String>[];
    for (int i = 0; i < staff.experienceCertificateData.length; i++) {
      final path = staff.experienceCertificateData[i];
      final url = await uploadFile(
        localPath: path,
        storagePath: '$base/experience/${staff.experienceCertificatesNames[i]}',
        onProgress: (p) => onProgress?.call('${staff.experienceCertificatesNames[i]}', p),
      );
      if (url != null) urls.add(url);
    }
    staff.experienceCertificateUrls = urls;

    final urls2 = <String>[];
    for (int i = 0; i < staff.otherFileData.length; i++) {
      final path = staff.otherFileData[i];
      final url = await uploadFile(
        localPath: path,
        storagePath: '$base/files/${staff.otherFileNames[i]}',
        onProgress: (p) => onProgress?.call('${staff.otherFileNames[i]}', p),
      );
      if (url != null) urls2.add(url);
    }
    staff.otherFileUrls = urls2;
  }

  String _ext(String path) {
    final idx = path.lastIndexOf('.');
    return idx >= 0 ? path.substring(idx) : '';
  }

  /// Fetch all students (for listing / search).
  // Stream<QuerySnapshot> studentsStream() =>
  //     _firestore.collection(_collection).orderBy('createdAt', descending: true).snapshots();
}
