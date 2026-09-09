import '../models/home_analytics.dart';

abstract class AnalyticsRepository {
  /// Returns activity counts for the previous calendar day (IST).
  Future<HomeAnalytics> fetchPreviousDayAnalytics();

  /// Returns activity counts for [istDay] (any calendar day, IST wall-clock).
  ///
  /// Only the year/month/day components are used; the time is ignored.
  Future<HomeAnalytics> fetchDayAnalytics(DateTime istDay);
}
