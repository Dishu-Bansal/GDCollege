import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gd_college/access/widgets/access_gate.dart';
import 'package:gd_college/models/user_session.dart';
import 'package:gd_college/providers.dart';
import 'package:gd_college/widgets/drawer.dart';
import 'package:gd_college/widgets/stock_widgets.dart' show confirmDelete;
import '../models/lead_model.dart';
import '../repositories/lead_repository.dart';
import 'lead_form_screen.dart';

/// Lead Management: admission leads with a status pipeline, follow-up dates
/// and an audit log. Viewing needs the Lead Management access flag; adding,
/// editing, status changes and deletes are admin-only (same split as Bills).
class LeadManagementScreen extends ConsumerStatefulWidget {
  const LeadManagementScreen({super.key});

  @override
  ConsumerState<LeadManagementScreen> createState() =>
      _LeadManagementScreenState();
}

class _LeadManagementScreenState extends ConsumerState<LeadManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _adminEmail = 'dishubansal@lklms.com';

  bool get _isAdmin =>
      (UserSession().currentUser?.email ?? '').toLowerCase() == _adminEmail;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openForm([LeadModel? lead]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LeadFormScreen(existingLead: lead)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccessGate(
      module: 'Leads',
      canAccess: (s) => s.canAccessLeads,
      drawer: getSideDrawer(context),
      child: _content(),
    );
  }

  Widget _content() {
    final service = ref.read(leadRepositoryProvider);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      drawer: getSideDrawer(context),
      appBar: AppBar(
        title: const Text('Leads',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (isNarrow && _isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Lead',
              onPressed: () => _openForm(),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.person_search_outlined, size: 18),
                text: 'Leads'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _LeadsTab(service: service, onEdit: _openForm, canManage: _isAdmin),
          _LogsTab(service: service),
        ],
      ),
      floatingActionButton: !isNarrow && _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: const Color(0xFF1A3C6E),
              icon: const Icon(Icons.person_add_alt, color: Colors.white),
              label: const Text('Add Lead',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}

// ── Leads tab ────────────────────────────────────────────────────────────────

class _LeadsTab extends ConsumerStatefulWidget {
  final LeadRepository service;
  final void Function(LeadModel) onEdit;
  final bool canManage;

  const _LeadsTab({
    required this.service,
    required this.onEdit,
    required this.canManage,
  });

  @override
  ConsumerState<_LeadsTab> createState() => _LeadsTabState();
}

class _LeadsTabState extends ConsumerState<_LeadsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedStatuses = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _searchCtrl.text.isNotEmpty || _selectedStatuses.isNotEmpty;

  List<LeadModel> _applyFilters(List<LeadModel> all) {
    final query = _searchCtrl.text.toLowerCase().trim();
    final filtered = all.where((l) {
      final match = query.isEmpty ||
          l.name.toLowerCase().contains(query) ||
          l.phone.contains(query) ||
          l.location.toLowerCase().contains(query) ||
          l.courses.any((c) => c.toLowerCase().contains(query));
      final statusMatch = _selectedStatuses.isEmpty ||
          _selectedStatuses.contains(l.status);
      return match && statusMatch;
    }).toList();
    // Next follow-up first (earliest date on top, none last), then newest.
    filtered.sort((a, b) {
      final fa = a.nextFollowUp;
      final fb = b.nextFollowUp;
      if (fa != null && fb != null) {
        final byDate = fa.date.compareTo(fb.date);
        if (byDate != 0) return byDate;
      } else if (fa != null) {
        return -1;
      } else if (fb != null) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  void _toggleStatus(String status) {
    setState(() {
      if (!_selectedStatuses.remove(status)) _selectedStatuses.add(status);
    });
  }

  void _clearFilters() {
    _searchCtrl.clear();
    _selectedStatuses.clear();
    setState(() {});
  }

  Future<void> _confirmDelete(LeadModel lead) async {
    final ok = await confirmDelete(context, label: lead.name);
    if (!ok) return;
    try {
      await widget.service.deleteLead(lead);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _changeStatus(LeadModel lead, String status) async {
    try {
      await widget.service.updateLeadStatus(lead, status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadsStreamProvider);
    return leads.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Unable to load leads.\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ),
      ),
      data: (list) {
        final filtered = _applyFilters(list);
        return Column(
          children: [
            _LeadFilterBar(
              searchCtrl: _searchCtrl,
              selectedStatuses: _selectedStatuses,
              hasActiveFilters: _hasActiveFilters,
              onSearchChanged: (_) => setState(() {}),
              onStatusToggled: _toggleStatus,
              onClear: _clearFilters,
            ),
            Expanded(
              child: list.isEmpty
                  ? const _EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'No leads yet',
                      subtitle: 'Tap "Add Lead" to record the first enquiry.',
                    )
                  : filtered.isEmpty
                      ? const _EmptyState(
                          icon: Icons.search_off,
                          title: 'No leads match',
                          subtitle:
                              'Try a different search or clear the status filters.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _LeadCard(
                            lead: filtered[i],
                            canManage: widget.canManage,
                            onEdit: () => widget.onEdit(filtered[i]),
                            onDelete: () =>
                                _confirmDelete(filtered[i]),
                            onStatusChanged: (s) =>
                                _changeStatus(filtered[i], s),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ── Filter bar ───────────────────────────────────────────────────────────────

class _LeadFilterBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final Set<String> selectedStatuses;
  final bool hasActiveFilters;
  final void Function(String) onSearchChanged;
  final void Function(String) onStatusToggled;
  final VoidCallback onClear;

  const _LeadFilterBar({
    required this.searchCtrl,
    required this.selectedStatuses,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onStatusToggled,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, course, location',
                    hintStyle:
                        TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: Color(0xFF1A3C6E)),
                    suffixIcon: searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              searchCtrl.clear();
                              onSearchChanged('');
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFF1A3C6E), width: 1.5),
                    ),
                  ),
                ),
              ),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: leadStatuses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final status = leadStatuses[i];
                final selected = selectedStatuses.contains(status);
                final color = _statusColor(status);
                return InkWell(
                  onTap: () => onStatusToggled(status),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? color : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(Icons.check,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                selected ? Colors.white : Colors.black87,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'New':
      return const Color(0xFF1565C0);
    case 'Contacted':
      return const Color(0xFFEF6C00);
    case 'Interested':
      return const Color(0xFF6A1B9A);
    case 'Admitted':
      return const Color(0xFF2E7D32);
    case 'Lost':
      return Colors.grey.shade600;
    default:
      return const Color(0xFF1A3C6E);
  }
}

// ── Lead card ────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final LeadModel lead;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String) onStatusChanged;

  const _LeadCard({
    required this.lead,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(lead.status);
    final next = lead.nextFollowUp;
    final overdue = next != null &&
        next.date
            .isBefore(DateTime.now().subtract(const Duration(days: 1))) &&
        lead.status != 'Admitted' &&
        lead.status != 'Lost';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: overdue ? Colors.red.shade300 : Colors.grey.shade200,
          width: overdue ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lead.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  lead.status,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (lead.phone.isNotEmpty)
            _infoRow(Icons.phone_outlined, lead.phone),
          if (lead.location.isNotEmpty)
            _infoRow(Icons.place_outlined, lead.location),
          if (lead.courses.isNotEmpty)
            _infoRow(Icons.school_outlined, lead.courses.join(', ')),
          _infoRow(Icons.source_outlined, 'Source: ${lead.source}'),
          if (next != null)
            _infoRow(
              Icons.event_outlined,
              'Follow up: ${_fmtDate(next.date)}'
              '${next.note.isNotEmpty ? ' — ${next.note}' : ''}'
              '${overdue ? ' (overdue)' : ''}'
              '${lead.followUps.length > 1 ? ' (+${lead.followUps.length - 1} more)' : ''}',
              color: overdue ? Colors.red.shade700 : null,
            ),
          if (lead.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              lead.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: lead.status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: leadStatuses
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null && v != lead.status) {
                        onStatusChanged(v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A3C6E),
                    side: const BorderSide(color: Color(0xFF1A3C6E)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  tooltip: 'Delete lead',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13,
                  color: color ?? Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logs tab ─────────────────────────────────────────────────────────────────

class _LogsTab extends ConsumerWidget {
  final LeadRepository service;

  const _LogsTab({required this.service});

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(leadLogsStreamProvider);
    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Unable to load logs.\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No lead activity yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final log = list[i];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person_search_outlined,
                      size: 18, color: Color(0xFF1A3C6E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LEAD — ${log.leadName}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          if (log.detail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(log.detail,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${_fmtDateTime(log.timestamp)}  •  by ${log.changedBy}',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ]),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
