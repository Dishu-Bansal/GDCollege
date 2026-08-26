import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../repositories/staff_repository.dart';
import '../../staff_management/models/staff_model.dart';
import '../models/visitor_models.dart';
import '../repositories/visitor_repository.dart';

/// Creates a check-in entry for a staff member or an external visitor.
/// Checking in stamps the current time automatically.
class VisitorEntryFormScreen extends ConsumerStatefulWidget {
  const VisitorEntryFormScreen({super.key});

  @override
  ConsumerState<VisitorEntryFormScreen> createState() =>
      _VisitorEntryFormScreenState();
}

class _VisitorEntryFormScreenState
    extends ConsumerState<VisitorEntryFormScreen> {
  VisitorRepository get _visitorService =>
      ref.read(visitorRepositoryProvider);
  StaffRepository get _staffService => ref.read(staffRepositoryProvider);

  // Staff mode
  bool _isStaff = false;
  StaffModel? _selectedStaff;
  List<StaffModel> _staff = [];

  // Visitor mode
  final _nameCtrl = TextEditingController();
  List<VisitorModel> _visitors = [];

  // Entry details
  final _vehicleCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final List<TextEditingController> _accompanyingCtrls = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _staffService.watchNames().first.then((s) {
      if (mounted) setState(() => _staff = s);
    });
    _visitorService.watchVisitors().first.then((v) {
      if (mounted) setState(() => _visitors = v);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vehicleCtrl.dispose();
    _purposeCtrl.dispose();
    _fromCtrl.dispose();
    for (final c in _accompanyingCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addAccompanying() {
    setState(() => _accompanyingCtrls.add(TextEditingController()));
  }

  void _removeAccompanying(int i) {
    final c = _accompanyingCtrls.removeAt(i);
    c.dispose();
    setState(() {});
  }

  List<String> get _accompanyingNames => _accompanyingCtrls
      .map((c) => c.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  /// Previous visitors whose name matches the typed text (for autocomplete).
  List<VisitorModel> get _nameSuggestions {
    final q = _nameCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _visitors
        .where((v) => v.name.toLowerCase().contains(q))
        .take(5)
        .toList();
  }

  void _pickSuggestion(VisitorModel v) {
    setState(() {
      _nameCtrl.text = v.name;
      _nameCtrl.selection =
          TextSelection.collapsed(offset: _nameCtrl.text.length);
    });
  }

  Future<void> _checkIn() async {
    if (_saving) return;
    final name = _isStaff ? _selectedStaff?.name : _nameCtrl.text.trim();
    if (name == null || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_isStaff ? 'Select a staff member' : 'Enter the visitor name')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _visitorService.checkIn(
        isStaff: _isStaff,
        staffId: _selectedStaff?.docId,
        name: name,
        vehicleNumber: _vehicleCtrl.text,
        purpose: _purposeCtrl.text,
        fromPlace: _fromCtrl.text,
        accompanyingPeople: _accompanyingNames,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      final now = DateTime.now();
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      messenger.showSnackBar(
        SnackBar(content: Text('$name checked in at $time')),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check in failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Check In',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Person type
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Visitor'),
                    icon: Icon(Icons.person_outline),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Staff'),
                    icon: Icon(Icons.badge_outlined),
                  ),
                ],
                selected: {_isStaff},
                onSelectionChanged: (s) =>
                    setState(() => _isStaff = s.first),
              ),
              const SizedBox(height: 16),

              // Name / staff picker
              if (_isStaff)
                _buildStaffPicker()
              else
                _buildVisitorNameField(),
              const SizedBox(height: 12),

              // Car license plate
              TextField(
                controller: _vehicleCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Car License Plate (optional)',
                  hintText: 'e.g. HR 26 AB 1234',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Purpose of visit
              TextField(
                controller: _purposeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Visit (optional)',
                  prefixIcon: Icon(Icons.info_outline),
                ),
              ),
              const SizedBox(height: 12),

              // Where they are from
              TextField(
                controller: _fromCtrl,
                decoration: const InputDecoration(
                  labelText: 'Where are they from? (optional)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Accompanying people
              Row(children: [
                const Text('Accompanying People',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addAccompanying,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Add Person'),
                ),
              ]),
              if (_accompanyingCtrls.isEmpty)
                Text('No accompanying people added',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              for (var i = 0; i < _accompanyingCtrls.length; i++) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _accompanyingCtrls[i],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Name ${i + 1}',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeAccompanying(i),
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                    tooltip: 'Remove',
                  ),
                ]),
              ],

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _checkIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Check In',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
      ),
    );
  }

  Widget _buildStaffPicker() {
    if (_staff.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'No staff members found. Add staff from Staff Management first.',
          style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
        ),
      );
    }
    return DropdownButtonFormField<StaffModel>(
      initialValue: _selectedStaff,
      decoration: const InputDecoration(
        labelText: 'Staff Member',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      items: _staff
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s.designation != null && s.designation!.isNotEmpty
                      ? '${s.name} — ${s.designation}'
                      : s.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: (s) => setState(() => _selectedStaff = s),
    );
  }

  Widget _buildVisitorNameField() {
    final suggestions = _nameSuggestions;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Visitor Name',
          hintText: 'Start typing to see previous visitors',
          prefixIcon: Icon(Icons.person_outline),
        ),
        onChanged: (_) => setState(() {}),
      ),
      if (suggestions.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(children: [
            for (final v in suggestions)
              ListTile(
                dense: true,
                leading: const Icon(Icons.history, size: 18),
                title: Text(v.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  '${v.visitCount} visit${v.visitCount == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                onTap: () => _pickSuggestion(v),
              ),
          ]),
        ),
      ],
    ]);
  }
}
