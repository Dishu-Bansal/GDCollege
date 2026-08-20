import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/home_analytics.dart';
import 'repositories/student_repository.dart';
import 'repositories/staff_repository.dart';
import 'repositories/stock_repository.dart';
import 'repositories/analytics_repository.dart';
import 'services/firebase_student_service.dart';
import 'services/firebase_staff_service.dart';
import 'services/stock_service.dart';
import 'services/firebase_analytics_service.dart';

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
