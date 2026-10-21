import 'package:cloud_firestore/cloud_firestore.dart';

// ── Firestore date/time wire formats ─────────────────────────────────────────
//
// Every date and time the app stores in Firestore goes through one of these
// helpers so a value never depends on the writing device's clock zone:
//
//   * [timestampToWire] — an *instant* (createdAt, updatedAt, log times,
//     visit times, …) is written as a UTC ISO-8601 string ending in `Z`.
//   * [dateToWire] — a *calendar date* (date of birth, joining date, bill
//     date, …) is written as `yyyy-MM-dd`; a date has no timezone, so it is
//     stored without one.
//
// Reads go through [parseTimestamp] / [parseDate], which accept every shape
// the collection has accumulated:
//
//   * UTC ISO strings written by current builds (`…Z`),
//   * legacy naive local wall-clock strings (`DateTime.now().toIso8601String()`)
//     that encode no zone at all,
//   * Firestore [Timestamp] values (server-authored fields, imports, and
//     anything written with a raw `DateTime`).
//
// Both readers return local time, so display code, sorting and comparisons
// keep working unchanged regardless of which shape the document holds.

/// Converts a stored instant into local time.
///
/// Accepts Firestore [Timestamp]s, [DateTime]s, and ISO-8601 [String]s. A
/// legacy string without a zone is interpreted as local wall-clock time, which
/// is what those records meant when they were written.
DateTime? parseTimestamp(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toLocal();
  if (value is DateTime) return value.toLocal();
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text)?.toLocal();
}

/// Serialises an instant as an unambiguous UTC ISO-8601 string (`…Z`).
String? timestampToWire(DateTime? value) =>
    value?.toUtc().toIso8601String();

/// Converts a stored calendar date into local time at midnight.
///
/// Accepts `yyyy-MM-dd` (current format), legacy full ISO strings with a time
/// component, [Timestamp]s and [DateTime]s. The time of day is dropped: a
/// calendar date carries no timezone, so only the date is meaningful.
DateTime? parseDate(Object? value) {
  final parsed = parseTimestamp(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Serialises a calendar date as `yyyy-MM-dd`.
String? dateToWire(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-$month-$day';
}

/// Formats a date for display as `dd/MM/yyyy` (the app's date convention).
String formatDay(DateTime? value) {
  if (value == null) return '';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
