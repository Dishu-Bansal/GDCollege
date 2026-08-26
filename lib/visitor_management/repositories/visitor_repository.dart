import '../models/visitor_models.dart';

/// Data access for visitor check-ins / check-outs, unique visitor profiles
/// and the global visitor log.
abstract class VisitorRepository {
  /// People currently checked in (no check-out time yet), newest first.
  Stream<List<VisitorVisitModel>> watchInside();

  /// Unique external visitors, most recent visit first.
  Stream<List<VisitorModel>> watchVisitors();

  /// All visits — the global log — newest first.
  Stream<List<VisitorVisitModel>> watchAllVisits();

  /// All visits of a single visitor, newest first (visitor detail screen).
  Stream<List<VisitorVisitModel>> watchVisitorVisits(String visitorId);

  /// Checks in a staff member or an external visitor, stamping the current
  /// time as the check-in time. For visitors, the unique visitor doc is
  /// reused when the name matches an earlier visitor (case-insensitive),
  /// otherwise a new one is created.
  Future<void> checkIn({
    required bool isStaff,
    required String? staffId,
    required String name,
    required String vehicleNumber,
    required String purpose,
    required String fromPlace,
    required List<String> accompanyingPeople,
  });

  /// Checks out an open visit, stamping the current time as the check-out
  /// time.
  Future<void> checkOut(String visitId);
}
