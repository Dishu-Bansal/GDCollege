// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:gd_college/constants.dart';
import '../../repositories/student_repository.dart';
import '../models/student_model.dart';

/// One downloadable column: header label + value extractor.
class _DownloadField {
  final String label;
  final String Function(StudentModel s) get;
  const _DownloadField(this.label, this.get);
}

String _fmtDate(DateTime? d) =>
    d == null ? '' : d.toIso8601String().split('T').first;

/// Column groups shown as chip sections in the dialog.
final Map<String, List<_DownloadField>> _downloadFieldGroups = {
  'Personal': [
    _DownloadField('Student ID', (s) => s.studentId),
    _DownloadField('Name', (s) => s.name),
    _DownloadField('Father Name', (s) => s.fatherName),
    _DownloadField('Mother Name', (s) => s.motherName),
    _DownloadField('DOB', (s) => _fmtDate(s.dob)),
    _DownloadField('Gender', (s) => s.gender),
    _DownloadField('Caste', (s) => s.caste),
  ],
  'Contact': [
    _DownloadField('Mobile 1', (s) => s.mobileNo1),
    _DownloadField('Mobile 2', (s) => s.mobileNo2),
    _DownloadField('Aadhar Number', (s) => s.aadharNumber),
    _DownloadField('PAN', (s) => s.panCard),
    _DownloadField('Family ID', (s) => s.familyId),
  ],
  'Address': [
    _DownloadField('Address', (s) => s.address),
    _DownloadField('Village', (s) => s.village),
    _DownloadField('District', (s) => s.district),
    _DownloadField('State', (s) => s.state),
    _DownloadField('PIN', (s) => s.pin),
  ],
  'Course': [
    _DownloadField('Course', (s) => s.nameOfCourse),
    _DownloadField(
        'Admission Year', (s) => s.yearOfAdmission?.toString() ?? ''),
    _DownloadField('1st Year Fee', (s) => s.feeDetails1stYear),
    _DownloadField('2nd Year Fee', (s) => s.feeDetails2ndYear),
    _DownloadField('3rd Year Fee', (s) => s.feeDetails3rdYear),
    _DownloadField('Other Fees',
        (s) => s.otherFees.map((f) => '${f['label']}: ${f['amount']}').join('; ')),
    _DownloadField('Placement', (s) => s.placementDetails),
    _DownloadField('Date Added', (s) => _fmtDate(s.createdAt)),
  ],
  'Document Links': [
    _DownloadField('Photo', (s) => s.photoUrl ?? ''),
    _DownloadField('Aadhar File', (s) => s.aadharUrl ?? ''),
    _DownloadField('PAN File', (s) => s.panUrl ?? ''),
    _DownloadField('10th Cert', (s) => s.tenthUrl ?? ''),
    _DownloadField('12th Cert', (s) => s.twelfthUrl ?? ''),
    _DownloadField('Graduation', (s) => s.graduationUrl ?? ''),
    _DownloadField('Post Graduation', (s) => s.postGraduationUrl ?? ''),
    _DownloadField('Diploma', (s) => s.diplomaUrl ?? ''),
    _DownloadField('SC Cert', (s) => s.scCertificateUrl ?? ''),
    _DownloadField('BC Cert', (s) => s.bcCertificateUrl ?? ''),
    _DownloadField('Sports Cert', (s) => s.sportsCertificateUrl ?? ''),
    _DownloadField('Family ID Doc', (s) => s.familyIdDocUrl ?? ''),
    _DownloadField('Haryana Residence', (s) => s.haryanaResidenceUrl ?? ''),
    _DownloadField('ABC ID', (s) => s.abcIdUrl ?? ''),
    _DownloadField('Other Files', (s) => s.otherFileUrls.join('\n')),
  ],
};

/// Columns pre-selected when the dialog opens.
const Set<String> _defaultDownloadColumns = {
  'Student ID',
  'Name',
  'Father Name',
  'Mother Name',
  'Mobile 1',
  'Mobile 2',
  'Address',
  'Village',
  'District',
  'State',
  'PIN',
  'Course',
  'Admission Year',
};

/// Shows the download popup for [group]: year/course filter chips plus
/// column-picker chips. The selection downloads as an .xlsx file.
Future<void> showStudentDownloadDialog({
  required BuildContext context,
  required StudentGroup group,
  required StudentRepository service,
  required List<String> yearOptions,
  required Set<String> initialYears,
  required List<String> courseOptions,
  required Set<String> initialCourses,
}) {
  return showDialog(
    context: context,
    builder: (_) => _StudentDownloadDialog(
      group: group,
      service: service,
      yearOptions: yearOptions,
      initialYears: Set.of(initialYears),
      courseOptions: courseOptions,
      initialCourses: Set.of(initialCourses),
    ),
  );
}

class _StudentDownloadDialog extends StatefulWidget {
  final StudentGroup group;
  final StudentRepository service;
  final List<String> yearOptions;
  final Set<String> initialYears;
  final List<String> courseOptions;
  final Set<String> initialCourses;

  const _StudentDownloadDialog({
    required this.group,
    required this.service,
    required this.yearOptions,
    required this.initialYears,
    required this.courseOptions,
    required this.initialCourses,
  });

  @override
  State<_StudentDownloadDialog> createState() =>
      _StudentDownloadDialogState();
}

class _StudentDownloadDialogState extends State<_StudentDownloadDialog> {
  late Set<String> _years;
  late Set<String> _courses;
  late Set<String> _columns;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _years = Set.of(widget.initialYears);
    _courses = Set.of(widget.initialCourses);
    _columns = Set.of(_defaultDownloadColumns);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.download_outlined,
                      color: Color(0xFF1A3C6E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Download ${widget.group.label} students',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _downloading
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Students'),
                      if (widget.yearOptions.isNotEmpty) ...[
                        _chipRow(
                          label: 'Admission Year',
                          options: widget.yearOptions,
                          selected: _years,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (widget.courseOptions.isNotEmpty)
                        _chipRow(
                          label: 'Course',
                          options: widget.courseOptions,
                          selected: _courses,
                        ),
                      Text(
                        'Group: ${widget.group.label} (current tab). '
                        'Empty selections mean all.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle('Columns'),
                      for (final entry in _downloadFieldGroups.entries) ...[
                        _chipRow(
                          label: entry.key,
                          options: [
                            for (final f in entry.value) f.label
                          ],
                          selected: _columns,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _downloading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed:
                          (_downloading || _columns.isEmpty) ? null : _download,
                      icon: _downloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.table_view_outlined,
                              size: 18),
                      label: Text(_downloading
                          ? 'Preparing...'
                          : 'Download Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A3C6E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A3C6E),
        ),
      ),
    );
  }

  Widget _chipRow({
    required String label,
    required List<String> options,
    required Set<String> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in options)
              FilterChip(
                label: Text(o, style: const TextStyle(fontSize: 12)),
                selected: selected.contains(o),
                onSelected: _downloading
                    ? null
                    : (_) => setState(() {
                          if (!selected.remove(o)) selected.add(o);
                        }),
                selectedColor:
                    const Color(0xFF1A3C6E).withValues(alpha: 0.15),
                checkmarkColor: const Color(0xFF1A3C6E),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final students = await widget.service.searchInGroup(
        group: widget.group,
        query: '',
        years: _years,
        courses: _courses,
      );
      students.sort((a, b) => a.name.compareTo(b.name));
      final fields = [
        for (final group in _downloadFieldGroups.values)
          for (final f in group)
            if (_columns.contains(f.label)) f,
      ];

      final excel = Excel.createExcel();
      final sheet = excel['Students'];
      for (var c = 0; c < fields.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: c, rowIndex: 0))
            .value = TextCellValue(fields[c].label);
      }
      for (var r = 0; r < students.length; r++) {
        for (var c = 0; c < fields.length; c++) {
          sheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: c, rowIndex: r + 1))
              .value = TextCellValue(fields[c].get(students[r]));
        }
      }

      final bytes = excel.save();
      if (bytes == null) throw StateError('Excel encoding failed');
      final stamp =
          DateTime.now().toIso8601String().split('T').first;
      final filename =
          'students_${widget.group.name}_$stamp.xlsx';
      final blob = html.Blob([
        bytes
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Downloaded ${students.length} student${students.length == 1 ? '' : 's'}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }
}
