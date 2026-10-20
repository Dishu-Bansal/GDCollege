import 'student_model.dart';

/// Every label missingStudentDocuments() can emit, in chip display order.
/// Used by the list's per-document filter chips.
const kMissingDocLabels = [
  'Aadhar Number',
  'Aadhar Card',
  'PAN Number',
  'PAN Card',
  '10th',
  '12th',
  'SC Certificate',
  'BC Certificate',
  'Family ID',
  'Haryana Residence',
  'ABC ID Number',
];

/// Document-completeness checks shared by the student list (row alerts +
/// "Missing documents" filter), the Helper audit and the Helper backfill.
///
/// Rules:
/// 1) Aadhar: number **and** file, only for students admitted in 2016 or
///    later (Aadhar was rolled out in 2016). Students with no admission year
///    are treated as not applicable.
/// 2) PAN: number **and** file for every student.
/// 3) 10th and 12th files for every student.
/// 4) caste SC: SC Certificate; caste BC (form stores OBC): BC Certificate.
/// 5) state Haryana: Family ID number and Haryana Residence file.
/// 6) ABC ID number for students admitted in 2024 or later (the ABC/APAAR
///    roll-out year).
///
/// Returns the labels of required-but-missing documents (empty = complete).
/// Missing keys on pre-feature records read as null, so old students simply
/// report their gaps instead of erroring. Saves are not blocked by these
/// rules; they surface as row alerts, filter results and the Helper audit.
List<String> missingStudentDocuments(StudentModel s) {
  bool empty(String? value) => value == null || value.trim().isEmpty;
  final missing = <String>[];
  final year = s.yearOfAdmission;

  // Aadhar became applicable from 2016 admissions onwards; the number and
  // the scanned card are both mandatory.
  if (year != null && year >= 2016) {
    if (empty(s.aadharNumber)) missing.add('Aadhar Number');
    if (empty(s.aadharUrl)) missing.add('Aadhar Card');
  }

  // PAN number + scanned card are mandatory for every student.
  if (empty(s.panCard)) missing.add('PAN Number');
  if (empty(s.panUrl)) missing.add('PAN Card');

  if (empty(s.tenthUrl)) missing.add('10th');
  if (empty(s.twelfthUrl)) missing.add('12th');

  switch (s.caste.trim().toUpperCase()) {
    case 'SC':
      if (empty(s.scCertificateUrl)) missing.add('SC Certificate');
    case 'BC':
    case 'OBC': // form offers OBC; treated as BC for rule 4
      if (empty(s.bcCertificateUrl)) missing.add('BC Certificate');
  }

  if (s.state.trim().toUpperCase() == 'HARYANA') {
    if (empty(s.familyId)) missing.add('Family ID');
    if (empty(s.haryanaResidenceUrl)) {
      missing.add('Haryana Residence');
    }
  }

  // ABC/APAAR ID became applicable from 2024 admissions onwards.
  if (year != null && year >= 2024 && empty(s.abcIdNumber)) {
    missing.add('ABC ID Number');
  }

  return missing;
}
