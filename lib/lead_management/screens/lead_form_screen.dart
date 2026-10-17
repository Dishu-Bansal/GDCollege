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
  final _courseCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late String _source;
  late String _status;
  DateTime? _followUpAt;
  bool _saving = false;

  bool get _isEdit => widget.existingLead != null;

  @override
  void initState() {
    super.initState();
    final lead = widget.existingLead;
    _source = lead?.source ?? leadSources.first;
    _status = lead?.status ?? leadStatuses.first;
    _followUpAt = lead?.followUpAt;
    if (lead != null) {
      _nameCtrl.text = lead.name;
      _phoneCtrl.text = lead.phone;
      _courseCtrl.text = lead.course;
      _notesCtrl.text = lead.notes;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _courseCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _pickFollowUp() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _followUpAt = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final phone = _phoneCtrl.text.trim();
    final lead = LeadModel(
      id: widget.existingLead?.id,
      name: _nameCtrl.text.trim(),
      phone: phone,
      course: _courseCtrl.text.trim(),
      source: _source,
      status: _status,
      notes: _notesCtrl.text.trim(),
      followUpAt: _followUpAt,
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
                _courseCtrl,
                'Interested Course',
                hint: 'e.g. B.ED, GNM',
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _source,
                      decoration: const InputDecoration(labelText: 'Source'),
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
                      decoration: const InputDecoration(labelText: 'Status'),
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
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Follow-up Date',
                    style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  _followUpAt == null
                      ? 'Not set'
                      : _fmtDate(_followUpAt!),
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: _followUpAt == null
                    ? TextButton(
                        onPressed: _pickFollowUp,
                        child: const Text('Set'),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Clear',
                        onPressed: () =>
                            setState(() => _followUpAt = null),
                      ),
                onTap: _pickFollowUp,
              ),
              _buildField(
                _notesCtrl,
                'Notes',
                hint: 'Anything worth remembering',
                maxLines: 3,
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
