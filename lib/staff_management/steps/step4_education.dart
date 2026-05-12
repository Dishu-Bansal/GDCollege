import 'package:flutter/material.dart';
import '../models/staff_model.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/file_picker_widget.dart';

class Step4Education extends StatefulWidget {
  final StaffModel staff;
  final GlobalKey<FormState> formKey;

  const Step4Education({
    super.key,
    required this.staff,
    required this.formKey,
  });

  @override
  State<Step4Education> createState() => _Step4EducationState();
}

class _Step4EducationState extends State<Step4Education> {

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
              title: 'Educational Qualifications', icon: Icons.school),

          FilePicker(
            label: '10th/High School/Matriculation',
            filePath: widget.staff.tenthData,
            filename: widget.staff.tenthName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.tenthData = data; widget.staff.tenthName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.tenthData = null; widget.staff.tenthName = null;}),
          ),

          FilePicker(
            label: '12th / Intermediate / Higher Secondary',
            filePath: widget.staff.twelfthData,
            filename: widget.staff.twelfthName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.twelfthData = data; widget.staff.twelfthName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.twelfthData = null; widget.staff.twelfthName = null;}),
          ),

          FilePicker(
            label: 'Graduation/Bachelor\'s Degree',
            filePath: widget.staff.graduationData,
            filename: widget.staff.graduationName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.graduationData = data; widget.staff.graduationName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.graduationData = null; widget.staff.graduationName = null;}),
          ),

          FilePicker(
            label: 'Post Graduation/Master\'s Degree',
            filePath: widget.staff.postGraduationData,
            filename: widget.staff.postGraduationName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.postGraduationData = data; widget.staff.postGraduationName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.postGraduationData = null; widget.staff.postGraduationName = null;}),
          ),

          FilePicker(
            label: 'Diploma/Vocational',
            filePath: widget.staff.diplomaData,
            filename: widget.staff.diplomaName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.diplomaData = data; widget.staff.diplomaName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.diplomaData = null; widget.staff.diplomaName = null;}),
          ),

          FilePicker(
            label: 'PHD',
            filePath: widget.staff.phdData,
            filename: widget.staff.phdName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.phdData = data; widget.staff.phdName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.phdData = null; widget.staff.phdName = null;}),
          ),

          FilePicker(
            label: 'NET',
            filePath: widget.staff.netData,
            filename: widget.staff.netName,
            onFilePicked: (data, name) =>
                setState(() {widget.staff.netData = data; widget.staff.netName = name;}),
            onFileRemoved: () =>
                setState(() {widget.staff.netData = null; widget.staff.netName = null;}),
          ),

          MultiFilePicker(
            label: 'Experience Certificates',
            filePaths: widget.staff.experienceCertificatesNames,
            onFileAdded: (data, name) {setState(() {
              widget.staff.experienceCertificateData = [
                ...widget.staff.experienceCertificateData,
                data
              ];
              widget.staff.experienceCertificatesNames = [
                ...widget.staff.experienceCertificatesNames,
                name
              ];
            });},
            onFileRemoved: (i) => setState(() {
              final list = [...widget.staff.experienceCertificateData];
              final list2 = [...widget.staff.experienceCertificatesNames];
              list.removeAt(i);
              list2.removeAt(i);
              widget.staff.experienceCertificateData = list;
              widget.staff.experienceCertificatesNames = list2;
            }),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _QualificationTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final IconData icon;
  final void Function(String) onChanged;

  const _QualificationTile({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.icon,
    required this.onChanged,
  });

  @override
  State<_QualificationTile> createState() => _QualificationTileState();
}

class _QualificationTileState extends State<_QualificationTile> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.controller.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: _expanded
              ? const Color(0xFF1A3C6E).withOpacity(0.4)
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(10),
        color: _expanded
            ? const Color(0xFF1A3C6E).withOpacity(0.03)
            : Colors.grey.shade50,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _expanded
                          ? const Color(0xFF1A3C6E)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: _expanded ? Colors.white : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _expanded
                                ? const Color(0xFF1A3C6E)
                                : Colors.black87,
                          ),
                        ),
                        if (widget.controller.text.isNotEmpty)
                          Text(
                            widget.controller.text,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade400),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: TextFormField(
                controller: widget.controller,
                onChanged: widget.onChanged,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText:
                      'Enter board/university, year, percentage/grade...',
                  hintStyle: TextStyle(
                      fontSize: 12, color: Colors.grey.shade400),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
