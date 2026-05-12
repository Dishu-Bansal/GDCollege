import 'package:flutter/material.dart';
import '../models/staff_model.dart';
import '../../../services/firebase_staff_service.dart';
import '../../../widgets/step_indicator.dart';
import '../../../staff_management/steps/step1_personal_info.dart';
import '../../../staff_management/steps/step2_address.dart';
import '../../../staff_management/steps/step3_ids_certificates.dart';
import '../../../staff_management/steps/step4_education.dart';
import '../../../staff_management/steps/step5_course_fees.dart';

class StaffFormScreen extends StatefulWidget {
  /// Pass an existing student to enter edit mode; leave null for create mode.
  final StaffModel? existingStaff;

  const StaffFormScreen({super.key, this.existingStaff});

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final PageController _pageController = PageController();
  final FirebaseService _firebaseService = FirebaseService();
  late final StaffModel _staff;

  bool get _isEditMode => widget.existingStaff != null;

  int _currentStep = 1;
  final int _totalSteps = 5;
  bool _isSubmitting = false;
  String _uploadStatus = '';

  // One form key per step
  final List<GlobalKey<FormState>> _formKeys =
      List.generate(5, (_) => GlobalKey<FormState>());

  static const List<String> _stepTitles = [
    'Personal Info',
    'Address & Contact',
    'IDs & Certificates',
    'Education',
    'Course & Fees',
  ];

  @override
  void initState() {
    super.initState();
    // In edit mode, clone the existing student so we don't mutate the original
    // until the user saves.
    _staff = _isEditMode ? widget.existingStaff!.clone() : StaffModel();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    final key = _formKeys[_currentStep - 1];
    if (key.currentState?.validate() ?? true) {
      if (_currentStep < _totalSteps) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        await _submitForm();
      }
    }
  }

  void _goPrev() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitForm() async {
    setState(() {
      _isSubmitting = true;
      _uploadStatus = 'Preparing upload...';
    });

    try {

      String docId;

      if (_isEditMode) {
        // UPDATE path
        docId = widget.existingStaff!.docId!;
        setState(() => _uploadStatus = 'Uploading new files…');
        await _firebaseService.uploadStaffFiles(
          _staff,
          docId,
          onProgress: (label, p) => setState(
                  () => _uploadStatus = '$label: ${(p * 100).toStringAsFixed(0)}%'),
        );
        setState(() => _uploadStatus = 'Saving changes…');
        await _firebaseService.updateStaff(docId, _staff);
      } else {
        // 1. Save basic record to get a Firestore ID
        final docId = await _firebaseService.saveStaff(_staff);

        // 2. Upload files
        setState(() => _uploadStatus = 'Uploading files...');
        await _firebaseService.uploadStaffFiles(
          _staff,
          docId,
          onProgress: (label, progress) {
            setState(() =>
            _uploadStatus = '$label: ${(progress * 100).toStringAsFixed(0)}%');
          },
        );

        // 3. Update record with file URLs
        setState(() => _uploadStatus = 'Saving final data...');
        await _firebaseService.updateStaff(docId, _staff);
      }
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog(_isEditMode);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(bool wasEdit) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF1A3C6E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              wasEdit ? 'Staff Updated!' : 'Staff Registered!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3C6E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              wasEdit
                  ? 'Changes saved successfully.'
                  : 'New record created successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          if (!wasEdit)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => const StaffFormScreen()),
                );
              },
              child: const Text('Add Another'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // return to list
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Staff' : 'Staff Registration',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: _currentStep > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goPrev,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Step indicator
              StepIndicator(
                currentStep: _currentStep,
                totalSteps: _totalSteps,
                stepTitles: _stepTitles,
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Step1PersonalInfo(
                        staff: _staff, formKey: _formKeys[0]),
                    Step2Address(
                        staff: _staff, formKey: _formKeys[1]),
                    Step3IdsAndCertificates(
                        staff: _staff, formKey: _formKeys[2]),
                    Step4Education(
                        staff: _staff, formKey: _formKeys[3]),
                    Step5CourseAndFees(
                        staff: _staff, formKey: _formKeys[4]),
                  ],
                ),
              ),

              // Bottom navigation
              _buildBottomBar(),
            ],
          ),

          // Upload overlay
          if (_isSubmitting) _buildUploadOverlay(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 1)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _goPrev,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A3C6E),
                  side: const BorderSide(color: Color(0xFF1A3C6E)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          if (_currentStep > 1) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _goNext,
              icon: Icon(
                _currentStep == _totalSteps
                    ? (_isEditMode ? Icons.save : Icons.cloud_upload)
                    : Icons.arrow_forward,
                size: 18,
              ),
              label: Text(
                _currentStep == _totalSteps ? (_isEditMode ? 'Save Changes' : 'Submit') : 'Next',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1A3C6E)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isEditMode ? 'Saving Changes' : 'Registering Student',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A3C6E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _uploadStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Help'),
        content: const Text(
          '• Fields marked with * are required.\n'
          '• Upload photo in JPG or PNG format.\n'
          '• Certificates can be PDF, JPG or PNG.\n'
          '• Family ID is optional for students from other states.\n'
          '• Data is saved securely to Firebase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
