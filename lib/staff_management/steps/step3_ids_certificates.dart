import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/staff_model.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/file_picker_widget.dart';

class Step3IdsAndCertificates extends StatefulWidget {
  final StaffModel staff;
  final GlobalKey<FormState> formKey;

  const Step3IdsAndCertificates({
    super.key,
    required this.staff,
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
    _aadharCtrl = TextEditingController(text: widget.staff.aadharNumber);
    _panCtrl = TextEditingController(text: widget.staff.panCard);
    _familyIdCtrl = TextEditingController(text: widget.staff.familyId);
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
                widget.staff.aadharNumber = v.replaceAll(' ', ''),
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
            onChanged: (v) => widget.staff.panCard = v,
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('Family ID'), hint: Text('Optional for other states')),
            controller: _familyIdCtrl,
            onChanged: (v) => widget.staff.familyId = v,
          ),

          const SectionHeader(
              title: 'Documents', icon: Icons.file_present),

          FilePicker(
            label: 'Aadhar Card',
            filePath: widget.staff.aadharData,
            filename: widget.staff.aadharName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.aadharData = data; widget.staff.aadharName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.aadharData = null; widget.staff.aadharName = null;}),
          ),
          FilePicker(
            label: 'PAN Card',
            filePath: widget.staff.panData,
            filename: widget.staff.panName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.panData = data; widget.staff.panName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.panData = null; widget.staff.panName = null;}),
          ),

          FilePicker(
            label: 'SC Certificate',
            filePath: widget.staff.scCertificateData,
            filename: widget.staff.scCertificateName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.scCertificateData = data; widget.staff.scCertificateName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.scCertificateData = null; widget.staff.scCertificateName = null;}),
          ),

          FilePicker(
            label: 'BC Certificate',
            filePath: widget.staff.bcCertificateData,
            filename: widget.staff.bcCertificateName,
            onFilePicked: (data, name) =>
                setState(() { widget.staff.bcCertificateData = data; widget.staff.bcCertificateName = name;}),
            onFileRemoved: () =>
                setState(() { widget.staff.bcCertificateData = null; widget.staff.bcCertificateName = null;}),
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
