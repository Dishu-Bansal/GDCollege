import 'dart:math';

/// Receipt identity: a human display serial plus an unguessable
/// verification code.
///
/// - Serial: per college per financial year, e.g. `GD/2026-27/0143`.
///   The FY follows April–March of the *payment* date, whatever the
///   student's admission year. Counters restart at 1 every April.
/// - Code: a random 12-digit number, the Firestore doc id of the receipt.
///   It is what the QR encodes and the public verify page asks for.
class ReceiptIdentity {
  final String serial;
  final String code;

  const ReceiptIdentity({required this.serial, required this.code});
}

/// Financial-year label (`2026-27`) for [date]: April–March.
String finYearOf(DateTime date) {
  final y = date.year;
  final start = date.month >= 4 ? y : y - 1;
  final end2 = ((start + 1) % 100).toString().padLeft(2, '0');
  return '$start-$end2';
}

/// Short college prefix for the serial (`GD`, `MLSN`).
String serialPrefixOf(String college) {
  final c = college.toUpperCase();
  if (c.contains('MLSN')) return 'MLSN';
  if (c.contains('GD')) return 'GD';
  return 'GEN';
}

/// `GD/2026-27/0143` from prefix, FY label and 1-based sequence.
String formatSerial(String prefix, String finYear, int seq) =>
    '$prefix/$finYear/${seq.toString().padLeft(4, '0')}';

/// Random 12-digit code (first digit 1–9 so it never loses a digit).
String generateReceiptCode([Random? random]) {
  final r = random ?? Random.secure();
  final buf = StringBuffer()..write(1 + r.nextInt(9));
  for (var i = 1; i < 12; i++) {
    buf.write(r.nextInt(10));
  }
  return buf.toString();
}
