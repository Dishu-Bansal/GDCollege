import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers.dart';
import '../models/student_doc_models.dart';
import '../services/firebase_student_docs_service.dart';
import '../widgets/camera_capture_dialog.dart';

/// Per-student DMC + Degree workspace: one card per slot of the student's
/// course. Each card holds the document scan, per-subject marks (DMCs) and
/// the collector's identity (name, phone, Aadhaar + photo, live webcam
/// photo). Saving is per slot so partial progress is never lost.
class StudentDocDetailScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String course;
  final int? yearOfAdmission;

  const StudentDocDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.course,
    required this.yearOfAdmission,
  });

  @override
  State<StudentDocDetailScreen> createState() =>
      _StudentDocDetailScreenState();
}

class _StudentDocDetailScreenState extends State<StudentDocDetailScreen> {
  final _service = FirebaseStudentDocsService();
  late final List<DocSlot> _slots;
  Map<String, StudentDocRecord> _records = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _slots = docSlotsForCourse(widget.course);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap =
          await db.collection('students').doc(widget.studentId).get();
      final data = snap.data() ?? {};
      if (!mounted) return;
      setState(() {
        _records = StudentDocRecord.recordsOf(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load records: $e';
        _loading = false;
      });
    }
  }

  void _onSaved(String slotKey, StudentDocRecord record) {
    setState(() => _records[slotKey] = record);
  }

  @override
  Widget build(BuildContext context) {
    final done = _slots
        .where((s) =>
            (_records[s.key]?.complete(isDmc: s.isDmc) ?? false))
        .length;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(widget.studentName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _load,
                            child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _HeaderCard(
                      course: widget.course,
                      year: widget.yearOfAdmission,
                      done: done,
                      total: _slots.length,
                    ),
                    const SizedBox(height: 10),
                    for (final slot in _slots) ...[
                      _SlotCard(
                        key: ValueKey(
                            '${widget.studentId}_${slot.key}'),
                        studentId: widget.studentId,
                        slot: slot,
                        initial:
                            _records[slot.key] ?? StudentDocRecord(),
                        service: _service,
                        onSaved: (r) => _onSaved(slot.key, r),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String course;
  final int? year;
  final int done;
  final int total;

  const _HeaderCard({
    required this.course,
    required this.year,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = done == total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allDone
              ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.isEmpty ? 'Course not set' : course,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  year == null
                      ? 'Admission year not set'
                      : 'Batch of $year',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (allDone
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFEF6C00))
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$done / $total complete',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: allDone
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFEF6C00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── One slot card ────────────────────────────────────────────────────────────

class _SlotCard extends StatefulWidget {
  final String studentId;
  final DocSlot slot;
  final StudentDocRecord initial;
  final FirebaseStudentDocsService service;
  final void Function(StudentDocRecord) onSaved;

  const _SlotCard({
    super.key,
    required this.studentId,
    required this.slot,
    required this.initial,
    required this.service,
    required this.onSaved,
  });

  @override
  State<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends State<_SlotCard> {
  late StudentDocRecord _record;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController();
  final List<_SubjectRow> _subjectRows = [];

  Uint8List? _pendingFile;
  String? _pendingFileName;
  Uint8List? _pendingAadhar;
  Uint8List? _pendingLive;
  bool _saving = false;

  bool get _complete =>
      _record.complete(isDmc: widget.slot.isDmc) &&
      _pendingFile == null &&
      _pendingAadhar == null &&
      _pendingLive == null;

  @override
  void initState() {
    super.initState();
    _record = StudentDocRecord(
      fileUrl: widget.initial.fileUrl,
      fileName: widget.initial.fileName,
      subjects: widget.initial.subjects
          .map((s) => SubjectMark(
              subject: s.subject, obtained: s.obtained, max: s.max))
          .toList(),
      collector: CollectorInfo(
        name: widget.initial.collector.name,
        phone: widget.initial.collector.phone,
        aadharNumber: widget.initial.collector.aadharNumber,
        aadharUrl: widget.initial.collector.aadharUrl,
        livePhotoUrl: widget.initial.collector.livePhotoUrl,
      ),
      collectedAt: widget.initial.collectedAt,
      updatedBy: widget.initial.updatedBy,
    );
    _nameCtrl.text = _record.collector.name;
    _phoneCtrl.text = _record.collector.phone;
    _aadharCtrl.text = _record.collector.aadharNumber;
    for (final s in _record.subjects) {
      _subjectRows.add(_SubjectRow.from(s));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _aadharCtrl.dispose();
    for (final r in _subjectRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            error ? Colors.red : const Color(0xFF2E7D32),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result =
        await file_picker.FilePicker.platform.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result == null || result.files.isEmpty
        ? null
        : result.files.first;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (bytes.length > 5 * 1024 * 1024) {
      _snack('File must be under 5 MB.', error: true);
      return;
    }
    setState(() {
      _pendingFile = bytes;
      _pendingFileName = file.name;
    });
  }

  Future<void> _pickAadharPhoto() async {
    final result =
        await file_picker.FilePicker.platform.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    final file = result == null || result.files.isEmpty
        ? null
        : result.files.first;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (bytes.length > 5 * 1024 * 1024) {
      _snack('File must be under 5 MB.', error: true);
      return;
    }
    setState(() => _pendingAadhar = bytes);
  }

  Future<void> _captureLive() async {
    final bytes = await CameraCaptureDialog.show(context);
    if (bytes == null) return;
    setState(() => _pendingLive = bytes);
  }

  Future<void> _deleteFile() async {
    final ok = await _confirm('Delete this document scan?');
    if (!ok) return;
    setState(() => _saving = true);
    try {
      await widget.service.deleteUrl(_record.fileUrl ?? '');
      _record.fileUrl = null;
      _record.fileName = null;
      await widget.service.saveRecord(
        studentId: widget.studentId,
        slotKey: widget.slot.key,
        record: _record,
      );
      widget.onSaved(_record);
      _snack('Document deleted.');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePhoto(bool aadhar) async {
    final ok = await _confirm(
        'Delete this ${aadhar ? 'Aadhaar' : 'live'} photo?');
    if (!ok) return;
    setState(() => _saving = true);
    try {
      if (aadhar) {
        await widget.service
            .deleteUrl(_record.collector.aadharUrl ?? '');
        _record.collector.aadharUrl = null;
      } else {
        await widget.service
            .deleteUrl(_record.collector.livePhotoUrl ?? '');
        _record.collector.livePhotoUrl = null;
      }
      await widget.service.saveRecord(
        studentId: widget.studentId,
        slotKey: widget.slot.key,
        record: _record,
      );
      widget.onSaved(_record);
      _snack('Photo deleted.');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirm(String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm'),
            content: Text(msg),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  double? _parseNum(String t) {
    final v = double.tryParse(t.trim());
    return v;
  }

  Future<void> _save() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty && !RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      _snack('Collector phone must be 10 digits.', error: true);
      return;
    }
    final aadhar = _aadharCtrl.text.trim();
    if (aadhar.isNotEmpty &&
        !RegExp(r'^[0-9]{12}$').hasMatch(aadhar)) {
      _snack('Aadhaar number must be 12 digits.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      // Upload anything newly picked, replacing previous files.
      if (_pendingFile != null) {
        await widget.service.deleteUrl(_record.fileUrl ?? '');
        _record.fileUrl = await widget.service.uploadSlotFile(
          studentId: widget.studentId,
          slotKey: widget.slot.key,
          originalName: _pendingFileName ?? 'doc.pdf',
          bytes: _pendingFile!,
        );
        _record.fileName = _pendingFileName;
        _pendingFile = null;
        _pendingFileName = null;
      }
      if (_pendingAadhar != null) {
        await widget.service
            .deleteUrl(_record.collector.aadharUrl ?? '');
        _record.collector.aadharUrl =
            await widget.service.uploadCollectorPhoto(
          studentId: widget.studentId,
          slotKey: widget.slot.key,
          which: 'aadhar',
          bytes: _pendingAadhar!,
        );
        _pendingAadhar = null;
      }
      if (_pendingLive != null) {
        await widget.service
            .deleteUrl(_record.collector.livePhotoUrl ?? '');
        _record.collector.livePhotoUrl =
            await widget.service.uploadCollectorPhoto(
          studentId: widget.studentId,
          slotKey: widget.slot.key,
          which: 'live',
          bytes: _pendingLive!,
        );
        _pendingLive = null;
      }
      _record.collector.name = _nameCtrl.text.trim();
      _record.collector.phone = phone;
      _record.collector.aadharNumber = aadhar;
      _record.subjects = _subjectRows
          .map((r) => SubjectMark(
                subject: r.subjectCtrl.text.trim(),
                obtained: _parseNum(r.obtainedCtrl.text),
                max: _parseNum(r.maxCtrl.text),
              ))
          .toList();
      await widget.service.saveRecord(
        studentId: widget.studentId,
        slotKey: widget.slot.key,
        record: _record,
      );
      widget.onSaved(_record);
      _snack('${widget.slot.label} saved.');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complete = _complete;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: complete
              ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.slot.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (complete
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFEF6C00))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  complete ? 'Complete' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: complete
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFEF6C00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SectionTitle('Document'),
          const SizedBox(height: 6),
          _fileRow(),
          if (widget.slot.isDmc) ...[
            const SizedBox(height: 10),
            _SectionTitle('Subject Marks'),
            const SizedBox(height: 6),
            _subjectsEditor(),
          ],
          const SizedBox(height: 10),
          _SectionTitle('Collected By'),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Collector name',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Collector phone',
                    hintText: '10 digits',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _aadharCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar number',
                    hintText: '12 digits',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PhotoBox(
                  title: 'Aadhaar Photo',
                  bytes: _pendingAadhar,
                  url: _record.collector.aadharUrl,
                  onPick: _pickAadharPhoto,
                  onDelete: _record.collector.aadharUrl == null
                      ? null
                      : () => _deletePhoto(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PhotoBox(
                  title: 'Live Photo',
                  bytes: _pendingLive,
                  url: _record.collector.livePhotoUrl,
                  actionLabel: 'Webcam',
                  actionIcon: Icons.videocam_outlined,
                  onPick: _captureLive,
                  onDelete:
                      _record.collector.livePhotoUrl == null
                          ? null
                          : () => _deletePhoto(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_saving ? 'Saving…' : 'Save ${widget.slot.label}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3C6E),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileRow() {
    if (_pendingFile != null) {
      return _rowBox(
        Icons.insert_drive_file_outlined,
        _pendingFileName ?? 'New file',
        'Ready to upload on Save',
        trailing: IconButton(
          icon: const Icon(Icons.clear, size: 18),
          onPressed: () => setState(() {
            _pendingFile = null;
            _pendingFileName = null;
          }),
        ),
      );
    }
    if (_record.hasFile) {
      return _rowBox(
        Icons.insert_drive_file_outlined,
        _record.fileName ?? 'Document',
        'Uploaded — tap to view',
        onTap: () => launchUrl(Uri.parse(_record.fileUrl!)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 18, color: Colors.red),
          onPressed: _saving ? null : _deleteFile,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _pickFile,
      icon: const Icon(Icons.upload_file_outlined, size: 18),
      label: const Text('Upload scan (PDF / JPG / PNG, ≤5 MB)'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1A3C6E),
        side: const BorderSide(color: Color(0xFF1A3C6E)),
      ),
    );
  }

  Widget _rowBox(IconData icon, String title, String subtitle,
      {VoidCallback? onTap, Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF1A3C6E)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _subjectsEditor() {
    final totalObtained = _subjectRows.fold(
        0.0,
        (s, r) =>
            s + (double.tryParse(r.obtainedCtrl.text.trim()) ?? 0));
    final totalMax = _subjectRows.fold(
        0.0,
        (s, r) => s + (double.tryParse(r.maxCtrl.text.trim()) ?? 0));
    return Column(
      children: [
        for (var i = 0; i < _subjectRows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _subjectRows[i].subjectCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _subjectRows[i].obtainedCtrl,
                    onChanged: (_) => setState(() {}),
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Marks',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _subjectRows[i].maxCtrl,
                    onChanged: (_) => setState(() {}),
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Max',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.redAccent),
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _subjectRows.removeAt(i)),
                ),
              ],
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(
                  () => _subjectRows.add(_SubjectRow())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add subject',
                  style: TextStyle(fontSize: 12)),
            ),
            const Spacer(),
            if (_subjectRows.isNotEmpty)
              Text(
                'Total: ${_fmtNum(totalObtained)} / ${_fmtNum(totalMax)}'
                '${totalMax > 0 ? '  (${(totalObtained / totalMax * 100).toStringAsFixed(1)}%)' : ''}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ],
    );
  }

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Colors.grey.shade500,
      ),
    );
  }
}

class _SubjectRow {
  final TextEditingController subjectCtrl = TextEditingController();
  final TextEditingController obtainedCtrl = TextEditingController();
  final TextEditingController maxCtrl = TextEditingController();

  _SubjectRow();

  _SubjectRow.from(SubjectMark s) {
    subjectCtrl.text = s.subject;
    obtainedCtrl.text =
        s.obtained == null ? '' : _num(s.obtained!);
    maxCtrl.text = s.max == null ? '' : _num(s.max!);
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  void dispose() {
    subjectCtrl.dispose();
    obtainedCtrl.dispose();
    maxCtrl.dispose();
  }
}

/// Thumbnail box for Aadhaar / live photos: pending bytes, saved URL, or an
/// action button to pick/capture.
class _PhotoBox extends StatelessWidget {
  final String title;
  final Uint8List? bytes;
  final String? url;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onPick;
  final VoidCallback? onDelete;

  const _PhotoBox({
    required this.title,
    required this.bytes,
    required this.url,
    required this.onPick,
    this.actionLabel = 'Upload',
    this.actionIcon = Icons.upload_outlined,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Widget? preview;
    final pendingBytes = bytes;
    if (pendingBytes != null) {
      preview = Image.memory(pendingBytes,
          height: 110, width: double.infinity, fit: BoxFit.cover);
    } else if (url != null && url!.isNotEmpty) {
      preview = url!.toLowerCase().endsWith('.pdf')
          ? const SizedBox(
              height: 110,
              child: Center(
                  child: Icon(Icons.picture_as_pdf_outlined,
                      size: 36, color: Colors.redAccent)),
            )
          : Image.network(url!,
              height: 110, width: double.infinity, fit: BoxFit.cover);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: preview ??
              InkWell(
                onTap: onPick,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(actionIcon,
                          size: 26, color: Colors.grey.shade500),
                      const SizedBox(height: 4),
                      Text(actionLabel,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
        ),
        if (preview != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onPick,
                child: Text(bytes != null ? 'Change' : 'Replace',
                    style: const TextStyle(fontSize: 11)),
              ),
              if (onDelete != null)
                TextButton(
                  onPressed: onDelete,
                  child: const Text('Delete',
                      style:
                          TextStyle(fontSize: 11, color: Colors.red)),
                ),
            ],
          )
        else
          const SizedBox(height: 4),
      ],
    );
  }
}
