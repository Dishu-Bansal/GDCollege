import 'dart:typed_data';
import '../bill_management/models/bill_models.dart';

abstract class BillRepository {
  Stream<List<BillModel>> watchBills();

  Stream<List<BillLog>> watchAllBillLogs();

  /// Creates a bill and adds its items to Extras > Pending > Pending.
  Future<String> createBill(
    BillModel bill, {
    Uint8List? photoBytes,
    String? photoName,
  });

  /// Updates a bill record and true-ups only the stock items this bill
  /// previously created in Extras > Pending > Pending.
  Future<void> updateBill(
    BillModel bill, {
    Uint8List? photoBytes,
    String? photoName,
    bool removePhoto = false,
  });

  /// Marks a pending-reimbursement bill as paid.
  Future<void> markBillPaid(String billId);
}
