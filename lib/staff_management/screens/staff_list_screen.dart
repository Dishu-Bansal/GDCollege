import 'package:flutter/material.dart';
import 'package:gd_college/constants.dart';
import 'package:gd_college/widgets/drawer.dart';
import '../models/staff_model.dart';
import '../../models/audit_log.dart';
import '../../providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'staff_form_screen.dart';
import 'staff_detail_screen.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});
  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Filters
  final TextEditingController _searchIdCtrl = TextEditingController();
  final TextEditingController _searchNameCtrl = TextEditingController();
  String? _selectedCourse;
  String? _selectedYear;

  bool _filtersVisible = false;

  // Sorting
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchIdCtrl.dispose();
    _searchNameCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchIdCtrl.clear();
      _searchNameCtrl.clear();
      _selectedCourse = null;
      _selectedYear = null;
    });
  }

  bool get _hasActiveFilters =>
      _searchIdCtrl.text.isNotEmpty ||
      _searchNameCtrl.text.isNotEmpty ||
      (_selectedCourse != null && _selectedCourse != 'All') ||
      (_selectedYear != null && _selectedYear!.isNotEmpty);

  Future<void> _confirmDelete(StaffModel staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Delete Staff'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: staff.name.isEmpty ? 'this staff' : staff.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                  text:
                      '?\n\nThis action cannot be undone and all associated data will be permanently removed.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && staff.docId != null) {
      try {
        await ref.read(staffRepositoryProvider).delete(staff.docId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${staff.name.isEmpty ? "Staff" : staff.name} deleted.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openDetail(StaffModel staff) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => StaffDetailScreen(staff: staff)),
    );
  }

  void _openEdit(StaffModel staff) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffFormScreen(existingStaff: staff),
      ),
    );
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StaffFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Staff Records',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              backgroundColor: Colors.amber,
              child: Icon(
                _filtersVisible ? Icons.filter_list_off : Icons.filter_list,
              ),
            ),
            tooltip: 'Toggle Filters',
            onPressed: () =>
                setState(() => _filtersVisible = !_filtersVisible),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Staff',
            onPressed: _openAdd,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.people_outlined, size: 18), text: 'Staff'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Global Log'),
          ],
        ),
      ),
      drawer: getSideDrawer(context),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Tab 0 – Staff list
          _StaffTab(
            searchIdCtrl: _searchIdCtrl,
            searchNameCtrl: _searchNameCtrl,
            selectedCourse: _selectedCourse,
            selectedYear: _selectedYear,
            filtersVisible: _filtersVisible,
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            hasActiveFilters: _hasActiveFilters,
            onChanged: () => setState(() {}),
            onCourseChanged: (v) => setState(() => _selectedCourse = v),
            onYearChanged: (v) => setState(() => _selectedYear = v),
            onClear: _clearFilters,
            onSort: (col, asc) => setState(() {
              _sortColumnIndex = col;
              _sortAscending = asc;
            }),
            onView: _openDetail,
            onEdit: _openEdit,
            onDelete: _confirmDelete,
          ),
          // Tab 1 – Global audit log
          const _StaffGlobalLogTab(),
        ],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openAdd,
              backgroundColor: const Color(0xFF1A3C6E),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add Staff',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}

// ── Staff Tab ─────────────────────────────────────────────────────────────────

class _StaffTab extends ConsumerStatefulWidget {
  final TextEditingController searchIdCtrl;
  final TextEditingController searchNameCtrl;
  final String? selectedCourse;
  final String? selectedYear;
  final bool filtersVisible;
  final int sortColumnIndex;
  final bool sortAscending;
  final bool hasActiveFilters;
  final VoidCallback onChanged;
  final void Function(String?) onCourseChanged;
  final void Function(String?) onYearChanged;
  final VoidCallback onClear;
  final void Function(int, bool) onSort;
  final void Function(StaffModel) onView;
  final void Function(StaffModel) onEdit;
  final void Function(StaffModel) onDelete;

  const _StaffTab({
    required this.searchIdCtrl,
    required this.searchNameCtrl,
    required this.selectedCourse,
    required this.selectedYear,
    required this.filtersVisible,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.hasActiveFilters,
    required this.onChanged,
    required this.onCourseChanged,
    required this.onYearChanged,
    required this.onClear,
    required this.onSort,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ConsumerState<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends ConsumerState<_StaffTab> {
  /// Subscribed once so typing in the filters does not rebuild the
  /// StreamBuilder with a new stream (which would drop focus).
  late final Stream<List<StaffModel>> _staffStream;

  @override
  void initState() {
    super.initState();
    _staffStream = ref.read(staffRepositoryProvider).watchAll();
  }

  List<StaffModel> _applyFilters(List<StaffModel> all) {
    final idCtrl = widget.searchIdCtrl;
    final nameCtrl = widget.searchNameCtrl;
    return all.where((s) {
      final idMatch = idCtrl.text.isEmpty ||
          s.staffId
              .toLowerCase()
              .contains(idCtrl.text.toLowerCase());
      final nameMatch = nameCtrl.text.isEmpty ||
          s.name
              .toLowerCase()
              .contains(nameCtrl.text.toLowerCase());
      return idMatch && nameMatch;
    }).toList();
  }

  static final DateTime _noDate = DateTime.fromMillisecondsSinceEpoch(0);

  List<StaffModel> _applySort(List<StaffModel> list) {
    list.sort((a, b) {
      int cmp;
      switch (widget.sortColumnIndex) {
        case 0:
          cmp = int.tryParse(a.staffId)!.compareTo(int.tryParse(b.staffId)!);
          break;
        case 1:
          cmp = a.name.compareTo(b.name);
          break;
        case 4:
          // Current (no relieving date) sorts before Previous.
          cmp = (a.dateOfRelieving == null ? 0 : 1)
              .compareTo(b.dateOfRelieving == null ? 0 : 1);
          break;
        case 5:
          cmp = (a.dateOfJoining ?? _noDate)
              .compareTo(b.dateOfJoining ?? _noDate);
          break;
        case 6:
          cmp = (a.dateOfRelieving ?? _noDate)
              .compareTo(b.dateOfRelieving ?? _noDate);
          break;
        default:
          cmp = 0;
      }
      return widget.sortAscending ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StaffModel>>(
      stream: _staffStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A3C6E)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ],
            ),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = _applySort(_applyFilters(all));

        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: widget.filtersVisible
                  ? _FilterPanel(
                      idCtrl: widget.searchIdCtrl,
                      nameCtrl: widget.searchNameCtrl,
                      selectedCourse: widget.selectedCourse,
                      courses: listOfCourses,
                      selectedYear: widget.selectedYear,
                      allYears: all
                          .map((s) => s.salary?.toString() ?? '')
                          .where((y) => y.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort((a, b) => b.compareTo(a)),
                      hasActiveFilters: widget.hasActiveFilters,
                      onChanged: widget.onChanged,
                      onCourseChanged: widget.onCourseChanged,
                      onYearChanged: widget.onYearChanged,
                      onClear: widget.onClear,
                    )
                  : const SizedBox.shrink(),
            ),
            _StatsBar(total: all.length, showing: filtered.length),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(hasFilters: widget.hasActiveFilters)
                  : _StaffTable(
                      staffs: filtered,
                      sortColumnIndex: widget.sortColumnIndex,
                      sortAscending: widget.sortAscending,
                      onSort: widget.onSort,
                      onView: widget.onView,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Global Audit Log Tab ──────────────────────────────────────────────────────

class _StaffGlobalLogTab extends ConsumerWidget {
  const _StaffGlobalLogTab();

  IconData _actionIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.check_circle;
      case 'update':
        return Icons.sync;
      case 'delete':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'create':
        return 'Created';
      case 'update':
        return 'Updated';
      case 'delete':
        return 'Deleted';
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<AuditLog>>(
      stream: ref.watch(staffRepositoryProvider).watchAllStaffLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A3C6E)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ],
            ),
          );
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No audit logs yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Activity will appear here',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final log = logs[i];
            final color = _actionColor(log.action);
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_actionIcon(log.action),
                          size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  log.personName.isEmpty
                                      ? 'Unknown'
                                      : log.personName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _actionLabel(log.action),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (log.detail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              log.detail,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                log.changedBy.isEmpty ? '—' : log.changedBy,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.access_time,
                                  size: 13, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimestamp(log.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Filter Panel ──────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final TextEditingController idCtrl;
  final TextEditingController nameCtrl;
  final String? selectedCourse;
  final List<String> courses;
  final String? selectedYear;
  final List<String> allYears;
  final bool hasActiveFilters;
  final VoidCallback onChanged;
  final void Function(String?) onCourseChanged;
  final void Function(String?) onYearChanged;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.idCtrl,
    required this.nameCtrl,
    required this.selectedCourse,
    required this.courses,
    required this.selectedYear,
    required this.allYears,
    required this.hasActiveFilters,
    required this.onChanged,
    required this.onCourseChanged,
    required this.onYearChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 16, color: Color(0xFF1A3C6E)),
              const SizedBox(width: 6),
              const Text(
                'Filter Staff',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A3C6E),
                    fontSize: 13),
              ),
              const Spacer(),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear All',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FilterField(
                  controller: idCtrl,
                  label: 'Staff ID',
                  icon: Icons.badge_outlined,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterField(
                  controller: nameCtrl,
                  label: 'Name',
                  icon: Icons.person_outline,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  value: selectedCourse,
                  hint: 'Course',
                  icon: Icons.menu_book_outlined,
                  items: courses,
                  onChanged: onCourseChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterDropdown(
                  value: selectedYear,
                  hint: 'Admission Year',
                  icon: Icons.calendar_today_outlined,
                  items: ['All', ...allYears],
                  onChanged: (v) => onYearChanged(v == 'All' ? null : v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final void Function(String) onChanged;

  const _FilterField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(icon, size: 16),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          borderSide:
              const BorderSide(color: Color(0xFF1A3C6E), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 14),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            : null,
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final void Function(String?) onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      isDense: true,
      isExpanded: true,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(icon, size: 16),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          borderSide:
              const BorderSide(color: Color(0xFF1A3C6E), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items
          .map((e) => DropdownMenuItem(
              value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
          .toList(),
    );
  }
}

// ── Stats Bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int total;
  final int showing;

  const _StatsBar({required this.total, required this.showing});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _StatChip(
            label: 'Total',
            value: total.toString(),
            color: const Color(0xFF1A3C6E),
          ),
          const SizedBox(width: 10),
          if (showing != total)
            _StatChip(
              label: 'Filtered',
              value: showing.toString(),
              color: Colors.amber.shade700,
            ),
          const Spacer(),
          Text(
            'Showing $showing of $total records',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: color, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _StaffTable extends StatelessWidget {
  final List<StaffModel> staffs;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final void Function(StaffModel) onView;
  final void Function(StaffModel) onEdit;
  final void Function(StaffModel) onDelete;

  const _StaffTable({
    required this.staffs,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: isNarrow
            ? _MobileCardList(
                staffs: staffs,
                onView: onView,
                onEdit: onEdit,
                onDelete: onDelete,
              )
            : _DataTable(
                staffs: staffs,
                sortColumnIndex: sortColumnIndex,
                sortAscending: sortAscending,
                onSort: onSort,
                onView: onView,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
      ),
    );
  }
}

// Desktop-style DataTable
class _DataTable extends StatelessWidget {
  final List<StaffModel> staffs;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final void Function(StaffModel) onView;
  final void Function(StaffModel) onEdit;
  final void Function(StaffModel) onDelete;

  const _DataTable({
    required this.staffs,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1080),
        child: DataTable(
        sortColumnIndex: sortColumnIndex,
        sortAscending: sortAscending,
        headingRowColor: WidgetStateProperty.all(
            const Color(0xFF1A3C6E).withOpacity(0.07)),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A3C6E),
          fontSize: 13,
        ),
        dataTextStyle:
            const TextStyle(fontSize: 13, color: Colors.black87),
        columnSpacing: 20,
        horizontalMargin: 16,
        dividerThickness: 0.5,
        columns: [
          DataColumn(
            label: const Text('Staff ID'),
            onSort: (i, asc) => onSort(0, asc),
          ),
          DataColumn(
            label: const Text('Name'),
            onSort: (i, asc) => onSort(1, asc),
          ),
          DataColumn(
            label: const Text('Designation'),
            numeric: true,
            onSort: (i, asc) => onSort(2, asc),
          ),
          DataColumn(
            label: const Text('Course'),
            onSort: (i, asc) => onSort(3, asc),
          ),
          DataColumn(
            label: const Text('Status'),
            onSort: (i, asc) => onSort(4, asc),
          ),
          DataColumn(
            label: const Text('Date of Joining'),
            onSort: (i, asc) => onSort(5, asc),
          ),
          DataColumn(
            label: const Text('Date of Relieving'),
            onSort: (i, asc) => onSort(6, asc),
          ),
          const DataColumn(label: Text('Actions')),
        ],
        rows: staffs.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return DataRow(
            color: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFF1A3C6E).withOpacity(0.04);
              }
              return i.isOdd ? Colors.grey.shade50 : Colors.white;
            }),
            cells: [
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3C6E).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.staffId.isEmpty ? '—' : s.staffId,
                    style: const TextStyle(
                      color: Color(0xFF1A3C6E),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: avatarColor(s.name),
                      child: Text(
                        s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        s.name.isEmpty ? '—' : s.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(Text(
                s.designation?.toString() ?? '—',
                textAlign: TextAlign.right,
              )),
              DataCell(_CourseBadge(course: s.course.toString())),
              DataCell(_StatusBadge(previous: s.dateOfRelieving != null)),
              DataCell(Text(_fmtDate(s.dateOfJoining))),
              DataCell(Text(_fmtDate(s.dateOfRelieving))),
              DataCell(_ActionButtons(
                staff: s,
                onView: () => onView(s),
                onEdit: () => onEdit(s),
                onDelete: () => onDelete(s),
              )),
            ],
          );
        }).toList(),
        ),
      ),
    );
  }
}

// Mobile card list (for narrow screens)
class _MobileCardList extends StatelessWidget {
  final List<StaffModel> staffs;
  final void Function(StaffModel) onView;
  final void Function(StaffModel) onEdit;
  final void Function(StaffModel) onDelete;

  const _MobileCardList({
    required this.staffs,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: staffs.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final s = staffs[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: avatarColor(s.name),
            child: Text(
              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            s.name.isEmpty ? 'Unknown' : s.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (s.staffId.isNotEmpty)
                    _SmallTag(
                        label: s.staffId, color: const Color(0xFF1A3C6E)),
                  _SmallTag(
                    label: s.dateOfRelieving != null ? 'Previous' : 'Current',
                    color: s.dateOfRelieving != null
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Joined: ${_fmtDate(s.dateOfJoining)}   '
                'Relieved: ${_fmtDate(s.dateOfRelieving)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'view') onView(s);
              if (v == 'edit') onEdit(s);
              if (v == 'delete') onDelete(s);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'view', child: Text('View')),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _CourseBadge extends StatelessWidget {
  final String course;
  const _CourseBadge({required this.course});

  Color get _color {
    switch (course) {
      case 'B.ED':
        return Colors.blue.shade700;
      case 'D.ED':
        return Colors.green.shade700;
      case 'M.ED':
        return Colors.purple.shade700;
      case 'D.P.ED':
        return Colors.orange.shade700;
      case 'SKILL':
        return Colors.teal.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        course.isEmpty ? '—' : course,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Current (no relieving date) or Previous label pill for the table.
class _StatusBadge extends StatelessWidget {
  final bool previous;
  const _StatusBadge({required this.previous});

  @override
  Widget build(BuildContext context) {
    final color =
        previous ? Colors.orange.shade700 : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        previous ? 'Previous' : 'Current',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// dd/MM/yyyy, or an em dash when the date is unknown.
String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day}/${d.month}/${d.year}';
}

class _ActionButtons extends StatelessWidget {
  final StaffModel staff;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionButtons({
    required this.staff,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionBtn(
          label: 'View',
          icon: Icons.visibility_outlined,
          color: const Color(0xFF1A3C6E),
          onPressed: onView,
        ),
        const SizedBox(width: 4),
        _ActionBtn(
          label: 'Edit',
          icon: Icons.edit_outlined,
          color: Colors.amber.shade700,
          onPressed: staff.isLocked ? null : onEdit,
        ),
        const SizedBox(width: 4),
        _ActionBtn(
          label: 'Delete',
          icon: Icons.delete_outline,
          color: Colors.red.shade600,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: onPressed != null
                ? color.withOpacity(0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: onPressed != null ? color : Colors.grey.shade400,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: onPressed != null ? color : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No staffs match your filters' : 'No staffs yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try adjusting your search criteria'
                : 'Tap the + button to add a staff',
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
