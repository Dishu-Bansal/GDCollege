import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gd_college/providers.dart';
import '../models/lead_model.dart';

/// Add / edit an admission lead. Only reachable by users who can manage
/// leads (currently the admin); viewing is gated separately.
class LeadFormScreen extends ConsumerStatefulWidget {
  final LeadModel? existingLead;

  const LeadFormScreen({super.key, this.existingLead});

  @override
  ConsumerState<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends ConsumerState<LeadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late String _source;
  late String _status;
  final Set<String> _courses = {};
  final List<FollowUpNote> _followUps = [];
  bool _saving = false;

  bool get _isEdit => widget.existingLead != null;

  @override
  void initState() {
    super.initState();
    final lead = widget.existingLead;
    _source = lead?.source ?? leadSources.first;
    _status = lead?.status ?? leadStatuses.first;
    if (lead != null) {
      _nameCtrl.text = lead.name;
      _phoneCtrl.text = lead.phone;
      _locationCtrl.text = lead.location;
      _notesCtrl.text = lead.notes;
      _courses.addAll(lead.courses);
      _followUps.addAll(lead.followUps.map(
          (f) => FollowUpNote(note: f.note, date: f.date)));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _addFollowUp() async {
    final noteCtrl = TextEditingController();
    var date = DateTime.now();
    final result = await showDialog<FollowUpNote>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Add Follow-up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Follow-up note *',
                  hintText: 'e.g. Call about fee structure',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Date', style: TextStyle(fontSize: 14)),
                subtitle: Text(_fmtDate(date),
                    style: const TextStyle(fontSize: 13)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 30)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) setDialog(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (noteCtrl.text.trim().isEmpty) return;
                Navigator.pop(
                    ctx,
                    FollowUpNote(
                        note: noteCtrl.text.trim(), date: date));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _followUps.add(result));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final phone = _phoneCtrl.text.trim();
    final lead = LeadModel(
      id: widget.existingLead?.id,
      name: _nameCtrl.text.trim(),
      phone: phone,
      location: _locationCtrl.text.trim(),
      courses: _courses.toList(),
      source: _source,
      status: _status,
      notes: _notesCtrl.text.trim(),
      followUps: List.of(_followUps),
      createdAt: widget.existingLead?.createdAt,
      createdBy: widget.existingLead?.createdBy ?? '',
    );
    try {
      final repo = ref.read(leadRepositoryProvider);
      if (_isEdit) {
        await repo.updateLead(lead);
      } else {
        await repo.createLead(lead);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Lead' : 'Add Lead',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCard([
              _buildField(_nameCtrl, 'Name *'),
              _buildField(
                _phoneCtrl,
                'Phone',
                hint: '10-digit mobile number',
                keyboard: TextInputType.phone,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  return RegExp(r'^[0-9]{10}$').hasMatch(t)
                      ? null
                      : 'Enter a 10-digit number';
                },
              ),
              _buildField(
                _locationCtrl,
                'Location',
                hint: 'e.g. Gohana, Sonipat',
              ),
              _CourseMultiPicker(
                selected: _courses,
                onChanged: () => setState(() {}),
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _source,
                      decoration:
                          const InputDecoration(labelText: 'Source'),
                      items: leadSources
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _source = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration:
                          const InputDecoration(labelText: 'Status'),
                      items: leadStatuses
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _status = v);
                      },
                    ),
                  ),
                ],
              ),
              _buildField(
                _notesCtrl,
                'Notes',
                hint: 'Anything worth remembering',
                maxLines: 3,
              ),
            ]),
            const SizedBox(height: 16),
            _sectionCard([
              Row(
                children: [
                  const Text(
                    'Follow-ups',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addFollowUp,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Follow-up'),
                  ),
                ],
              ),
              if (_followUps.isEmpty)
                Text(
                  'No follow-ups yet.',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade500),
                )
              else
                for (var i = 0; i < _followUps.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3C6E)
                          .withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF1A3C6E)
                              .withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.event_note_outlined,
                            size: 18, color: Color(0xFF1A3C6E)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _followUps[i].note,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _fmtDate(_followUps[i].date),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              setState(() => _followUps.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: validator ??
          (label.endsWith('*')
              ? (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null
              : null),
    );
  }
}

/// Multi-select dropdown for interested courses: a read-only field showing
/// the picks, opening a checkbox dialog.
class _CourseMultiPicker extends StatelessWidget {
  final Set<String> selected;
  final VoidCallback onChanged;

  const _CourseMultiPicker({required this.selected, required this.onChanged});

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        final temp = Set<String>.of(selected);
        return StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            title: const Text('Interested Courses'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in leadCourseOptions)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(option,
                          style: const TextStyle(fontSize: 14)),
                      value: temp.contains(option),
                      onChanged: (v) => setDialog(() {
                        if (v == true) {
                          temp.add(option);
                        } else {
                          temp.remove(option);
                        }
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, temp),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      selected
        ..clear()
        ..addAll(picked);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Interested Courses',
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selected.isEmpty
              ? 'Select courses'
              : selected.join(', '),
          style: TextStyle(
            fontSize: 14,
            color: selected.isEmpty ? Colors.grey.shade600 : null,
          ),
        ),
      ),
    );
  }
}
