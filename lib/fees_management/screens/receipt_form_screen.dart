import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:gd_college/constants.dart';
import 'package:gd_college/providers.dart';
import 'package:gd_college/student_management/models/student_model.dart';
import '../models/receipt_model.dart';
import '../models/student_fee_structure.dart';
import '../repositories/fees_repository.dart';

/// Records a fee receipt for a student. The student is picked through
/// College → Course → Admission year → a searchable student list.
class ReceiptFormScreen extends ConsumerStatefulWidget {
  /// College preselected in the picker (the tab the form was opened from).
  final String initialCollege;

  const ReceiptFormScreen(
      {super.key, this.initialCollege = 'GD College'});

  @override
  ConsumerState<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends ConsumerState<ReceiptFormScreen> {
  late final FeesRepository _feesService = ref.read(feesRepositoryProvider);
  final _formKey = GlobalKey<FormState>();

  String _college = StudentGroup.gdCollege.label;
  String _course = 'B.ED';
  late int _year;
  StudentModel? _selectedStudent;

  final _studentCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _modeCtrl = TextEditingController(text: 'Cash');
  final _receiptNoCtrl = TextEditingController();

  Uint8List? _photoBytes;
  bool _saving = false;

  List<String> get _courseOptions {
    final set = _college == StudentGroup.gdCollege.label
        ? gdCollegeCourses
        : mlsnCourses;
    return set.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    if (widget.initialCollege == StudentGroup.mlsn.label) {
      _college = StudentGroup.mlsn.label;
      _course = 'ANM';
    }
  }

  @override
  void dispose() {
    _studentCtrl.dispose();
    _amountCtrl.dispose();
    _modeCtrl.dispose();
    _receiptNoCtrl.dispose();
    super.dispose();
  }

  List<StudentModel> _filteredStudents(List<StudentModel> students) =>
      students
          .where((s) =>
              collegeLabelOf(s) == _college &&
              s.nameOfCourse == _course &&
              s.yearOfAdmission == _year)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<void> _openStudentPicker(List<StudentModel> students) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No students match College/Course/Year.')));
      return;
    }
    final picked = await showModalBottomSheet<StudentModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _StudentPickerSheet(students: students),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedStudent = picked;
        _studentCtrl.text = picked.name;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _photoBytes = bytes);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a student')),
      );
      return;
    }
    if (_selectedStudent!.docId == null || _selectedStudent!.docId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected student has no record ID')),
      );
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the fees received')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String photoUrl = '';
      if (_photoBytes != null) {
        photoUrl = await _feesService.uploadReceiptPhoto(
          _photoBytes!,
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }
      await _feesService.createReceipt(
        studentId: _selectedStudent!.docId!,
        amount: amount,
        mode: _modeCtrl.text.trim(),
        receiptNumber: _receiptNoCtrl.text.trim(),
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text('Receipt saved — ₹${amount.toStringAsFixed(0)} for '
              '${_selectedStudent!.name}')));
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(allStudentsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Add Receipt')),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (all) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _form(all),
        ),
      ),
    );
  }

  Widget _form(List<StudentModel> all) {
    final filtered = _filteredStudents(all);
    return Form(
      key: _formKey,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // College / Course
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _college,
                    decoration: const InputDecoration(
                      labelText: 'College',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: [StudentGroup.gdCollege.label, StudentGroup.mlsn.label]
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _college = v;
                          _course = (v == StudentGroup.gdCollege.label
                                  ? gdCollegeCourses
                                  : mlsnCourses)
                              .first;
                          _selectedStudent = null;
                          _studentCtrl.clear();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // Rebuilt with the college so the selected course is
                    // always one of the visible options.
                    key: ValueKey(_college),
                    initialValue: _course,
                    decoration: const InputDecoration(
                      labelText: 'Course',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    items: _courseOptions
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _course = v;
                          _selectedStudent = null;
                          _studentCtrl.clear();
                        });
                      }
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // Admission year
              DropdownButtonFormField<int>(
                initialValue: _year,
                decoration: const InputDecoration(
                  labelText: 'Admission Year',
                  prefixIcon: Icon(Icons.event),
                ),
                items: [
                  for (var y = DateTime.now().year; y >= 2010; y--)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _year = v;
                      _selectedStudent = null;
                      _studentCtrl.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              // Student — opens a searchable picker of the students matching
              // the college/course/year chosen above. A read-only text field
              // keeps the label/hint layering identical to the other inputs.
              TextFormField(
                controller: _studentCtrl,
                readOnly: true,
                onTap: _saving ? null : () => _openStudentPicker(filtered),
                decoration: const InputDecoration(
                  labelText: 'Student *',
                  hintText: 'Search by name, father or student ID',
                  prefixIcon: Icon(Icons.person_search_outlined),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
              ),
              if (_selectedStudent != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _StudentSummary(student: _selectedStudent!),
                ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No students match College/Course/Year. Create the student first.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              const SizedBox(height: 16),

              // Fees received + mode
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,8}(\.\d{0,2})?')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Fees Received (₹) *',
                      prefixText: '₹ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownMenu<String>(
                    controller: _modeCtrl,
                    initialSelection: 'Cash',
                    label: const Text('Mode of Payment'),
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(value: 'Cash', label: 'Cash'),
                      DropdownMenuEntry(
                          value: 'Account-XXXX', label: 'Account-XXXX'),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // Receipt number
              TextFormField(
                controller: _receiptNoCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Receipt Number (optional)',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Pending preview for the picked student.
              if (_selectedStudent != null)
                _PendingPreview(student: _selectedStudent!),
              if (_selectedStudent != null) const SizedBox(height: 16),

              // Receipt photo
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_photoBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(_photoBytes!,
                              width: 48, height: 48, fit: BoxFit.cover),
                        )
                      else
                        Icon(Icons.receipt_long_outlined,
                            color: Colors.grey.shade600, size: 32),
                      const SizedBox(width: 10),
                      Text(
                        _photoBytes != null
                            ? 'Receipt photo attached'
                            : 'Add receipt photo (optional)',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Receipt',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
  }
}

/// Live pending-fees preview for the picked student, computed from the
/// current receipts stream so the collector sees the dues before saving.
class _PendingPreview extends ConsumerWidget {
  final StudentModel student;

  const _PendingPreview({required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<ReceiptModel>>(
      stream: ref.read(feesRepositoryProvider).watchAllReceipts(),
      builder: (context, snap) {
        final receipts = (snap.data ?? [])
            .where((r) => r.studentId == student.docId)
            .toList();
        final fees = feeEntriesOf(student);
        final pending = FeesCalc.pendingByType(fees, receipts);
        final total = FeesCalc.pendingTotal(fees, receipts);
        if (fees.isEmpty) {
          return Text('No fee heads set for this student.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3C6E).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in fees)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(children: [
                    Expanded(
                        child: Text(f.type,
                            style: const TextStyle(fontSize: 12))),
                    Text('₹${(pending[f.type] ?? 0).toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (pending[f.type] ?? 0) > 0
                                ? Colors.red.shade700
                                : const Color(0xFF2E7D32))),
                  ]),
                ),
              const Divider(height: 10),
              Row(children: [
                const Expanded(
                    child: Text('Pending total',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700))),
                Text('₹${total.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: total > 0
                            ? Colors.red.shade700
                            : const Color(0xFF2E7D32))),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ── Searchable student picker (bottom sheet) ────────────────────────────────

/// Bottom-sheet list of candidate students with a search box on top.
/// Entries show the student's name, father's name and student ID.
class _StudentPickerSheet extends StatefulWidget {
  final List<StudentModel> students;

  const _StudentPickerSheet({required this.students});

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<StudentModel> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.students;
    return widget.students
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.fatherName.toLowerCase().contains(q) ||
            s.studentId.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(children: [
            const Text('Select Student',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search by name, father or student ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text('No students match your search.',
                      style: TextStyle(color: Colors.grey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey.shade100),
                  itemBuilder: (_, i) => _StudentPickerTile(
                    student: results[i],
                    onTap: () => Navigator.pop(context, results[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _StudentPickerTile extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onTap;

  const _StudentPickerTile({required this.student, required this.onTap});

  String get _initial {
    final n = student.name.trim();
    return n.isEmpty ? '?' : n.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1A3C6E).withValues(alpha: 0.12),
            child: Text(_initial,
                style: const TextStyle(
                    color: Color(0xFF1A3C6E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (student.fatherName.isNotEmpty)
                  Text('Father: ${student.fatherName}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700)),
                if (student.studentId.isNotEmpty)
                  Text('ID: ${student.studentId}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

/// Small confirmation card under the student field showing the picked
/// student's father's name and student ID (when present).
class _StudentSummary extends StatelessWidget {
  final StudentModel student;

  const _StudentSummary({required this.student});

  @override
  Widget build(BuildContext context) {
    final hasFather = student.fatherName.isNotEmpty;
    final hasId = student.studentId.isNotEmpty;
    if (!hasFather && !hasId) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3C6E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasFather)
            Text('Father: ${student.fatherName}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
          if (hasId)
            Text('ID: ${student.studentId}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
