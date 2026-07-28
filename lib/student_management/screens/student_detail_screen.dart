import 'package:flutter/material.dart';
import 'package:image_network/image_network.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants.dart';
import '../models/student_model.dart';
import 'student_form_screen.dart';
import '../../repositories/student_repository.dart';

class StudentDetailScreen extends StatelessWidget {
  final StudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(
          student.name.isEmpty ? 'Student Details' : student.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (!student.isLocked)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StudentFormScreen(existingStudent: student),
                  ),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // â”€â”€ Header Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _HeaderCard(student: student),

          const SizedBox(height: 12),

          // â”€â”€ Sections â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _DetailCard(
            title: 'Personal Information',
            icon: Icons.person_outline,
            fields: [
              _Field('Father\'s Name', student.fatherName),
              _Field('Mother\'s Name', student.motherName),
              _Field('Date of Birth',
                  student.dob != null
                      ? '${student.dob!.day}/${student.dob!.month}/${student.dob!.year}'
                      : null),
              _Field('Gender', student.gender),
              _Field('Caste', student.caste),
            ],
          ),

          _DetailCard(
            title: 'Address & Contact',
            icon: Icons.location_on_outlined,
            fields: [
              _Field('Address', student.address),
              _Field('Village / Town', student.village),
              _Field('District', student.district),
              _Field('State', student.state),
              _Field('PIN Code', student.pin),
              _Field('Mobile No. 1', student.mobileNo1),
              _Field('Mobile No. 2', student.mobileNo2),
            ],
          ),

          _DetailCard(
            title: 'Identity & Certificates',
            icon: Icons.badge_outlined,
            fields: [
              _Field('Aadhar Number',
                  _maskAadhar(student.aadharNumber)),
              _Field('PAN Card', student.panCard),
              _Field('Family ID', student.familyId),
            ],
            fileUrls: {
              'SC Certificate': student.scCertificateUrl,
              'BC Certificate': student.bcCertificateUrl,
              'Sports Certificate': student.sportsCertificateUrl,
            },
          ),

          _DetailCard(
            title: 'Educational Qualifications',
            icon: Icons.school_outlined,
            fileUrls: {
              '10th': student.tenthUrl,
              '12th': student.twelfthUrl,
              'Graduation': student.graduationUrl,
              'Post Graduation': student.postGraduationUrl,
              'Diploma': student.diplomaUrl,
            },
          ),

          _DetailCard(
            title: 'Course & Fees',
            icon: Icons.menu_book_outlined,
            fields: [
              _Field('Student ID', student.studentId),
              _Field('Course', student.nameOfCourse),
              _Field('Year of Admission',
                  student.yearOfAdmission?.toString()),
              _Field('Placement Details', student.placementDetails),
              _Field('Fee â€“ 1st Year', student.feeDetails1stYear),
              _Field('Fee â€“ 2nd Year', student.feeDetails2ndYear),
              _Field('Fine', student.fineIfAny),
              _Field('Exam Fee', student.examFee),
            ],
            fileUrls: {
              for (int i = 0; i < student.otherFileUrls.length; i++)
                'File ${i + 1}': student.otherFileUrls[i],
            },
          ),

          _MetadataCard(student: student),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _maskAadhar(String n) {
    if (n.length < 4) return n;
    return 'XXXX XXXX ${n.substring(n.length - 4)}';
  }
}

class _Field {
  final String label;
  final String? value;
  _Field(this.label, this.value);
}

// â”€â”€ Header Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HeaderCard extends StatelessWidget {
  final StudentModel student;
  const _HeaderCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Photo or avatar
            student.photoUrl == null ? CircleAvatar(
              radius: 13,
              backgroundColor: avatarColor(student.name),
              child: Text(
                student.name.isNotEmpty
                    ? student.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ) : ImageNetwork(image: student.photoUrl!, height: 100, width: 100, fitWeb: BoxFitWeb.fill, borderRadius: BorderRadius.all(Radius.circular(32),)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name.isEmpty ? 'Unknown Student' : student.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (student.studentId.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3C6E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        student.studentId,
                        style: const TextStyle(
                          color: Color(0xFF1A3C6E),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (student.nameOfCourse.isNotEmpty)
                        _Chip(student.nameOfCourse, Colors.teal),
                      if (student.yearOfAdmission != null)
                        _Chip(
                            'Batch ${student.yearOfAdmission}',
                            Colors.amber.shade800),
                      if (student.isLocked)
                        _Chip('Locked', Colors.red.shade700),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// â”€â”€ Detail Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DetailCard extends StatefulWidget {
  final String title;
  final IconData icon;
  List<_Field> fields;
  final Map<String, String?> fileUrls;

  _DetailCard({
    required this.title,
    required this.icon,
    this.fields = const [],
    this.fileUrls = const {},
  });

  @override
  State<_DetailCard> createState() => _DetailCardState();
}

class _DetailCardState extends State<_DetailCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final nonEmpty = widget.fields
        .where((f) => f.value != null && f.value!.isNotEmpty)
        .toList();
    final nonEmptyFiles = widget.fileUrls.entries
        .where((e) => e.value != null && e.value!.isNotEmpty)
        .toList();

    if (nonEmpty.isEmpty && nonEmptyFiles.isEmpty) return const SizedBox();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3C6E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon,
                        size: 16, color: const Color(0xFF1A3C6E)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A3C6E)),
                  ),
                  const Spacer(),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...nonEmpty.map((f) => _FieldRow(f.label, f.value!)),
                  ...nonEmptyFiles.map((e) => _FileRow(e.key, e.value!)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  const _FieldRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final String label;
  final String url;
  const _FileRow(this.label, this.url);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () async {
              await launchUrl(Uri.parse(url));
              // Open URL â€” use url_launcher in production
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Open: $url')),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('View File', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1A3C6E),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Metadata Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MetadataCard extends StatelessWidget {
  final StudentModel student;
  const _MetadataCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record Metadata',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _MetaRow('Doc ID', student.docId ?? 'â€”'),
            _MetaRow('Version', 'v${student.documentVersion}'),
            _MetaRow('Status', student.isLocked ? 'ðŸ”’ Locked' : 'âœï¸ Editable'),
            if (student.createdAt != null)
              _MetaRow('Created',
                  _fmt(student.createdAt!)),
            if (student.updatedAt != null)
              _MetaRow('Updated',
                  _fmt(student.updatedAt!)),
            _MetaRow('Created by', student.createdBy ?? ""),
            _MetaRow('Last Update by', student.lastUpdatedBy ?? "")
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
