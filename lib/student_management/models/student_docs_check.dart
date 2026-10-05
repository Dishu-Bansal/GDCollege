import 'student_model.dart';

/// Every label missingStudentDocuments() can emit, in chip display order.
/// Used by the list's per-document filter chips.
const kMissingDocLabels = [
  'Aadhar Number',
  '10th',
  '12th',
  'SC Certificate',
  'BC Certificate',
  'Family ID',
  'Haryana Residence',
  'ABC ID Number',
];

/// Document-completeness checks shared by the student list (row alerts +
/// "Missing documents" filter) and the Helper audit.
///
/// Rules:
/// 1) every student: Aadhar Card, 10th, 12th;
/// 2) caste SC: SC Certificate;
/// 3) caste BC (form stores OBC): BC Certificate;
/// 4) state Haryana: Family ID, Haryana Residence, ABC ID.
///
/// ID rules (Aadhar, Family ID, ABC ID) are satisfied by the typed number,
/// not the uploaded file: the number is the must-have, the scan is
/// optional. Certificate rules (10th, 12th, SC, BC, Haryana Residence)
/// have no number field, so they still require the file.
///
/// Returns the labels of required-but-missing documents (empty = complete).
/// Missing keys on pre-feature records read as null, so old students simply
/// report their gaps instead of erroring. Creation/editing is never blocked
/// — failures surface as row alerts and filter results only.
List<String> missingStudentDocuments(StudentModel s) {
  bool empty(String? url) => url == null || url.isEmpty;
  bool blank(String? text) => text == null || text.trim().isEmpty;
  final missing = <String>[];

  if (blank(s.aadharNumber)) missing.add('Aadhar Number');
  if (empty(s.tenthUrl)) missing.add('10th');
  if (empty(s.twelfthUrl)) missing.add('12th');

  switch (s.caste.trim().toUpperCase()) {
    case 'SC':
      if (empty(s.scCertificateUrl)) missing.add('SC Certificate');
    case 'BC':
    case 'OBC': // form offers OBC; treated as BC for rule 3
      if (empty(s.bcCertificateUrl)) missing.add('BC Certificate');
  }

  if (s.state.trim().toUpperCase() == 'HARYANA') {
    if (blank(s.familyId)) missing.add('Family ID');
    if (empty(s.haryanaResidenceUrl)) {
      missing.add('Haryana Residence');
    }
    if (blank(s.abcIdNumber)) missing.add('ABC ID Number');
  }

  return missing;
}
