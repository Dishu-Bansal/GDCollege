/// Aggregated activity counts for a single calendar day.
class HomeAnalytics {
  /// Start of the analytics day (00:00 IST).
  final DateTime day;

  // Students
  final int studentsCreated;
  final int studentsUpdated;
  final int studentsDeleted;

  // Staff
  final int staffCreated;
  final int staffUpdated;
  final int staffDeleted;

  // Stock
  final int inspectionsDone;
  final int itemsAdded;
  final int itemsRemoved;
  final int assignmentsDone;

  const HomeAnalytics({
    required this.day,
    this.studentsCreated = 0,
    this.studentsUpdated = 0,
    this.studentsDeleted = 0,
    this.staffCreated = 0,
    this.staffUpdated = 0,
    this.staffDeleted = 0,
    this.inspectionsDone = 0,
    this.itemsAdded = 0,
    this.itemsRemoved = 0,
    this.assignmentsDone = 0,
  });

  int get studentEvents =>
      studentsCreated + studentsUpdated + studentsDeleted;

  int get staffEvents => staffCreated + staffUpdated + staffDeleted;

  bool get hasAnyActivity =>
      studentEvents > 0 || staffEvents > 0 || inspectionsDone > 0 ||
      itemsAdded > 0 || itemsRemoved > 0 || assignmentsDone > 0;
}
