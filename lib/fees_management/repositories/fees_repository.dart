import 'dart:typed_data';

import '../models/receipt_model.dart';
import '../models/student_fee_structure.dart';

abstract class FeesRepository {
  /// All receipts, newest first.
  Stream<List<ReceiptModel>> watchAllReceipts();

  /// Receipt log, newest first.
  Stream<List<ReceiptLog>> watchAllLogs();

  /// Creates a receipt for [studentId]. The amount is allocated across the
  /// student's fee entries in order — 1st Year, then 2nd Year, then 3rd
  /// Year, then other fees — based on what is still pending on each type.
  Future<void> createReceipt({
    required String studentId,
    required double amount,
    required String mode,
    required String receiptNumber,
    String photoUrl,
  });

  /// Uploads a receipt photo and returns its download URL.
  Future<String> uploadReceiptPhoto(Uint8List bytes, String fileName);
}

/// Helpers to compute pending fees from fee entries and receipts.
class FeesCalc {
  /// Total paid per fee type, from the given receipts' allocations.
  static Map<String, double> paidByType(List<ReceiptModel> receipts) {
    final map = <String, double>{};
    for (final r in receipts) {
      for (final a in r.allocations) {
        map[a.type] = (map[a.type] ?? 0) + a.amount;
      }
    }
    return map;
  }

  /// Total amount paid for a student across receipts.
  static double paidTotal(List<ReceiptModel> receipts) =>
      receipts.fold(0, (sum, r) => sum + r.amount);

  /// Pending (due − paid) per fee type for a student.
  static Map<String, double> pendingByType(
      List<FeeEntry> fees, List<ReceiptModel> receipts) {
    final paid = paidByType(receipts);
    final map = <String, double>{};
    for (final f in fees) {
      final pending = (f.amount - (paid[f.type] ?? 0)).clamp(0.0, double.infinity);
      map[f.type] = pending;
    }
    return map;
  }

  /// Total pending for a student.
  static double pendingTotal(List<FeeEntry> fees, List<ReceiptModel> receipts) {
    var total = 0.0;
    pendingByType(fees, receipts).forEach((_, v) => total += v);
    return total;
  }
}
