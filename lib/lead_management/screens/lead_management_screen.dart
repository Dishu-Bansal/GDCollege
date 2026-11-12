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
                      : _LeadsTable(
                          leads: filtered,
                          total: list.length,
                          canManage: widget.canManage,
                          onEdit: widget.onEdit,
                          onDelete: _confirmDelete,
                          onStatusChanged: _changeStatus,
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

// ── Leads table ──────────────────────────────────────────────────────────────

class _LeadsTable extends StatelessWidget {
  final List<LeadModel> leads;
  final int total;
  final bool canManage;
  final void Function(LeadModel) onEdit;
  final void Function(LeadModel) onDelete;
  final void Function(LeadModel, String) onStatusChanged;

  const _LeadsTable({
    required this.leads,
    required this.total,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _followUpText(LeadModel lead) {
    final next = lead.nextFollowUp;
    if (next == null) return '—';
    var text = _fmtDate(next.date);
    if (next.note.isNotEmpty) text += ' — ${next.note}';
    if (lead.followUps.length > 1) {
      text += ' (+${lead.followUps.length - 1} more)';
    }
    return text;
  }

  bool _isOverdue(LeadModel lead) {
    final next = lead.nextFollowUp;
    return next != null &&
        next.date
            .isBefore(DateTime.now().subtract(const Duration(days: 1))) &&
        lead.status != 'Admitted' &&
        lead.status != 'Lost';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            leads.length == total
                ? 'Total leads: $total'
                : 'Showing ${leads.length} of $total leads',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A3C6E)),
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF1A3C6E)),
                  dataTextStyle: const TextStyle(fontSize: 12),
                  columns: [
                    const DataColumn(label: Text('Name')),
                    const DataColumn(label: Text('Phone')),
                    const DataColumn(label: Text('Location')),
                    const DataColumn(label: Text('Courses')),
                    const DataColumn(label: Text('Source')),
                    const DataColumn(label: Text('Notes')),
                    const DataColumn(label: Text('Follow-up')),
                    const DataColumn(label: Text('Status')),
                    if (canManage)
                      const DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final lead in leads)
                      DataRow(
                        color: WidgetStatePropertyAll(
                          _isOverdue(lead)
                              ? Colors.red.shade50
                              : Colors.transparent,
                        ),
                        cells: [
                          DataCell(Text(lead.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                          DataCell(Text(lead.phone.isEmpty
                              ? '—'
                              : lead.phone)),
                          DataCell(Text(lead.location.isEmpty
                              ? '—'
                              : lead.location)),
                          DataCell(Text(lead.courses.isEmpty
                              ? '—'
                              : lead.courses.join(', '))),
                          DataCell(Text(lead.source)),
                          DataCell(SizedBox(
                            width: 200,
                            child: Text(
                              lead.notes.isEmpty ? '—' : lead.notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(Text(
                            _followUpText(lead),
                            style: TextStyle(
                              color: _isOverdue(lead)
                                  ? Colors.red.shade700
                                  : null,
                              fontWeight: _isOverdue(lead)
                                  ? FontWeight.w600
                                  : null,
                            ),
                          )),
                          DataCell(canManage
                              ? DropdownButton<String>(
                                  value: lead.status,
                                  isDense: true,
                                  underline: const SizedBox.shrink(),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          _statusColor(lead.status)),
                                  items: leadStatuses
                                      .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null &&
                                        v != lead.status) {
                                      onStatusChanged(lead, v);
                                    }
                                  },
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(lead.status)
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    lead.status,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _statusColor(
                                            lead.status)),
                                  ),
                                )),
                          if (canManage)
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16),
                                  tooltip: 'Edit lead',
                                  color:
                                      const Color(0xFF1A3C6E),
                                  visualDensity:
                                      VisualDensity.compact,
                                  onPressed: () => onEdit(lead),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16),
                                  tooltip: 'Delete lead',
                                  color: Colors.red,
                                  visualDensity:
                                      VisualDensity.compact,
                                  onPressed: () =>
                                      onDelete(lead),
                                ),
                              ],
                            )),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
