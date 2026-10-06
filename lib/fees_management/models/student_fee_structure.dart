import 'package:gd_college/constants.dart';
import 'package:gd_college/student_management/models/student_model.dart';

/// One named fee head with its total amount, derived from a GD College
/// student record. Mirrors the `FeeEntry` shape of the reference fees
/// module so the same allocation maths applies.
class FeeEntry {
  final String type;
  final double amount;

  const FeeEntry({required this.type, required this.amount});
}

/// Parses a free-text fee-details field ("50000", "₹50,000", …) into
/// rupees. Unparseable/empty values read as 0.
double parseFeeAmount(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return 0;
  return double.tryParse(cleaned) ?? 0;
}

/// Fee heads for a student, in allocation order: 1st Year → 2nd Year →
/// 3rd Year → other fees. Only heads with an amount above zero are kept.
List<FeeEntry> feeEntriesOf(StudentModel s) {
  final entries = <FeeEntry>[
    FeeEntry(type: '1st Year', amount: parseFeeAmount(s.feeDetails1stYear)),
    FeeEntry(type: '2nd Year', amount: parseFeeAmount(s.feeDetails2ndYear)),
    FeeEntry(type: '3rd Year', amount: parseFeeAmount(s.feeDetails3rdYear)),
    for (final f in s.otherFees)
      FeeEntry(
        type: (f['type'] ?? '').trim().isEmpty
            ? 'Other Fee'
            : f['type']!.trim(),
        amount: parseFeeAmount(f['amount'] ?? ''),
      ),
  ];
  return entries.where((e) => e.amount > 0).toList();
}

double totalFeesOf(StudentModel s) =>
    feeEntriesOf(s).fold(0, (sum, e) => sum + e.amount);

/// Human college label ('GD College' / 'MLSN' / 'Skill India') for a
/// student, from the stored group with a by-course fallback for legacy
/// documents.
String collegeLabelOf(StudentModel s) {
  for (final g in StudentGroup.values) {
    if (g.name == s.group) return g.label;
  }
  return studentGroupOfCourse(s.nameOfCourse).label;
}
