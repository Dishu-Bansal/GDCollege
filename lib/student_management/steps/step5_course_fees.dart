import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gd_college/constants.dart';
import '../models/student_model.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/file_picker_widget.dart';

class Step5CourseAndFees extends StatefulWidget {
  final StudentModel student;
  final GlobalKey<FormState> formKey;

  const Step5CourseAndFees({
    super.key,
    required this.student,
    required this.formKey,
  });

  @override
  State<Step5CourseAndFees> createState() => _Step5CourseAndFeesState();
}

/// One editable row of the "other fees" section: fee type, amount, comment.
class _FeeRow {
  final TextEditingController typeCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController commentCtrl;

  _FeeRow({String type = '', String amount = '', String comment = ''})
    : typeCtrl = TextEditingController(text: type),
      amountCtrl = TextEditingController(text: amount),
      commentCtrl = TextEditingController(text: comment);
}

class _Step5CourseAndFeesState extends State<Step5CourseAndFees> {
  late final TextEditingController _studentIdCtrl;
  late final TextEditingController _placementCtrl;
  late final TextEditingController _fee1Ctrl;
  late final TextEditingController _fee2Ctrl;
  late final TextEditingController _fee3Ctrl;
  late final TextEditingController _yearCtrl;
  late final List<_FeeRow> _feeRows;

  @override
  void initState() {
    super.initState();
    _studentIdCtrl = TextEditingController(text: widget.student.studentId);
    _placementCtrl = TextEditingController(
      text: widget.student.placementDetails,
    );
    _fee1Ctrl = TextEditingController(text: widget.student.feeDetails1stYear);
    _fee2Ctrl = TextEditingController(text: widget.student.feeDetails2ndYear);
    _fee3Ctrl = TextEditingController(text: widget.student.feeDetails3rdYear);
    _yearCtrl = TextEditingController(
      text: widget.student.yearOfAdmission?.toString() ?? '',
    );
    _feeRows = [
      for (final f in widget.student.otherFees)
        _FeeRow(
          type: f['type'] ?? '',
          amount: f['amount'] ?? '',
          comment: f['comment'] ?? '',
        ),
    ];
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _placementCtrl.dispose();
    _fee1Ctrl.dispose();
    _fee2Ctrl.dispose();
    _fee3Ctrl.dispose();
    for (final r in _feeRows) {
      r.typeCtrl.dispose();
      r.amountCtrl.dispose();
      r.commentCtrl.dispose();
    }
    _yearCtrl.dispose();
    super.dispose();
  }

  /// Writes the "other fees" rows back onto the student model. Completely
  /// empty rows are dropped so Firestore stays clean.
  void _syncFeeRows() {
    widget.student.otherFees = [
      for (final r in _feeRows)
        if (r.typeCtrl.text.trim().isNotEmpty ||
            r.amountCtrl.text.trim().isNotEmpty ||
            r.commentCtrl.text.trim().isNotEmpty)
          {
            'type': r.typeCtrl.text.trim(),
            'amount': r.amountCtrl.text.trim(),
            'comment': r.commentCtrl.text.trim(),
          },
    ];
  }

  void _addFeeRow() {
    setState(() => _feeRows.add(_FeeRow()));
    _syncFeeRows();
  }

  void _removeFeeRow(int index) {
    final removed = _feeRows.removeAt(index);
    removed.typeCtrl.dispose();
    removed.amountCtrl.dispose();
    removed.commentCtrl.dispose();
    setState(() {});
    _syncFeeRows();
  }

  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return int.tryParse(v.trim()) == null
        ? 'Enter a whole number (rupees)'
        : null;
  }

  /// An amount field that only accepts whole (integer) rupee amounts.
  Widget _amountField(
    TextEditingController ctrl,
    String label, {
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        label: Text(label),
        hintText: 'Whole rupees only',
        prefixIcon: const Icon(
          Icons.currency_rupee,
          size: 18,
          color: Color(0xFF1A3C6E),
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
      validator: _validateAmount,
      onChanged: onChanged,
    );
  }

  /// Builds one "other fee" row (type / amount / comment) with a remove
  /// button.
  Widget _buildFeeRow(int index) {
    final row = _feeRows[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fee ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeFeeRow(index),
                tooltip: 'Remove this fee',
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.red,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          TextFormField(
            controller: row.typeCtrl,
            decoration: InputDecoration(
              label: const Text('Fee Type'),
              hintText: 'e.g. Hostel, Transport, Caution Money',
            ),
            onChanged: (_) => _syncFeeRows(),
          ),
          const SizedBox(height: 12),
          _amountField(
            row.amountCtrl,
            'Amount',
            onChanged: (_) => _syncFeeRows(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: row.commentCtrl,
            decoration: InputDecoration(
              label: const Text('Comment'),
              hintText: 'Optional note (e.g. paid, pending…)',
            ),
            maxLines: 2,
            onChanged: (_) => _syncFeeRows(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(title: 'Course Details', icon: Icons.menu_book),

          TextFormField(
            decoration: InputDecoration(label: Text('Student ID')),
            controller: _studentIdCtrl,
            validator: (v) =>
                v == null || v.isEmpty ? 'Student ID is required' : null,
            onChanged: (v) => widget.student.studentId = v,
          ),

          FormDropdown(
            label: 'Name of Course',
            value: widget.student.nameOfCourse,
            isRequired: true,
            items: listOfCourses,
            validator: (v) =>
                v == null || v.isEmpty ? 'Course is required' : null,
            onChanged: (v) =>
                setState(() => widget.student.nameOfCourse = v ?? ''),
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('Year of Admission')),
            controller: _yearCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: (v) {
              if (v != null && v.isNotEmpty) {
                final year = int.tryParse(v);
                if (year == null ||
                    year < 1990 ||
                    year > DateTime.now().year + 1) {
                  return 'Enter valid admission year';
                }
              }
              return null;
            },
            onChanged: (v) => widget.student.yearOfAdmission = int.tryParse(v),
          ),

          TextFormField(
            decoration: InputDecoration(
              label: Text('Placement Details (Ex-students only)'),
              hint: Text('Company, role, year, etc.'),
            ),
            controller: _placementCtrl,
            maxLines: 2,
            onChanged: (v) => widget.student.placementDetails = v,
          ),

          const SectionHeader(title: 'Fee Details', icon: Icons.currency_rupee),

          _amountField(
            _fee1Ctrl,
            'Fee – 1st Year',
            onChanged: (v) => widget.student.feeDetails1stYear = v,
          ),
          const SizedBox(height: 16),
          _amountField(
            _fee2Ctrl,
            'Fee – 2nd Year',
            onChanged: (v) => widget.student.feeDetails2ndYear = v,
          ),
          const SizedBox(height: 16),
          _amountField(
            _fee3Ctrl,
            'Fee – 3rd Year',
            onChanged: (v) => widget.student.feeDetails3rdYear = v,
          ),

          const SizedBox(height: 20),
          const Text(
            'Other Fees',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A3C6E),
            ),
          ),
          const SizedBox(height: 4),
          if (_feeRows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No other fees added. Tap "Add Fee" to record extra fee types '
                'such as hostel, transport, etc.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          for (var i = 0; i < _feeRows.length; i++) ...[
            _buildFeeRow(i),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addFeeRow,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Fee'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A3C6E),
                side: const BorderSide(color: Color(0xFF1A3C6E)),
              ),
            ),
          ),

          const SizedBox(height: 12),
          const SectionHeader(
            title: 'Additional Files',
            icon: Icons.folder_open,
          ),

          MultiFilePicker(
            label: 'Supporting Files',
            filePaths: widget.student.otherFileNames,
            onFileAdded: (data, name) {
              setState(() {
                widget.student.otherFileData = [
                  ...widget.student.otherFileData,
                  data,
                ];
                widget.student.otherFileNames = [
                  ...widget.student.otherFileNames,
                  name,
                ];
              });
            },
            onFileRemoved: (i) => setState(() {
              final list = [...widget.student.otherFileData];
              final list2 = [...widget.student.otherFileNames];
              list.removeAt(i);
              list2.removeAt(i);
              widget.student.otherFileData = list;
              widget.student.otherFileNames = list2;
            }),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
