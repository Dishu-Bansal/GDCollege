import 'dart:ui';

const List<String> listOfCourses = [
  'All', 'B.ED', 'D.ED', 'M.ED', 'D.P.ED', 'ANM', 'GNM', 'DDUGKY 2021', 'SKILLING', 'Other'
];

/// The institute groups the student records are divided into.
enum StudentGroup { gdCollege, mlsn, skillIndia }

extension StudentGroupLabel on StudentGroup {
  String get label {
    switch (this) {
      case StudentGroup.gdCollege:
        return 'GD College';
      case StudentGroup.mlsn:
        return 'MLSN';
      case StudentGroup.skillIndia:
        return 'Skill India';
    }
  }
}

/// Courses belonging to the GD College group.
const Set<String> gdCollegeCourses = {'B.ED', 'D.ED', 'D.P.ED', 'M.ED'};

/// Courses belonging to the MLSN group.
const Set<String> mlsnCourses = {'ANM', 'GNM'};

/// Returns the [StudentGroup] a student's course belongs to. Any course that
/// is neither a GD College nor an MLSN course (Skill India courses such as
/// DDUGKY, SKILLING, Other, or empty/legacy values) falls to Skill India.
StudentGroup studentGroupOfCourse(String course) {
  final c = course.trim().toUpperCase();
  if (gdCollegeCourses.contains(c)) return StudentGroup.gdCollege;
  if (mlsnCourses.contains(c)) return StudentGroup.mlsn;
  return StudentGroup.skillIndia;
}

Color avatarColor(String name) {
  const colors = [
    Color(0xFF1A3C6E), Color(0xFF2E7D32), Color(0xFF6A1B9A),
    Color(0xFF00838F), Color(0xFF558B2F), Color(0xFF4527A0),
    Color(0xFFAD1457), Color(0xFF00695C), Color(0xFF283593),
  ];
  if (name.isEmpty) return colors[0];
  return colors[name.codeUnitAt(0) % colors.length];
}
