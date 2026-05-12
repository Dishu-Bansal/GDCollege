import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gd_college/constants.dart';
import '../../widgets/increments.dart';
import '../models/staff_model.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/file_picker_widget.dart';

class Step5CourseAndFees extends StatefulWidget {
  final StaffModel staff;
  final GlobalKey<FormState> formKey;

  const Step5CourseAndFees({
    super.key,
    required this.staff,
    required this.formKey,
  });

  @override
  State<Step5CourseAndFees> createState() => _Step5CourseAndFeesState();
}

class _Step5CourseAndFeesState extends State<Step5CourseAndFees> {
  late final TextEditingController _staffIdCtrl;
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _designationCtrl;
  late final TextEditingController _dateOfJoiningCtrl;
  late final TextEditingController _dateOfRelievingCtrl;

  @override
  void initState() {
    super.initState();
    _staffIdCtrl = TextEditingController(text: widget.staff.staffId);
    _salaryCtrl = TextEditingController(text: widget.staff.salary.toString());
    _dateOfJoiningCtrl = TextEditingController(
      text: widget.staff.dateOfJoining != null
          ? '${widget.staff.dateOfJoining!.day}/${widget.staff.dateOfJoining!.month}/${widget.staff.dateOfJoining!.year}'
          : '',
    );
    _dateOfRelievingCtrl = TextEditingController(
      text: widget.staff.dateOfRelieving != null
          ? '${widget.staff.dateOfRelieving!.day}/${widget.staff.dateOfRelieving!.month}/${widget.staff.dateOfRelieving!.year}'
          : '',
    );
    _designationCtrl = TextEditingController(text: widget.staff.designation.toString());
  }

  @override
  void dispose() {
    _staffIdCtrl.dispose();
    _salaryCtrl.dispose();
    _dateOfJoiningCtrl.dispose();
    _dateOfRelievingCtrl.dispose();
    _designationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickJoiningDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.staff.dateOfJoining ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A3C6E),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        widget.staff.dateOfJoining = date;
        _dateOfJoiningCtrl.text = '${date.day}/${date.month}/${date.year}';
      });
    }
  }

  Future<void> _pickRelievingDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.staff.dateOfRelieving ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A3C6E),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        widget.staff.dateOfRelieving = date;
        _dateOfRelievingCtrl.text = '${date.day}/${date.month}/${date.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(
              title: 'Other Details', icon: Icons.menu_book),

          TextFormField(
            decoration: InputDecoration(label: Text('Staff ID')),
            controller: _staffIdCtrl,
            validator: (v) =>
                v == null || v.isEmpty ? 'staff ID is required' : null,
            onChanged: (v) => widget.staff.staffId = v,
          ),
          SizedBox(height: 10,),
          TextFormField(
            decoration: InputDecoration(label: Text('Designation')),
            controller: _designationCtrl,
            validator: (v) =>
            v == null || v.isEmpty ? 'Designation is required' : null,
            onChanged: (v) => widget.staff.designation = v,
          ),
          SizedBox(height: 10,),
          TextFormField(
            decoration: InputDecoration(label: Text('Salary')),
            controller: _salaryCtrl,
            validator: (v) =>
            v == null || v.isEmpty ? 'Salary is required' : null,
            onChanged: (v) => widget.staff.salary = v,
          ),
          SizedBox(height: 10,),
          FormDropdown(
            label: 'Name of Course',
            value: widget.staff.course,
            isRequired: true,
            items: listOfCourses,
            validator: (v) =>
            v == null || v.isEmpty ? 'Course is required' : null,
            onChanged: (v) =>
                setState(() => widget.staff.course = v ?? ''),
          ),
          SizedBox(height: 10,),
          TextFormField(
            decoration: InputDecoration(label: Text('Date of Joining'), suffixIcon: const Icon(Icons.calendar_today, size: 18),),
            controller: _dateOfJoiningCtrl,
            readOnly: true,
            onTap: _pickJoiningDate,
            validator: (v) =>
            v == null || v.isEmpty ? 'Date of birth is required' : null,
          ),
          SizedBox(height: 10,),
          TextFormField(
            decoration: InputDecoration(label: Text('Date of Relieving'), suffixIcon: const Icon(Icons.calendar_today, size: 18),),
            controller: _dateOfRelievingCtrl,
            readOnly: true,
            onTap: _pickRelievingDate,
          ),
          SizedBox(height: 10,),
          IncrementsList(
            entries: widget.staff.increments,
            onChanged: (updated) => setState(() => widget.staff.increments = updated),
          ),

          FilePicker(
            label: 'Appointment Letter',
            filePath: widget.staff.appointmentLetterData,
            filename: widget.staff.appointmentLetterName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.appointmentLetterData = data; widget.staff.appointmentLetterName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.appointmentLetterData = null; widget.staff.appointmentLetterName = null;}),
          ),

          FilePicker(
            label: 'Joining Letter',
            filePath: widget.staff.joiningLetterData,
            filename: widget.staff.joiningLetterName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.joiningLetterData = data; widget.staff.joiningLetterName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.joiningLetterData = null; widget.staff.joiningLetterName = null;}),
          ),

          FilePicker(
            label: 'University Approval',
            filePath: widget.staff.universityApprovalData,
            filename: widget.staff.universityApprovalName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.universityApprovalData = data; widget.staff.universityApprovalName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.universityApprovalData = null; widget.staff.universityApprovalName = null;}),
          ),

          FilePicker(
            label: 'Resignation Letter',
            filePath: widget.staff.resignationLetterData,
            filename: widget.staff.resignationLetterName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.resignationLetterData = data; widget.staff.resignationLetterName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.resignationLetterData = null; widget.staff.resignationLetterName = null;}),
          ),

          const SectionHeader(title: 'Additional Files', icon: Icons.folder_open),

          MultiFilePicker(
            label: 'Supporting Files',
            filePaths: widget.staff.otherFileNames,
            onFileAdded: (data, name) {setState(() {
              widget.staff.otherFileData = [
                ...widget.staff.otherFileData,
                data
              ];
              widget.staff.otherFileNames = [
                ...widget.staff.otherFileNames,
                name
              ];
            });},
            onFileRemoved: (i) => setState(() {
              final list = [...widget.staff.otherFileData];
              final list2 = [...widget.staff.otherFileNames];
              list.removeAt(i);
              list2.removeAt(i);
              widget.staff.otherFileData = list;
              widget.staff.otherFileNames = list2;
            }),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
