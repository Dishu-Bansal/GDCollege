import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories/student_repository.dart';
import 'repositories/staff_repository.dart';
import 'repositories/stock_repository.dart';
import 'services/firebase_student_service.dart';
import 'services/firebase_staff_service.dart';
import 'services/stock_service.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return FirebaseStudentRepository();
});

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return FirebaseStaffRepository();
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return FirebaseStockRepository();
});
