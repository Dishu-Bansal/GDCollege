/// Whole-collection filter options for the student tabs, read from the
/// consolidated `_meta/students` document (one small read for totals +
/// chips) instead of deriving them from whatever page happens to be loaded.
///
/// Document shape in Firestore (written only by the syncStudentMeta Cloud
/// Function):
/// ```json
/// { "count": 412,
///   "countByGroup": {"gdCollege": 120, "mlsn": 52, "skillIndia": 240},
///   "facets": {
///     "gdCollege":  { "years": [2025, 2024], "courses": ["B.ED"] },
///     "mlsn":       { "years": [...],       "courses": [...] },
///     "skillIndia": { "years": [...],       "courses": [...] } } }
/// ```
class StudentFacets {
  /// Admission years per group name ([StudentGroup.name]), newest first.
  final Map<String, List<int>> years;

  /// Courses per group name ([StudentGroup.name]).
  final Map<String, List<String>> courses;

  const StudentFacets({
    this.years = const {},
    this.courses = const {},
  });

  static const empty = StudentFacets();

  List<int> yearsOf(String group) => years[group] ?? const [];

  List<String> coursesOf(String group) => courses[group] ?? const [];

  factory StudentFacets.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return empty;
    // Current shape nests under `facets`; the pre-consolidation `groups`
    // shape is accepted too for backward compatibility.
    final groups = data['facets'] ?? data['groups'];
    if (groups is! Map) return empty;
    final years = <String, List<int>>{};
    final courses = <String, List<String>>{};
    for (final entry in (groups as Map).entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is! Map) continue;
      final rawYears = value['years'];
      if (rawYears is List) {
        final parsed =
            rawYears.whereType<num>().map((y) => y.toInt()).toSet().toList()
              ..sort((a, b) => b.compareTo(a));
        if (parsed.isNotEmpty) years[key] = parsed;
      }
      final rawCourses = value['courses'];
      if (rawCourses is List) {
        final parsed =
            rawCourses
                .map((c) => c.toString().trim())
                .where((c) => c.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        if (parsed.isNotEmpty) courses[key] = parsed;
      }
    }
    return StudentFacets(years: years, courses: courses);
  }
}
