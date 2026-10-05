import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../repositories/staff_repository.dart';
import '../../staff_management/models/staff_model.dart';
import '../models/visitor_models.dart';
import '../repositories/visitor_repository.dart';
import '../widgets/visit_datetime_input.dart';

/// Creates a check-in entry for a staff member or an external visitor.
/// The check-in date, hour and minute are chosen by the user (defaults to
/// the current time).
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
  final _nameFocusNode = FocusNode();
  List<VisitorModel> _visitors = [];

  /// The visitor picked from the autocomplete list, if any. Only a picked
  /// suggestion reuses the visitor profile — anything else is a new visitor.
  VisitorModel? _selectedVisitor;

  /// Hides the name suggestions once one has been picked (or focus moved
  /// away), until the user edits the name again.
  bool _suggestionsDismissed = false;

  // Entry details
  final _vehicleCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final List<TextEditingController> _accompanyingCtrls = [];

  bool _saving = false;

  /// Chosen check-in moment (defaults to now, minute precision).
  late DateTime _checkInAt;

  /// Whether a check-out time is entered together with the check-in.
  bool _addCheckOut = false;

  /// Chosen check-out moment for a one-step completed entry.
  late DateTime _checkOutAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _checkInAt =
        DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _checkOutAt = _checkInAt;
    // Rebuild when the name field gains/loses focus so the suggestion list
    // appears and dismisses with focus.
    _nameFocusNode.addListener(_onNameFocusChanged);
    _staffService.watchNames().first.then((s) {
      if (mounted) setState(() => _staff = s);
    });
    _visitorService.watchVisitors().first.then((v) {
      if (mounted) setState(() => _visitors = v);
    });
  }

  void _onNameFocusChanged() {
    // Losing focus hides the suggestion list — but a tap on a suggestion
    // itself steals focus first, so delay the hide: a pick landing within
    // the window keeps the list alive long enough for onTap to fire.
    if (_nameFocusNode.hasFocus) {
      if (mounted) setState(() {});
      return;
    }
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted ||
          _nameFocusNode.hasFocus ||
          _selectedVisitor != null) {
        return;
      }
      setState(() => _suggestionsDismissed = true);
    });
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/'
      '${d.year}  ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    _vehicleCtrl.dispose();
    _purposeCtrl.dispose();
    _fromCtrl.dispose();
    _phoneCtrl.dispose();
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
  /// Shown once text is typed until a suggestion is picked, focus moves away
  /// (after a tap grace window), or the mode is switched.
  List<VisitorModel> get _nameSuggestions {
    if (_suggestionsDismissed) return const [];
    final q = _nameCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _visitors
        .where((v) => v.name.toLowerCase().contains(q))
        .toList();
  }

  /// Picks a previous visitor: remembers the selection, fills the name,
  /// last known car plate, from-place and phone, and collapses the
  /// suggestion list. Always overwrites those fields (even with empty) so
  /// stale values from a previous pick never linger.
  void _pickSuggestion(VisitorModel v) {
    // Setting controller text fires onChanged synchronously, which would
    // wipe the just-made selection — suppress it for this programmatic set.
    _programmaticNameSet = true;
    _nameCtrl.text = v.name;
    _nameCtrl.selection =
        TextSelection.collapsed(offset: _nameCtrl.text.length);
    _programmaticNameSet = false;
    setState(() {
      _suggestionsDismissed = true;
      _selectedVisitor = v;
      _vehicleCtrl.text = v.vehicleNumber;
      _fromCtrl.text = v.fromPlace;
      _phoneCtrl.text = v.phone;
    });
  }

  /// True while the name field is being set from a picked suggestion, so the
  /// manual-edit handler below doesn't invalidate the pick.
  bool _programmaticNameSet = false;

  /// Switching person type resets every person/entry field so values picked
  /// in one mode never leak into the other.
  void _switchMode(bool isStaff) {
    setState(() {
      _isStaff = isStaff;
      _selectedStaff = null;
      _selectedVisitor = null;
      _suggestionsDismissed = false;
      _nameCtrl.clear();
      _vehicleCtrl.clear();
      _purposeCtrl.clear();
      _fromCtrl.clear();
      _phoneCtrl.clear();
      for (final c in _accompanyingCtrls) {
        c.dispose();
      }
      _accompanyingCtrls.clear();
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
    final fromPlace = _fromCtrl.text.trim();
    // Staff already have address details in the staff list — Where From is
    // optional for them, required for external visitors.
    if (!_isStaff && fromPlace.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter where the visitor is from')),
      );
      return;
    }
    final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.isNotEmpty && phoneDigits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }
    if (_checkInAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in time cannot be in the future')),
      );
      return;
    }
    // Optional one-step check-out: when the toggle is on, the visit is
    // registered complete under the same name.
    DateTime? checkOutAt;
    if (_addCheckOut) {
      checkOutAt = _checkOutAt;
      if (checkOutAt.isBefore(_checkInAt)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Check-out cannot be before check-in')),
        );
        return;
      }
      if (checkOutAt.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Check-out time cannot be in the future')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await _visitorService.checkIn(
        isStaff: _isStaff,
        staffId: _selectedStaff?.docId,
        // Only reuse a visitor profile when a suggestion was actually picked.
        visitorId: _isStaff ? null : _selectedVisitor?.id,
        name: name,
        vehicleNumber: _vehicleCtrl.text,
        purpose: _purposeCtrl.text,
        fromPlace: fromPlace,
        phone: _phoneCtrl.text,
        accompanyingPeople: _accompanyingNames,
        at: _checkInAt,
        checkOutAt: checkOutAt,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
            content: Text(checkOutAt == null
                ? '$name checked in at ${_fmt(_checkInAt)}'
                : '$name registered (in ${_fmt(_checkInAt)}, '
                    'out ${_fmt(checkOutAt)})')),
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
                onSelectionChanged: (s) => _switchMode(s.first),
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

              // Phone number (autofills from the picked visitor / staff)
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (optional)',
                  hintText: 'e.g. 98765 43210',
                  prefixIcon: Icon(Icons.phone_outlined),
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

              // Where they are from (optional for staff)
              TextField(
                controller: _fromCtrl,
                decoration: InputDecoration(
                  labelText: _isStaff
                      ? 'Where are they from? (optional)'
                      : 'Where are they from? *',
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Check-in date & time (date, hour, minute)
              const Text('Check-in Date & Time',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              VisitDateTimeInput(
                initial: _checkInAt,
                onChanged: (v) => _checkInAt = v,
              ),
              const SizedBox(height: 12),

              // Optional one-step check-out (same for staff and visitors)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add check-out time',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text(
                    'Register this entry complete with both times',
                    style: TextStyle(fontSize: 12)),
                value: _addCheckOut,
                onChanged: (v) => setState(() => _addCheckOut = v),
              ),
              if (_addCheckOut) ...[
                const Text('Check-out Date & Time',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                VisitDateTimeInput(
                  initial: _checkOutAt,
                  onChanged: (v) => _checkOutAt = v,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),

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
      itemHeight: 56,
      decoration: const InputDecoration(
        labelText: 'Staff Member',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      // Compact single-line selected display: the rich two-line item
      // overflows the button's selected-value area.
      selectedItemBuilder: (context) => _staff
          .map((s) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ))
          .toList(),
      items: _staff
          .map((s) => DropdownMenuItem(
                value: s,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14)),
                    if (s.village.isNotEmpty)
                      Text(s.village,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ))
          .toList(),
      onChanged: (s) => setState(() {
        _selectedStaff = s;
        // Autofill where-from from the staff record (village + district,
        // falling back to the address) so it rarely needs typing.
        if (s != null) {
          final place = _staffFromPlace(s);
          if (place.isNotEmpty) _fromCtrl.text = place;
          // Same for the phone number (primary mobile, else secondary).
          final phone = s.mobileNo1.trim().isNotEmpty
              ? s.mobileNo1.trim()
              : s.mobileNo2.trim();
          if (phone.isNotEmpty) _phoneCtrl.text = phone;
        }
      }),
    );
  }

  /// "Where are they from" for a staff member: village + district, or the
  /// address when those are empty.
  static String _staffFromPlace(StaffModel s) {
    final parts = [
      s.village.trim(),
      s.district.trim(),
    ].where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return s.address.trim();
  }

  Widget _buildVisitorNameField() {
    final suggestions = _nameSuggestions;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _nameCtrl,
        focusNode: _nameFocusNode,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Visitor Name',
          hintText: 'Start typing to see previous visitors',
          prefixIcon: Icon(Icons.person_outline),
        ),
        // Any manual edit invalidates a picked suggestion and re-enables
        // the suggestion list (programmatic fills are ignored).
        onChanged: (_) {
          if (_programmaticNameSet) return;
          setState(() {
            _suggestionsDismissed = false;
            _selectedVisitor = null;
          });
        },
      ),
      if (suggestions.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          // Scrollable so many same-name visitors don't stretch the form.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (_, i) {
                final v = suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.history, size: 18),
                  title: Text(v.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${v.visitCount} visit${v.visitCount == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                        if (v.vehicleNumber.isNotEmpty ||
                            v.fromPlace.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child:
                                Wrap(spacing: 10, runSpacing: 2, children: [
                              if (v.vehicleNumber.isNotEmpty)
                                _MiniInfo(Icons.directions_car_outlined,
                                    v.vehicleNumber),
                              if (v.fromPlace.isNotEmpty)
                                _MiniInfo(
                                    Icons.place_outlined, v.fromPlace),
                            ]),
                          ),
                      ]),
                  onTap: () => _pickSuggestion(v),
                );
              },
            ),
          ),
        ),
      ],
    ]);
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniInfo(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.grey.shade500),
      const SizedBox(width: 3),
      Text(text,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
    ]);
  }
}
