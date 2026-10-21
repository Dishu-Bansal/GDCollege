import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../access/access_service.dart';
import '../../lead_management/models/lead_model.dart';
import '../../models/user_session.dart';
import '../../providers.dart';
import '../../constants.dart';
import '../../widgets/stock_widgets.dart';
import '../models/visitor_models.dart';
import '../repositories/visitor_repository.dart';

/// Detail screen for a unique visitor: their profile summary plus every one
/// of their visits.
class VisitorDetailScreen extends ConsumerStatefulWidget {
  final VisitorModel visitor;
  final VisitorRepository service;

  const VisitorDetailScreen({
    super.key,
    required this.visitor,
    required this.service,
  });

  @override
  ConsumerState<VisitorDetailScreen> createState() =>
      _VisitorDetailScreenState();
}

class _VisitorDetailScreenState
    extends ConsumerState<VisitorDetailScreen> {
  VisitorModel get visitor => widget.visitor;
  VisitorRepository get service => widget.service;

  /// Local mirror of the visitor's added-as-lead flag: set from the doc on
  /// open, flipped (and persisted) the moment a lead is created here.
  late bool _addedAsLead;

  @override
  void initState() {
    super.initState();
    _addedAsLead = widget.visitor.addedAsLead;
  }

  String _initial(String name) =>
      name.isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  bool get _isAdmin =>
      AccessService.isAdminEmail(UserSession().currentUser?.email);

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(visitor.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Profile header
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: avatarColor(visitor.name),
              child: Text(
                _initial(visitor.name),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visitor.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 3),
                    Text(
                      '${visitor.visitCount} '
                      'visit${visitor.visitCount == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                    if (visitor.phone.isNotEmpty)
                      Text(
                        'Phone: ${visitor.phone}',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    if (visitor.firstVisitAt != null)
                      Text(
                        'First visit: ${_fmtDateTime(visitor.firstVisitAt!)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    if (visitor.lastVisitAt != null)
                      Text(
                        'Last visit: ${_fmtDateTime(visitor.lastVisitAt!)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    if (_isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _addedAsLead
                            ? const _AddedAsLeadBadge()
                            : OutlinedButton.icon(
                                onPressed: () => _openAddAsLead(context),
                                icon: const Icon(
                                    Icons.person_add_alt_outlined,
                                    size: 16),
                                label: const Text('Add as Lead',
                                    style:
                                        TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      const Color(0xFF00695C),
                                  side: const BorderSide(
                                      color: Color(0xFF00695C)),
                                  visualDensity:
                                      VisualDensity.compact,
                                ),
                              ),
                      ),
                  ]),
            ),
          ]),
        ),
        const Divider(height: 1),

        // Visit history
        Expanded(
          child: StreamBuilder<List<VisitorVisitModel>>(
            stream: service.watchVisitorVisits(visitor.id!),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: Text('Failed to load visits: ${snap.error}'));
              }
              final visits = snap.data ?? [];
              if (snap.connectionState == ConnectionState.waiting &&
                  visits.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (visits.isEmpty) {
                return const StockEmptyState(
                    message: 'No visits recorded for this visitor yet.');
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: visits.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _VisitCard(visit: visits[i]),
              );
            },
          ),
        ),
      ]),
    );
  }

  /// Admin-only one-click lead capture: name, phone, source (Walk-in) and
  /// location (the visitor's "from" place) come prefilled; the rest is the
  /// same lead detail set as the form. On success the visitor is flagged
  /// so the button flips to "Added as Lead".
  Future<void> _openAddAsLead(BuildContext context) async {
    final lead = await showDialog<LeadModel>(
      context: context,
      builder: (_) => _AddLeadDialog(visitor: visitor),
    );
    if (lead == null || !context.mounted) return;
    try {
      await ref.read(leadRepositoryProvider).createLead(lead);
      final id = visitor.id;
      if (id != null) {
        await service.markVisitorAddedAsLead(id);
      }
      if (mounted) setState(() => _addedAsLead = true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lead added for ${lead.name}.'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// Non-interactive badge shown once the visitor has been captured as a lead.
class _AddedAsLeadBadge extends StatelessWidget {
  const _AddedAsLeadBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 14, color: Color(0xFF2E7D32)),
          SizedBox(width: 4),
          Text(
            'Added as Lead',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32)),
          ),
        ],
      ),
    );
  }
}

/// A single visit record for the visitor detail screen.
class _VisitCard extends StatelessWidget {
  final VisitorVisitModel visit;

  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            visit.isInside ? Icons.login : Icons.logout,
            size: 16,
            color: visit.isInside ? Colors.green.shade700 : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            visit.isInside ? 'Inside' : 'Checked out',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: visit.isInside
                    ? Colors.green.shade700
                    : Colors.grey.shade600),
          ),
          const Spacer(),
          Text(
            _fmt(visit.checkInAt),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('In:  ${_fmtFull(visit.checkInAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ]),
        if (visit.checkOutAt != null)
          Text('Out: ${_fmtFull(visit.checkOutAt!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        if (visit.purpose.isNotEmpty ||
            visit.vehicleNumber.isNotEmpty ||
            visit.fromPlace.isNotEmpty ||
            visit.phone.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (visit.purpose.isNotEmpty)
              _InfoItem(Icons.info_outline, visit.purpose),
            if (visit.vehicleNumber.isNotEmpty)
              _InfoItem(Icons.directions_car_outlined, visit.vehicleNumber),
            if (visit.fromPlace.isNotEmpty)
              _InfoItem(Icons.place_outlined, visit.fromPlace),
            if (visit.phone.isNotEmpty)
              _InfoItem(Icons.phone_outlined, visit.phone),
          ]),
        ],
        if (visit.accompanyingPeople.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('With: ${visit.accompanyingPeople.join(', ')}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtFull(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      Text(text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
    ]);
  }
}

/// Lead-capture popup opened from a visitor: name, phone, source (Walk-in)
/// and location (visitor's "from" place) come prefilled but stay editable;
/// courses, notes and an optional first follow-up match the lead form.
class _AddLeadDialog extends StatefulWidget {
  final VisitorModel visitor;

  const _AddLeadDialog({required this.visitor});

  @override
  State<_AddLeadDialog> createState() => _AddLeadDialogState();
}

class _AddLeadDialogState extends State<_AddLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _locationCtrl;
  final _notesCtrl = TextEditingController();
  final _followUpNoteCtrl = TextEditingController();

  String _source = 'Walk-in';
  final Set<String> _courses = {};
  DateTime? _followUpDate;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.visitor.name);
    _phoneCtrl = TextEditingController(text: widget.visitor.phone);
    _locationCtrl = TextEditingController(text: widget.visitor.fromPlace);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _followUpNoteCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      LeadModel(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        courses: _courses.toList(),
        source: _source,
        notes: _notesCtrl.text.trim(),
        followUps: _followUpNoteCtrl.text.trim().isEmpty || _followUpDate == null
            ? []
            : [
                FollowUpNote(
                    note: _followUpNoteCtrl.text.trim(),
                    date: _followUpDate!)
              ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Add as Lead'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    return RegExp(r'^[0-9]{10}$').hasMatch(t)
                        ? null
                        : 'Enter a 10-digit number';
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _locationCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
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
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked =
                        await _pickCourses(context, _courses);
                    if (picked != null) {
                      setState(() => _courses
                        ..clear()
                        ..addAll(picked));
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Interested Courses',
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _courses.isEmpty
                          ? 'Select courses'
                          : _courses.join(', '),
                      style: TextStyle(
                        fontSize: 14,
                        color: _courses.isEmpty
                            ? Colors.grey.shade600
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _followUpNoteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'First follow-up note (optional)',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.event_outlined, size: 20),
                  title: Text(
                    _followUpDate == null
                        ? 'Follow-up date (optional)'
                        : _fmtDate(_followUpDate!),
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: _followUpDate == null
                      ? TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                  const Duration(days: 30)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 730)),
                            );
                            if (picked != null) {
                              setState(() => _followUpDate = picked);
                            }
                          },
                          child: const Text('Set'),
                        )
                      : IconButton(
                          icon:
                              const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(
                              () => _followUpDate = null),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Add Lead')),
      ],
    );
  }

  /// Shared course multi-picker (mirrors the lead form's).
  Future<Set<String>?> _pickCourses(
      BuildContext context, Set<String> current) {
    return showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        final temp = Set<String>.of(current);
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
                      controlAffinity:
                          ListTileControlAffinity.leading,
                      title: Text(option,
                          style:
                              const TextStyle(fontSize: 14)),
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
  }
}
