import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/home_analytics.dart';
import 'bill_management/models/bill_models.dart';
import 'repositories/student_repository.dart';
import 'repositories/staff_repository.dart';
import 'repositories/stock_repository.dart';
import 'repositories/analytics_repository.dart';
import 'repositories/bill_repository.dart';
import 'services/firebase_student_service.dart';
import 'services/firebase_staff_service.dart';
import 'services/stock_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/firebase_bill_service.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return FirebaseStudentRepository();
});

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return FirebaseStaffRepository();
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return FirebaseStockRepository();
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return FirebaseAnalyticsRepository();
});

final homeAnalyticsProvider = FutureProvider<HomeAnalytics>((ref) {
  return ref.read(analyticsRepositoryProvider).fetchPreviousDayAnalytics();
});

final billRepositoryProvider = Provider<BillRepository>((ref) {
  return FirebaseBillRepository(
    stockRepository: ref.read(stockRepositoryProvider),
  );
});

final billsStreamProvider =
    StreamProvider<List<BillModel>>((ref) => ref.watch(billRepositoryProvider).watchBills());

final billLogsStreamProvider = StreamProvider<List<BillLog>>(
    (ref) => ref.watch(billRepositoryProvider).watchAllBillLogs());
