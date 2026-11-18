import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:gd_college/models/user_session.dart';
import 'package:gd_college/providers.dart';
import 'package:gd_college/student_management/models/student_model.dart';
import '../models/receipt_identity.dart';
import '../models/receipt_model.dart';
import '../models/student_fee_structure.dart';
import '../repositories/fees_repository.dart';

class FirebaseFeesService implements FeesRepository {
  FirebaseFirestore get _db => db;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const _students = 'students';
  static const _receipts = 'receipts';
  static const _receiptLogs = 'receiptLogs';
  static const _counters = 'counters';

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

  /// Creates a receipt for [studentId] with a server-minted identity: a
  /// per-college-per-FY serial (`GD/2026-27/0143`) plus a random 12-digit
  /// verification code that becomes the receipt's doc id.
  ///
  /// Counter bump, code-uniqueness check and all writes happen in ONE
  /// transaction, so serials stay gap-free and codes stay unique even with
  /// two cashiers collecting at once. Returns the minted receipt.
  @override
  Future<ReceiptModel> createReceipt({
    required String studentId,
    required double amount,
    required String mode,
    String photoUrl = '',
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive');

    final now = DateTime.now();
    final finYear = finYearOf(now);

    // Allocation inputs (plain reads — transactions only allow doc gets).
    // Two cashiers collecting for the same student at the same instant
    // could double-fill a head; the serial/code guarantees below are
    // unaffected and any overlap lands in Advance.
    final studentSnap =
        await _db.collection(_students).doc(studentId).get();
    final student = StudentModel.fromFirestore(
        studentId, studentSnap.data() ?? {});
    final college = collegeLabelOf(student);
    final fees = feeEntriesOf(student);
    final existing = await _db
        .collection(_receipts)
        .where('studentId', isEqualTo: studentId)
        .get();
    final paidByType = FeesCalc.paidByType(existing.docs
        .map((d) => ReceiptModel.fromFirestore(d.id, d.data()))
        .toList());

    // Allocate the amount across the fee heads in order, only filling
    // the still-pending part of each type.
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
      allocations
          .add(ReceiptAllocation(type: 'Advance', amount: remaining));
    }

    return _db.runTransaction((tx) async {
      // Mint the serial: bump the per-college-per-FY counter.
      final prefix = serialPrefixOf(college);
      final counterRef =
          _db.collection(_counters).doc('receipts-$prefix-$finYear');
      final counterSnap = await tx.get(counterRef);
      final seq = ((counterSnap.data()?['next'] ?? 0) as num).toInt() + 1;
      tx.set(counterRef, {
        'next': seq,
        'updatedAt': now.toIso8601String(),
        'updatedBy': _currentUser,
      });
      final serial = formatSerial(prefix, finYear, seq);

      // Mint the code: the receipt doc id itself, so creation IS the
      // uniqueness check. Regenerate on the (near-impossible) collision.
      var code = generateReceiptCode();
      for (var attempt = 0; attempt < 5; attempt++) {
        final probe = await tx.get(_db.collection(_receipts).doc(code));
        if (!probe.exists) break;
        code = generateReceiptCode();
      }

      final receipt = ReceiptModel(
        id: code,
        receiptNumber: serial,
        code: code,
        finYear: finYear,
        status: 'active',
        studentId: studentId,
        studentName: student.name,
        rollNo: student.studentId,
        fatherName: student.fatherName,
        aadharNumber: student.aadharNumber,
        college: college,
        course: student.nameOfCourse,
        admissionYear: student.yearOfAdmission ?? 0,
        amount: amount,
        mode: mode.trim(),
        photoUrl: photoUrl,
        allocations: allocations,
        createdAt: now,
        createdBy: _currentUser,
      );
      tx.set(
          _db.collection(_receipts).doc(code), receipt.toFirestore());
      tx.set(
          _db.collection(_receiptLogs).doc(),
          ReceiptLog(
            receiptNumber: serial,
            studentName: student.name,
            action: 'create',
            changedBy: _currentUser,
            detail: 'Receipt $serial (code $code) for ${student.name} — '
                '₹${amount.toStringAsFixed(0)} ($mode)'
                '${allocations.isNotEmpty ? ' → ${allocations.map((a) => '${a.type}: ${a.amount.toStringAsFixed(0)}').join(', ')}' : ''}',
            timestamp: now,
          ).toFirestore());
      return receipt;
    });
  }

  @override
  Future<String> uploadReceiptPhoto(Uint8List bytes, String fileName) async {
    final ref = _storage.ref('receipts/$fileName');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }
}
