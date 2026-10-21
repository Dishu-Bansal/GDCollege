import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/file_picker_widget.dart';

/// Step 5: educational qualification scans and extra supporting files.
/// The bottom bar's Save/Submit button finishes the wizard from here.
class Step5EducationFiles extends StatefulWidget {
  final StudentModel student;
  final GlobalKey<FormState> formKey;

  const Step5EducationFiles({
    super.key,
    required this.student,
    required this.formKey,
  });

  @override
  State<Step5EducationFiles> createState() => _Step5EducationFilesState();
}

class _Step5EducationFilesState extends State<Step5EducationFiles> {
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
            filePath: widget.student.tenthData,
            filename: widget.student.tenthName,
            existingUrl: widget.student.tenthUrl,
            onExistingRemoved: () => setState(() {
              widget.student.tenthData = null;
              widget.student.tenthName = null;
              widget.student.tenthUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.tenthData = data;
              widget.student.tenthName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.tenthData = null;
              widget.student.tenthName = null;
            }),
          ),

          FilePicker(
            label: '12th / Intermediate / Higher Secondary',
            filePath: widget.student.twelfthData,
            filename: widget.student.twelfthName,
            existingUrl: widget.student.twelfthUrl,
            onExistingRemoved: () => setState(() {
              widget.student.twelfthData = null;
              widget.student.twelfthName = null;
              widget.student.twelfthUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.twelfthData = data;
              widget.student.twelfthName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.twelfthData = null;
              widget.student.twelfthName = null;
            }),
          ),

          FilePicker(
            label: 'Graduation/Bachelor\'s Degree',
            filePath: widget.student.graduationData,
            filename: widget.student.graduationName,
            existingUrl: widget.student.graduationUrl,
            onExistingRemoved: () => setState(() {
              widget.student.graduationData = null;
              widget.student.graduationName = null;
              widget.student.graduationUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.graduationData = data;
              widget.student.graduationName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.graduationData = null;
              widget.student.graduationName = null;
            }),
          ),

          FilePicker(
            label: 'Post Graduation/Master\'s Degree',
            filePath: widget.student.postGraduationData,
            filename: widget.student.postGraduationName,
            existingUrl: widget.student.postGraduationUrl,
            onExistingRemoved: () => setState(() {
              widget.student.postGraduationData = null;
              widget.student.postGraduationName = null;
              widget.student.postGraduationUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.postGraduationData = data;
              widget.student.postGraduationName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.postGraduationData = null;
              widget.student.postGraduationName = null;
            }),
          ),

          FilePicker(
            label: 'Diploma/Vocational',
            filePath: widget.student.diplomaData,
            filename: widget.student.diplomaName,
            existingUrl: widget.student.diplomaUrl,
            onExistingRemoved: () => setState(() {
              widget.student.diplomaData = null;
              widget.student.diplomaName = null;
              widget.student.diplomaUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.diplomaData = data;
              widget.student.diplomaName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.diplomaData = null;
              widget.student.diplomaName = null;
            }),
          ),

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

          const SizedBox(height: 12),
          Text(
            'Use Save below to store the student record.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
