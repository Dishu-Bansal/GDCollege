import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_network/image_network.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants.dart';
import '../models/student_model.dart';
import 'student_form_screen.dart';
import '../../repositories/student_repository.dart';
import '../../models/user_session.dart';
import '../../providers.dart';
import '../../models/audit_log.dart';

class StudentDetailScreen extends ConsumerStatefulWidget {
  final StudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  ConsumerState<StudentDetailScreen> createState() =>
      _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  StudentRepository get _service => ref.read(studentRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
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
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.person_outlined, size: 18), text: 'Details'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DetailsTab(student: student, service: _service),
          if (student.docId != null)
            _StudentLogTab(service: _service, studentId: student.docId!)
          else
            const Center(child: Text('Student record not yet saved')),
        ],
      ),
    );
  }
}

// ── Details Tab ───────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final StudentModel student;
  final StudentRepository service;
  const _DetailsTab({required this.student, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(student: student),

        const SizedBox(height: 12),

        _DetailCard(
          title: 'Personal Information',
          icon: Icons.person_outline,
          fields: [
            _Field('Full Name', student.name),
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
            _Field('Aadhar Number', student.aadharNumber),
            _Field('PAN Card', student.panCard),
            _Field('Family ID', student.familyId),
            _Field('ABC ID Number', student.abcIdNumber),
          ],
          fileUrls: {
            'Aadhar Card': student.aadharUrl,
            'PAN Card': student.panUrl,
            'Family ID': student.familyIdDocUrl,
            'Haryana Residence': student.haryanaResidenceUrl,
            'ABC ID': student.abcIdUrl,
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
            _Field('Fee – 1st Year', _money(student.feeDetails1stYear)),
            _Field('Fee – 2nd Year', _money(student.feeDetails2ndYear)),
            _Field('Fee – 3rd Year', _money(student.feeDetails3rdYear)),
            for (final f in student.otherFees)
              if (_feeHasValue(f)) _Field(_feeLabel(f), _feeSummary(f)),
          ],
          fileUrls: {
            if (student.otherFileUrls.isEmpty)
              'Supporting Files': null,
            for (int i = 0; i < student.otherFileUrls.length; i++)
              'File ${i + 1}': student.otherFileUrls[i],
          },
        ),

        _MetadataCard(student: student),

        _VerificationCard(
          student: student,
          service: service,
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  /// Prefixes a whole-rupee amount with the ₹ symbol ('' stays empty).
  static String _money(String amount) {
    final a = amount.trim();
    return a.isEmpty ? '' : '₹ $a';
  }

  static bool _feeHasValue(Map<String, String> f) =>
      (f['type'] ?? '').trim().isNotEmpty ||
      (f['amount'] ?? '').trim().isNotEmpty ||
      (f['comment'] ?? '').trim().isNotEmpty;

  static String _feeLabel(Map<String, String> f) {
    final type = (f['type'] ?? '').trim();
    return type.isEmpty ? 'Fee' : 'Fee · $type';
  }

  static String _feeSummary(Map<String, String> f) {
    final amount = _money(f['amount'] ?? '');
    final comment = (f['comment'] ?? '').trim();
    if (amount.isNotEmpty && comment.isNotEmpty) return '$amount ($comment)';
    return amount.isNotEmpty ? amount : comment;
  }
}

// ── Student Log Tab ───────────────────────────────────────────────────────────

class _StudentLogTab extends StatelessWidget {
  final StudentRepository service;
  final String studentId;
  const _StudentLogTab({required this.service, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AuditLog>>(
      stream: service.watchStudentLogs(studentId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Unable to load logs.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
            ]),
          );
        }
        final logs = snap.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No activity yet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _LogTile(log: logs[i]),
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  final AuditLog log;
  const _LogTile({required this.log});

  IconData get _icon {
    switch (log.action) {
      case 'create':
        return Icons.check_circle_outline;
      case 'delete':
        return Icons.cancel_outlined;
      default:
        return Icons.sync;
    }
  }

  Color get _color {
    switch (log.action) {
      case 'create':
        return Colors.green.shade700;
      case 'delete':
        return Colors.red.shade600;
      default:
        return Colors.blue.shade700;
    }
  }

  String get _actionLabel {
    switch (log.action) {
      case 'create':
        return 'Created';
      case 'delete':
        return 'Deleted';
      default:
        return 'Updated';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_icon, color: _color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_actionLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _color)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(log.detail,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 4),
              if (log.changedBy.isNotEmpty)
                Text(log.changedBy,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(
                _fmt(log.timestamp),
                style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  String _fmt(DateTime d) {
    final date = '${d.day}/${d.month}/${d.year}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date  $time';
  }
}

class _Field {
  final String label;
  final String? value;
  _Field(this.label, this.value);
}

// ── Header Card ───────────────────────────────────────────────────────────────

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
            ) : _isPdfUrl(student.photoUrl!)
                ? _PdfPhotoThumb(url: student.photoUrl!)
                : ImageNetwork(image: student.photoUrl!, height: 100, width: 100, fitWeb: BoxFitWeb.fill, borderRadius: BorderRadius.all(Radius.circular(32),)),
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
                      _Chip(
                        student.isVerified ? 'Verified' : 'Unverified',
                        student.isVerified
                            ? Colors.green.shade700
                            : Colors.amber.shade800,
                      ),
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
    // Every field and file slot is rendered, even when empty: an empty
    // value shows as '—' instead of hiding the row (or the whole card).
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
                  for (final f in widget.fields) _FieldRow(f.label, f.value),
                  for (final e in widget.fileUrls.entries)
                    _FileRow(e.key, e.value),
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
  final String? value;
  const _FieldRow(this.label, this.value);

  bool get _isEmpty => value == null || value!.trim().isEmpty;

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
            child: Text(
              _isEmpty ? '—' : value!.trim(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _isEmpty ? Colors.grey.shade400 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final String label;
  final String? url;
  const _FileRow(this.label, this.url);

  bool get _isEmpty => url == null || url!.isEmpty;

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
          if (_isEmpty)
            Expanded(
              child: Text('—',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400)),
            )
          else
            TextButton.icon(
              onPressed: () async {
                await launchUrl(Uri.parse(url!));
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
            _MetaRow('Doc ID', student.docId ?? '—'),
            _MetaRow('Version', 'v${student.documentVersion}'),
            _MetaRow('Status', student.isLocked ? '🔒 Locked' : '✏️ Editable'),
            _MetaRow('Verification',
                student.isVerified ? '✅ Verified' : '⏳ Unverified'),
            if (student.isVerified) ...[
              _MetaRow('Verified by', student.verifiedBy),
              if (student.verifiedAt != null)
                _MetaRow('Verified at', _fmt(student.verifiedAt!)),
            ],
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

/// Storage URLs keep the original filename (with extension) before the
/// query string, so a photo uploaded as .pdf is detectable here.
bool _isPdfUrl(String url) =>
    url.split('?').first.toLowerCase().endsWith('.pdf');

/// 100x100 thumbnail for a photo uploaded as PDF: opens the file instead
/// of trying to render it as an image.
class _PdfPhotoThumb extends StatelessWidget {
  final String url;
  const _PdfPhotoThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      borderRadius: const BorderRadius.all(Radius.circular(32)),
      child: Container(
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF1A3C6E).withOpacity(0.08),
          borderRadius: const BorderRadius.all(Radius.circular(32)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_outlined,
                size: 36, color: Color(0xFF1A3C6E)),
            SizedBox(height: 4),
            Text('View PDF',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A3C6E),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
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

// ── Verification Card ─────────────────────────────────────────────────────────
// Reviewer attestation: tick every info group + every uploaded document,
// then mark verified (who + when stamped, logged). Blocked while required
// documents are missing. Any later edit auto-revokes (service layer).

class _VerificationCard extends StatefulWidget {
  final StudentModel student;
  final StudentRepository service;
  const _VerificationCard({required this.student, required this.service});

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final verified = s.isVerified;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                verified
                    ? Icons.verified_outlined
                    : Icons.fact_check_outlined,
                size: 18,
                color: verified
                    ? Colors.green.shade700
                    : const Color(0xFF1A3C6E),
              ),
              const SizedBox(width: 8),
              const Text('Verification',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A3C6E))),
            ]),
            const SizedBox(height: 8),
            if (verified) ...[
              Text(
                'Verified by ${s.verifiedBy}'
                '${s.verifiedAt != null ? ' on ${_fmtDate(s.verifiedAt!)}' : ''}',
                style:
                    TextStyle(fontSize: 13, color: Colors.green.shade800),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _revoke,
                icon: const Icon(Icons.undo_outlined, size: 16),
                label: const Text('Revoke verification'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700),
              ),
            ] else if (s.missingDocsCount > 0) ...[
              Text(
                'Complete ${s.missingDocsCount} missing document${s.missingDocsCount == 1 ? '' : 's'} before verifying:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              for (final m in s.missingDocs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $m',
                      style: TextStyle(
                          fontSize: 12, color: Colors.red.shade700)),
                ),
            ] else ...[
              const Text(
                'Check every info field and document below, one by one, then mark verified.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _verifyFlow,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Verify checklist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
            if (_saving) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  Future<void> _verifyFlow() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _VerifyDialog(student: widget.student),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.service.verifyStudent(widget.student.docId!);
      widget.student
        ..isVerified = true
        ..verifiedBy = UserSession().currentUser?.email ?? ''
        ..verifiedAt = DateTime.now();
      if (!mounted) return;
      _reload('Student verified');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    }
  }

  Future<void> _revoke() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Revoke verification?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.service.unverifyStudent(widget.student.docId!,
          reason: reason);
      widget.student
        ..isVerified = false
        ..verifiedBy = ''
        ..verifiedAt = null;
      if (!mounted) return;
      _reload('Verification revoked');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revoke failed: $e')),
      );
    }
  }

  /// Rebuilds the whole detail screen from the mutated student so header
  /// chips, metadata and this card all reflect the new state at once.
  void _reload(String msg) {
    final s = widget.student;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s)),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Tick-everything checklist: info groups plus one row per uploaded file
/// (with View link). Missing optional files are shown but don't block.
class _VerifyDialog extends StatefulWidget {
  final StudentModel student;
  const _VerifyDialog({required this.student});

  @override
  State<_VerifyDialog> createState() => _VerifyDialogState();
}

class _VerifyDialogState extends State<_VerifyDialog> {
  final Set<String> _checked = {};

  static const _groups = [
    'Personal Information',
    'Address & Contact',
    'Identity Numbers',
    'Course & Fees',
  ];

  List<MapEntry<String, String?>> _files(StudentModel s) => [
        MapEntry('Photo', s.photoUrl),
        MapEntry('Aadhar Card', s.aadharUrl),
        MapEntry('PAN Card', s.panUrl),
        MapEntry('Family ID', s.familyIdDocUrl),
        MapEntry('Haryana Residence', s.haryanaResidenceUrl),
        MapEntry('ABC ID', s.abcIdUrl),
        MapEntry('SC Certificate', s.scCertificateUrl),
        MapEntry('BC Certificate', s.bcCertificateUrl),
        MapEntry('Sports Certificate', s.sportsCertificateUrl),
        MapEntry('10th', s.tenthUrl),
        MapEntry('12th', s.twelfthUrl),
        MapEntry('Graduation', s.graduationUrl),
        MapEntry('Post Graduation', s.postGraduationUrl),
        MapEntry('Diploma', s.diplomaUrl),
        for (int i = 0; i < s.otherFileUrls.length; i++)
          MapEntry('File ${i + 1}', s.otherFileUrls[i]),
      ];

  @override
  Widget build(BuildContext context) {
    final files = _files(widget.student);
    final required = {
      ..._groups,
      for (final f in files)
        if (f.value != null && f.value!.isNotEmpty) 'file:${f.key}',
    };
    final done = required.difference(_checked).isEmpty;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('Verify ${widget.student.name}',
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Tick each item after checking it against the record above.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            for (final g in _groups)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(g, style: const TextStyle(fontSize: 13)),
                value: _checked.contains(g),
                onChanged: (_) => setState(() {
                  if (!_checked.remove(g)) _checked.add(g);
                }),
              ),
            const Divider(),
            for (final f in files)
              _fileCheckRow(f.key, f.value, required),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: done ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700),
          child: const Text('Mark Verified'),
        ),
      ],
    );
  }

  Widget _fileCheckRow(
      String label, String? url, Set<String> required) {
    final present = url != null && url.isNotEmpty;
    final key = 'file:$label';
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: present ? null : Colors.grey.shade500)),
        ),
        if (present)
          TextButton(
            onPressed: () => launchUrl(Uri.parse(url)),
            child: const Text('View', style: TextStyle(fontSize: 12)),
          )
        else
          const Text('Not uploaded',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
      value: present && _checked.contains(key),
      onChanged: present
          ? (_) => setState(() {
                if (!_checked.remove(key)) _checked.add(key);
              })
          : null,
    );
  }
}
