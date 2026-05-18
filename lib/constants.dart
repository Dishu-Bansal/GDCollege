import 'dart:ui';

const List<String> listOfCourses = [
  'All', 'B.ED', 'D.ED', 'M.ED', 'D.P.ED', 'ANM', 'GNM', 'DDUGKY 2021', 'SKILLING', 'Other'
];

Color avatarColor(String name) {
  const colors = [
    Color(0xFF1A3C6E), Color(0xFF2E7D32), Color(0xFF6A1B9A),
    Color(0xFF00838F), Color(0xFF558B2F), Color(0xFF4527A0),
    Color(0xFFAD1457), Color(0xFF00695C), Color(0xFF283593),
  ];
  if (name.isEmpty) return colors[0];
  return colors[name.codeUnitAt(0) % colors.length];
}