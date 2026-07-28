import 'package:flutter/material.dart';
import 'package:image_network/image_network.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/staff_model.dart';
import 'staff_form_screen.dart';
import '../../repositories/staff_repository.dart';

class StaffDetailScreen extends StatelessWidget {
  final StaffModel staff;

  const StaffDetailScreen({super.key, required this.staff});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(
          staff.name.isEmpty ? 'Staff Details' : staff.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (!staff.isLocked)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StaffFormScreen(existingStaff: staff),
                  ),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header Card ──────────────────────────────────────────────
          _HeaderCard(student: staff),

          const SizedBox(height: 12),

          // ── Sections ─────────────────────────────────────────────────
          _DetailCard(
            title: 'Personal Information',
            icon: Icons.person_outline,
            fields: [
              _Field('Father\'s Name', staff.fatherName),
              _Field('Mother\'s Name', staff.motherName),
              _Field('Date of Birth',
                  staff.dob != null
                      ? '${staff.dob!.day}/${staff.dob!.month}/${staff.dob!.year}'
                      : null),
              _Field('Gender', staff.gender),
              _Field('Caste', staff.caste),
            ],
          ),

          _DetailCard(
            title: 'Address & Contact',
            icon: Icons.location_on_outlined,
            fields: [
              _Field('Address', staff.address),
              _Field('Village / Town', staff.village),
              _Field('District', staff.district),
              _Field('State', staff.state),
              _Field('PIN Code', staff.pin),
              _Field('Mobile No. 1', staff.mobileNo1),
              _Field('Mobile No. 2', staff.mobileNo2),
            ],
          ),

          _DetailCard(
            title: 'Identity & Certificates',
            icon: Icons.badge_outlined,
            fields: [
              _Field('Aadhar Number',
                  _maskAadhar(staff.aadharNumber)),
              _Field('PAN Card', staff.panCard),
              _Field('Family ID', staff.familyId),
            ],
            fileUrls: {
              'Aadhar Card': staff.aadharUrl,
              'PAN card': staff.panUrl,
              'SC Certificate': staff.scCertificateUrl,
              'BC Certificate': staff.bcCertificateUrl,
            },
          ),

          _DetailCard(
            title: 'Educational Qualifications',
            icon: Icons.school_outlined,
            fileUrls: {
              '10th': staff.tenthUrl,
              '12th': staff.twelfthUrl,
              'Graduation': staff.graduationUrl,
              'Post Graduation': staff.postGraduationUrl,
              'Diploma': staff.diplomaUrl,
              'PHD': staff.phdUrl,
              'NET': staff.netUrl,

              // Expand the list into numbered keys
              ...staff.experienceCertificateUrls.asMap().map((index, url) => MapEntry(
                'Experience Certificate ${index + 1}',
                url,
              )),
            },
          ),

          _DetailCard(
            title: 'Course & Fees',
            icon: Icons.menu_book_outlined,
            fields: [
              _Field('staff ID', staff.staffId),
              _Field('Salary', staff.salary),
              _Field('Designation', staff.designation),
              _Field('Course', staff.course),
              _Field('Increments', staff.increments.map((entry) => entry.amount + " on " + entry.date.toString() + "\n").join()),
            ],
            fileUrls: {
              'Joining Letter': staff.joiningLetterUrl,
              'Appointment Letter': staff.appointmentLetterUrl,
              'University Approval': staff.universityApprovalUrl,
              'Resignation Letter': staff.resignationLetterUrl,
              for (int i = 0; i < staff.otherFileUrls.length; i++)
                'File ${i + 1}': staff.otherFileUrls[i],
            },
          ),

          _MetadataCard(staff: staff),

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

// ── Header Card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final StaffModel student;
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
            student.photoUrl == null ? const Icon(Icons.person, size: 64) : ImageNetwork(image: student.photoUrl!, height: 100, width: 100, fitWeb: BoxFitWeb.fill, borderRadius: BorderRadius.all(Radius.circular(32),)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name.isEmpty ? 'Unknown Staff' : student.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (student.designation!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3C6E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        student.designation!,
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
                      if (student.course!.isNotEmpty)
                        _Chip(student.course!, Colors.teal),
                      if (student.course != null)
                        _Chip(
                            '${student.course}',
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

// ── Detail Card ───────────────────────────────────────────────────────────────

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
              // Open URL — use url_launcher in production
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

// ── Metadata Card ─────────────────────────────────────────────────────────────

class _MetadataCard extends StatelessWidget {
  final StaffModel staff;
  const _MetadataCard({required this.staff});

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
            _MetaRow('Doc ID', staff.docId ?? '—'),
            _MetaRow('Version', 'v${staff.documentVersion}'),
            _MetaRow('Status', staff.isLocked ? '🔒 Locked' : '✏️ Editable'),
            if (staff.createdAt != null)
              _MetaRow('Created',
                  _fmt(staff.createdAt!)),
            if (staff.updatedAt != null)
              _MetaRow('Updated',
                  _fmt(staff.updatedAt!)),
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
