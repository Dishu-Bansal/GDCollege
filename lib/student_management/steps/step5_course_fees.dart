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

class _Step5CourseAndFeesState extends State<Step5CourseAndFees> {
  late final TextEditingController _studentIdCtrl;
  late final TextEditingController _placementCtrl;
  late final TextEditingController _fee1Ctrl;
  late final TextEditingController _fee2Ctrl;
  late final TextEditingController _fineCtrl;
  late final TextEditingController _examFeeCtrl;
  late final TextEditingController _yearCtrl;

  @override
  void initState() {
    super.initState();
    _studentIdCtrl = TextEditingController(text: widget.student.studentId);
    _placementCtrl =
        TextEditingController(text: widget.student.placementDetails);
    _fee1Ctrl =
        TextEditingController(text: widget.student.feeDetails1stYear);
    _fee2Ctrl =
        TextEditingController(text: widget.student.feeDetails2ndYear);
    _fineCtrl = TextEditingController(text: widget.student.fineIfAny);
    _examFeeCtrl = TextEditingController(text: widget.student.examFee);
    _yearCtrl = TextEditingController(
        text: widget.student.yearOfAdmission?.toString() ?? '');
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _placementCtrl.dispose();
    _fee1Ctrl.dispose();
    _fee2Ctrl.dispose();
    _fineCtrl.dispose();
    _examFeeCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(
              title: 'Course Details', icon: Icons.menu_book),

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
            onChanged: (v) =>
                widget.student.yearOfAdmission = int.tryParse(v),
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('Placement Details (Ex-students only)'), hint: Text('Company, role, year, etc.')),
            controller: _placementCtrl,
            maxLines: 2,
            onChanged: (v) => widget.student.placementDetails = v,
          ),

          const SectionHeader(title: 'Fee Details', icon: Icons.currency_rupee),

          TextFormField(
            decoration: InputDecoration(label: Text('Fee Details – 1st Year'), hint: Text('Amount paid / pending'),),
            controller: _fee1Ctrl,
            onChanged: (v) => widget.student.feeDetails1stYear = v,
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('Fee Details – 2nd Year'), hint: Text('Amount paid / pending'),),
            controller: _fee2Ctrl,
            onChanged: (v) => widget.student.feeDetails2ndYear = v,
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('Fine (if any)'), hint: Text('Reason and amount')),
            controller: _fineCtrl,
            onChanged: (v) => widget.student.fineIfAny = v,
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('Exam Fee'), hint: Text('Paid / Not Paid / Amount'),),
            controller: _examFeeCtrl,
            onChanged: (v) => widget.student.examFee = v,
          ),

          const SectionHeader(title: 'Additional Files', icon: Icons.folder_open),

          MultiFilePicker(
            label: 'Supporting Files',
            filePaths: widget.student.otherFileNames,
            onFileAdded: (data, name) {setState(() {
              widget.student.otherFileData = [
                ...widget.student.otherFileData,
                data
              ];
              widget.student.otherFileNames = [
                ...widget.student.otherFileNames,
                name
              ];
            });},
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
