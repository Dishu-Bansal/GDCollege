import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/file_picker_widget.dart';

/// Step 4: identity documents.
///
/// The admission year was captured in step 3, so the Aadhar requirement can
/// be limited to 2016+ admissions here. PAN is required for every student.
class Step4IdentityDocuments extends StatefulWidget {
  final StudentModel student;
  final GlobalKey<FormState> formKey;

  const Step4IdentityDocuments({
    super.key,
    required this.student,
    required this.formKey,
  });

  @override
  State<Step4IdentityDocuments> createState() =>
      _Step4IdentityDocumentsState();
}

class _Step4IdentityDocumentsState extends State<Step4IdentityDocuments> {
  static bool aadharNeeded(int? year) => year != null && year >= 2016;

  @override
  Widget build(BuildContext context) {
    final year = widget.student.yearOfAdmission;
    final aadharRequired = aadharNeeded(year);
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(
              title: 'Identity Documents', icon: Icons.file_present),

          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              aadharRequired
                  ? 'Aadhar Card is required for 2016+ admissions. '
                      'PAN Card is required for every student. '
                      'The other documents are optional.'
                  : 'Aadhar is not applicable for pre-2016 admissions. '
                      'PAN Card is required for every student. '
                      'The other documents are optional.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),

          FilePicker(
            label: 'Aadhar Card',
            isRequired: aadharRequired,
            filePath: widget.student.aadharData,
            filename: widget.student.aadharName,
            existingUrl: widget.student.aadharUrl,
            onExistingRemoved: () => setState(() {
              widget.student.aadharData = null;
              widget.student.aadharName = null;
              widget.student.aadharUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.aadharData = data;
              widget.student.aadharName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.aadharData = null;
              widget.student.aadharName = null;
            }),
          ),
          FilePicker(
            label: 'PAN Card',
            isRequired: true,
            filePath: widget.student.panData,
            filename: widget.student.panName,
            existingUrl: widget.student.panUrl,
            onExistingRemoved: () => setState(() {
              widget.student.panData = null;
              widget.student.panName = null;
              widget.student.panUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.panData = data;
              widget.student.panName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.panData = null;
              widget.student.panName = null;
            }),
          ),

          FilePicker(
            label: 'Family ID',
            filePath: widget.student.familyIdDocData,
            filename: widget.student.familyIdDocName,
            existingUrl: widget.student.familyIdDocUrl,
            onExistingRemoved: () => setState(() {
              widget.student.familyIdDocData = null;
              widget.student.familyIdDocName = null;
              widget.student.familyIdDocUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.familyIdDocData = data;
              widget.student.familyIdDocName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.familyIdDocData = null;
              widget.student.familyIdDocName = null;
            }),
          ),
          FilePicker(
            label: 'Haryana Residence Certificate',
            filePath: widget.student.haryanaResidenceData,
            filename: widget.student.haryanaResidenceName,
            existingUrl: widget.student.haryanaResidenceUrl,
            onExistingRemoved: () => setState(() {
              widget.student.haryanaResidenceData = null;
              widget.student.haryanaResidenceName = null;
              widget.student.haryanaResidenceUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.haryanaResidenceData = data;
              widget.student.haryanaResidenceName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.haryanaResidenceData = null;
              widget.student.haryanaResidenceName = null;
            }),
          ),
          FilePicker(
            label: 'ABC ID',
            filePath: widget.student.abcIdData,
            filename: widget.student.abcIdName,
            existingUrl: widget.student.abcIdUrl,
            onExistingRemoved: () => setState(() {
              widget.student.abcIdData = null;
              widget.student.abcIdName = null;
              widget.student.abcIdUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.abcIdData = data;
              widget.student.abcIdName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.abcIdData = null;
              widget.student.abcIdName = null;
            }),
          ),

          FilePicker(
            label: 'SC Certificate',
            filePath: widget.student.scCertificateData,
            filename: widget.student.scCertificateName,
            existingUrl: widget.student.scCertificateUrl,
            onExistingRemoved: () => setState(() {
              widget.student.scCertificateData = null;
              widget.student.scCertificateName = null;
              widget.student.scCertificateUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.scCertificateData = data;
              widget.student.scCertificateName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.scCertificateData = null;
              widget.student.scCertificateName = null;
            }),
          ),

          FilePicker(
            label: 'BC Certificate',
            filePath: widget.student.bcCertificateData,
            filename: widget.student.bcCertificateName,
            existingUrl: widget.student.bcCertificateUrl,
            onExistingRemoved: () => setState(() {
              widget.student.bcCertificateData = null;
              widget.student.bcCertificateName = null;
              widget.student.bcCertificateUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.bcCertificateData = data;
              widget.student.bcCertificateName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.bcCertificateData = null;
              widget.student.bcCertificateName = null;
            }),
          ),

          FilePicker(
            label: 'Sports Certificate',
            filePath: widget.student.sportsCertificateData,
            filename: widget.student.sportsCertificateName,
            existingUrl: widget.student.sportsCertificateUrl,
            onExistingRemoved: () => setState(() {
              widget.student.sportsCertificateData = null;
              widget.student.sportsCertificateName = null;
              widget.student.sportsCertificateUrl = null;
            }),
            onFilePicked: (data, name) => setState(() {
              widget.student.sportsCertificateData = data;
              widget.student.sportsCertificateName = name;
            }),
            onFileRemoved: () => setState(() {
              widget.student.sportsCertificateData = null;
              widget.student.sportsCertificateName = null;
            }),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
