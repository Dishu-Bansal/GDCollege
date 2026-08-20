import 'dart:typed_data';
import '../staff_management/models/staff_model.dart';
import '../models/audit_log.dart';

abstract class StaffRepository {
  Stream<List<StaffModel>> watchAll();
  Stream<List<StaffModel>> watchNames();

  Future<String> create(StaffModel staff);
  Future<void> update(String id, StaffModel staff, {bool writeLog = true});
  Future<void> delete(String id);

  Future<void> uploadFiles(
    StaffModel staff,
    String staffId, {
    void Function(String label, double progress)? onProgress,
  });

  Future<String?> uploadFile({
    required Uint8List localPath,
    required String storagePath,
    void Function(double progress)? onProgress,
  });

  // ── Logs ──
  Stream<List<AuditLog>> watchStaffLogs(String staffId);
  Stream<List<AuditLog>> watchAllStaffLogs();

  // ── Migration ──
  Future<int> migrateStaffAuditLogs();
}
