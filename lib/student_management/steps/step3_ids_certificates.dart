import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/student_model.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/file_picker_widget.dart';

class Step3IdsAndCertificates extends StatefulWidget {
  final StudentModel student;
  final GlobalKey<FormState> formKey;

  const Step3IdsAndCertificates({
    super.key,
    required this.student,
    required this.formKey,
  });

  @override
  State<Step3IdsAndCertificates> createState() =>
      _Step3IdsAndCertificatesState();
}

class _Step3IdsAndCertificatesState extends State<Step3IdsAndCertificates> {
  late final TextEditingController _aadharCtrl;
  late final TextEditingController _panCtrl;
  late final TextEditingController _familyIdCtrl;

  @override
  void initState() {
    super.initState();
    _aadharCtrl = TextEditingController(text: widget.student.aadharNumber);
    _panCtrl = TextEditingController(text: widget.student.panCard);
    _familyIdCtrl = TextEditingController(text: widget.student.familyId);
  }

  @override
  void dispose() {
    _aadharCtrl.dispose();
    _panCtrl.dispose();
    _familyIdCtrl.dispose();
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
              title: 'Identity Documents', icon: Icons.badge),

          TextFormField(
            decoration: InputDecoration(label: Text('Aadhar Number'), hint: Text('XXXX XXXX XXXX')),
            controller: _aadharCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
              _AadharFormatter(),
            ],
            validator: (v) {
              final clean = v?.replaceAll(' ', '') ?? '';
              if (clean.isEmpty) return 'Aadhar number is required';
              if (clean.length != 12) return 'Enter valid 12-digit Aadhar';
              return null;
            },
            onChanged: (v) =>
                widget.student.aadharNumber = v.replaceAll(' ', ''),
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('PAN Card Number'), hint: Text('ABCDE1234F')),
            controller: _panCtrl,
            inputFormatters: [
              UpperCaseTextFormatter(),
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (v) {
              if (v != null && v.isNotEmpty) {
                final regex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
                if (!regex.hasMatch(v)) return 'Enter valid PAN (ABCDE1234F)';
              }
              return null;
            },
            onChanged: (v) => widget.student.panCard = v,
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('Family ID'), hint: Text('Optional for other states')),
            controller: _familyIdCtrl,
            onChanged: (v) => widget.student.familyId = v,
          ),

          const SectionHeader(
              title: 'Documents', icon: Icons.file_present),

          FilePicker(
            label: 'Aadhar Card',
            filePath: widget.student.aadharData,
            filename: widget.student.aadharName,
            onFilePicked: (data, name) =>
                setState(() {widget.student.aadharData = data; widget.student.aadharName = name;}),
            onFileRemoved: () =>
                setState(() {widget.student.aadharData = null; widget.student.aadharName = null;}),
          ),
          FilePicker(
            label: 'PAN Card',
            filePath: widget.student.panData,
            filename: widget.student.panName,
            onFilePicked: (data, name) =>
                setState(() {widget.student.panData = data; widget.student.panName = name;}),
            onFileRemoved: () =>
                setState(() {widget.student.panData = null; widget.student.panName = null;}),
          ),

          FilePicker(
            label: 'SC Certificate',
            filePath: widget.student.scCertificateData,
            filename: widget.student.scCertificateName,
            onFilePicked: (data, name) =>
                setState(() {widget.student.scCertificateData = data; widget.student.scCertificateName = name;}),
            onFileRemoved: () =>
                setState(() {widget.student.scCertificateData = null; widget.student.scCertificateName = null;}),
          ),

          FilePicker(
            label: 'BC Certificate',
            filePath: widget.student.bcCertificateData,
            filename: widget.student.bcCertificateName,
            onFilePicked: (data, name) =>
                setState(() { widget.student.bcCertificateData = data; widget.student.bcCertificateName = name;}),
            onFileRemoved: () =>
                setState(() { widget.student.bcCertificateData = null; widget.student.bcCertificateName = null;}),
          ),

          FilePicker(
            label: 'Sports Certificate',
            filePath: widget.student.sportsCertificateData,
            filename: widget.student.sportsCertificateName,
            onFilePicked: (data, name) =>
                setState(() {widget.student.sportsCertificateData = data; widget.student.sportsCertificateName = name;}),
            onFileRemoved: () =>
                setState(() {widget.student.sportsCertificateData = null; widget.student.sportsCertificateName = null;}),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _AadharFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 4 || i == 8) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return newValue.copyWith(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

extension on FormTextField {
  void Function(String) get onChanged => (_) {};
}
