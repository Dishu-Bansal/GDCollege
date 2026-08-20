import '../models/home_analytics.dart';

abstract class AnalyticsRepository {
  /// Returns activity counts for the previous calendar day (IST).
  Future<HomeAnalytics> fetchPreviousDayAnalytics();
}
