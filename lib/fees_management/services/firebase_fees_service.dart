import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:gd_college/models/user_session.dart';
import 'package:gd_college/providers.dart';
import 'package:gd_college/student_management/models/student_model.dart';
import '../models/receipt_model.dart';
import '../models/student_fee_structure.dart';
import '../repositories/fees_repository.dart';

class FirebaseFeesService implements FeesRepository {
  FirebaseFirestore get _db => db;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const _students = 'students';
  static const _receipts = 'receipts';
  static const _receiptLogs = 'receiptLogs';

  String get _currentUser => UserSession().currentUser?.email ?? '';

  @override
  Stream<List<ReceiptModel>> watchAllReceipts() {
    return _db
        .collection(_receipts)
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReceiptModel.fromFirestore(d.id, d.data()))
            .toList())
        .handleError((_) => <ReceiptModel>[]);
  }

  @override
  Stream<List<ReceiptLog>> watchAllLogs() {
    return _db
        .collection(_receiptLogs)
        .orderBy('timestamp', descending: true)
        .limit(300)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReceiptLog.fromFirestore(d.id, d.data()))
            .toList())
        .handleError((_) => <ReceiptLog>[]);
  }

  @override
  Future<void> createReceipt({
    required String studentId,
    required double amount,
    required String mode,
    required String receiptNumber,
    String photoUrl = '',
  }) async {
    if (amount <= 0) return;

    // Load the student's fee structure.
    final studentSnap =
        await _db.collection(_students).doc(studentId).get();
    final student = StudentModel.fromFirestore(
        studentId, studentSnap.data() ?? {});
    final fees = feeEntriesOf(student);

    // Sum what has already been paid on each fee type.
    final existing = await _db
        .collection(_receipts)
        .where('studentId', isEqualTo: studentId)
        .get();
    final paidByType = FeesCalc.paidByType(existing.docs
        .map((d) =>
            ReceiptModel.fromFirestore(d.id, d.data()))
        .toList());

    // Allocate the amount across the fee heads in order, only filling the
    // still-pending part of each type.
    var remaining = amount;
    final allocations = <ReceiptAllocation>[];
    for (final fee in fees) {
      if (remaining <= 0) break;
      final pending = (fee.amount - (paidByType[fee.type] ?? 0))
          .clamp(0.0, double.infinity);
      final take = pending < remaining ? pending : remaining;
      if (take > 0) {
        allocations.add(ReceiptAllocation(type: fee.type, amount: take));
        remaining -= take;
      }
    }
    // Anything left over (overpayment) is recorded as an advance.
    if (remaining > 0) {
      allocations.add(ReceiptAllocation(type: 'Advance', amount: remaining));
    }

    final now = DateTime.now();
    await _db.collection(_receipts).add(ReceiptModel(
      receiptNumber: receiptNumber.trim(),
      studentId: studentId,
      studentName: student.name,
      rollNo: student.studentId,
      college: collegeLabelOf(student),
      course: student.nameOfCourse,
      admissionYear: student.yearOfAdmission ?? 0,
      amount: amount,
      mode: mode.trim(),
      photoUrl: photoUrl,
      allocations: allocations,
      createdAt: now,
      createdBy: _currentUser,
    ).toFirestore());

    await _db.collection(_receiptLogs).add(ReceiptLog(
      receiptNumber: receiptNumber.trim(),
      studentName: student.name,
      action: 'create',
      changedBy: _currentUser,
      detail: 'Receipt ${receiptNumber.trim()} for ${student.name} — '
          '₹${amount.toStringAsFixed(0)} ($mode)'
          '${allocations.isNotEmpty ? ' → ${allocations.map((a) => '${a.type}: ${a.amount.toStringAsFixed(0)}').join(', ')}' : ''}',
      timestamp: now,
    ).toFirestore());
  }

  @override
  Future<String> uploadReceiptPhoto(Uint8List bytes, String fileName) async {
    final ref = _storage.ref('receipts/$fileName');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }
}
