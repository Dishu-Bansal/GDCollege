import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/file_picker_widget.dart';

class Step1PersonalInfo extends StatefulWidget {
  final StudentModel student;
  final GlobalKey<FormState> formKey;

  const Step1PersonalInfo({
    super.key,
    required this.student,
    required this.formKey,
  });

  @override
  State<Step1PersonalInfo> createState() => _Step1PersonalInfoState();
}

class _Step1PersonalInfoState extends State<Step1PersonalInfo> {
  late TextEditingController _nameCtrl;
  late TextEditingController _fatherCtrl;
  late TextEditingController _motherCtrl;
  late TextEditingController _dobCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.student.name);
    _fatherCtrl = TextEditingController(text: widget.student.fatherName);
    _motherCtrl = TextEditingController(text: widget.student.motherName);
    _dobCtrl = TextEditingController(
      text: widget.student.dob != null
          ? '${widget.student.dob!.day}/${widget.student.dob!.month}/${widget.student.dob!.year}'
          : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fatherCtrl.dispose();
    _motherCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.student.dob ?? DateTime(2000),
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
        widget.student.dob = date;
        _dobCtrl.text = '${date.day}/${date.month}/${date.year}';
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
          const SectionHeader(title: 'Basic Details', icon: Icons.person),

          TextFormField(
            decoration: InputDecoration(label: Text("Full Name")),
            controller: _nameCtrl,
            validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
            onChanged: (v) => widget.student.name = v,
          ),

          TextFormField(
            decoration: InputDecoration(label: Text("Father's Name")),
            controller: _fatherCtrl,
            validator: (v) =>
                v == null || v.isEmpty ? "Father's name is required" : null,
            onChanged: (v) => widget.student.fatherName = v,
          ),

          TextFormField(
            decoration: InputDecoration(label: Text("Mother's Name")),
            controller: _motherCtrl,
            validator: (v) =>
                v == null || v.isEmpty ? "Mother's name is required" : null,
            onChanged: (v) => widget.student.motherName = v,
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('Date of Birth'), suffixIcon: const Icon(Icons.calendar_today, size: 18),),
            controller: _dobCtrl,
            readOnly: true,
            onTap: _pickDate,
            validator: (v) =>
                v == null || v.isEmpty ? 'Date of birth is required' : null,
          ),

          FormDropdown(
            label: 'Gender',
            value: widget.student.gender,
            isRequired: true,
            items: const ['Male', 'Female', 'Other'],
            validator: (v) =>
                v == null || v.isEmpty ? 'Gender is required' : null,
            onChanged: (v) => setState(() => widget.student.gender = v ?? ''),
          ),

          FormDropdown(
            label: 'Caste',
            value: widget.student.caste,
            items: const ['General', 'OBC', 'SC', 'ST', 'EWS', 'Other'],
            onChanged: (v) => setState(() => widget.student.caste = v ?? ''),
          ),

          const SectionHeader(title: 'Photo', icon: Icons.photo_camera),

          FilePicker(
            label: 'Student Photo',
            filePath: widget.student.photoData,
            filename: widget.student.photoName,
            imageOnly: true,
            isRequired: true,
            onFilePicked: (path, name) =>
                setState(() {widget.student.photoData = path; widget.student.photoName = name;}),
            onFileRemoved: () =>
                setState(() {widget.student.photoData = null;
              widget.student.photoName = null;
            }),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

extension _FieldCallback on FormTextField {
  // ignore: unused_element
  static FormTextField withCallback(
      {required String label,
      required TextEditingController controller,
      bool isRequired = false,
      String? Function(String?)? validator,
      required void Function(String) onChanged}) {
    return FormTextField(
      label: label,
      controller: controller,
      isRequired: isRequired,
      validator: validator,
    );
  }
}
