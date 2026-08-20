import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gd_college/constants.dart';
import 'package:gd_college/widgets/drawer.dart';
import 'package:gd_college/widgets/pagination_bar.dart';
import '../../controllers/pagination_controller.dart';
import '../../models/audit_log.dart';
import '../models/student_model.dart';
import '../../repositories/student_repository.dart';
import '../../providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'student_form_screen.dart';
import 'student_detail_screen.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});
  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen>
    with SingleTickerProviderStateMixin {

  late final PaginationController _pagination;
  late final TabController _tabs;

  StudentRepository get _service => ref.read(studentRepositoryProvider);

  // Filters
  final TextEditingController _searchIdCtrl = TextEditingController();
  final TextEditingController _searchNameCtrl = TextEditingController();
  String? _selectedCourse;
  String? _selectedYear;

  bool _filtersVisible = false;

  // Sorting
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _pagination = PaginationController(ref.read(studentRepositoryProvider));
    _pagination.addListener(() => setState(() {}));
    _pagination.loadBrowsePage(1);
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pagination.dispose();
    _tabs.dispose();
    _searchIdCtrl.dispose();
    _searchNameCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFilterChanged() {
    setState(() {});
    _debounce?.cancel();

    if (!_hasActiveFilters) {
      // Filters cleared — go back to browse mode
      _pagination.resetToBrowse();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      final query = [_searchNameCtrl.text, _searchIdCtrl.text]
          .where((s) => s.isNotEmpty)
          .join(' ');
      _pagination.runSearch(
        query: query,
        course: _selectedCourse,
        year: _selectedYear,
      );
    });
  }

  List<StudentModel> get _sorted {
    final list = List<StudentModel>.from(_pagination.students);
    list.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: cmp = a.studentId.compareTo(b.studentId); break;
        case 1: cmp = a.name.compareTo(b.name); break;
        case 2: cmp = (a.yearOfAdmission ?? 0).compareTo(b.yearOfAdmission ?? 0); break;
        case 3: cmp = a.nameOfCourse.compareTo(b.nameOfCourse); break;
        default: cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  List<StudentModel> _applyFilters(List<StudentModel> all) {
    return all.where((s) {
      final idMatch = _searchIdCtrl.text.isEmpty ||
          s.studentId
              .toLowerCase()
              .contains(_searchIdCtrl.text.toLowerCase());
      final nameMatch = _searchNameCtrl.text.isEmpty ||
          s.name
              .toLowerCase()
              .contains(_searchNameCtrl.text.toLowerCase());
      final courseMatch = (_selectedCourse == null ||
          _selectedCourse == 'All' ||
          _selectedCourse!.isEmpty) ||
          s.nameOfCourse == _selectedCourse;
      final yearMatch = (_selectedYear == null || _selectedYear!.isEmpty) ||
          s.yearOfAdmission?.toString() == _selectedYear;
      return idMatch && nameMatch && courseMatch && yearMatch;
    }).toList();
  }

  List<StudentModel> _applySort(List<StudentModel> list) {
    list.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = int.tryParse(a.studentId)!.compareTo(int.tryParse(b.studentId)!);
          break;
        case 1:
          cmp = a.name.compareTo(b.name);
          break;
        case 2:
          cmp = (a.yearOfAdmission ?? 0).compareTo(b.yearOfAdmission ?? 0);
          break;
        case 3:
          cmp = a.nameOfCourse.compareTo(b.nameOfCourse);
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  void _clearFilters() {
    _searchIdCtrl.clear();
    _searchNameCtrl.clear();
    _selectedCourse = null;
    _selectedYear = null;
    _onFilterChanged();
  }

  bool get _hasActiveFilters =>
      _searchIdCtrl.text.isNotEmpty ||
      _searchNameCtrl.text.isNotEmpty ||
      (_selectedCourse != null && _selectedCourse != 'All') ||
      (_selectedYear != null && _selectedYear!.isNotEmpty);

  Future<void> _confirmDelete(StudentModel student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Delete Student'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: student.name.isEmpty ? 'this student' : student.name,
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

    if (confirm == true && student.docId != null) {
      try {
        await ref.read(studentRepositoryProvider).delete(student.docId!);
        _pagination.resetToBrowse();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${student.name.isEmpty ? "Student" : student.name} deleted.'),
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

  void _openDetail(StudentModel student) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => StudentDetailScreen(student: student)),
    );
  }

  void _openEdit(StudentModel student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormScreen(existingStudent: student),
      ),
    );
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentFormScreen()),
    );
  }

  void _onCourseChanged(String? v) {
    setState(() => _selectedCourse = v);
    _onFilterChanged();
  }

  void _onYearChanged(String? v) {
    setState(() => _selectedYear = v == 'All' ? null : v);
    _onFilterChanged();
  }

  void _onSort(int col, bool asc) {
    setState(() {
      _sortColumnIndex = col;
      _sortAscending = asc;
    });
  }

  void _onRetry() {
    if (_pagination.isSearchMode) {
      _onFilterChanged();
    } else {
      _pagination.loadBrowsePage(_pagination.currentPage);
    }
  }

  List<String> get _allYears {
    final years = _pagination.students
        .map((s) => s.yearOfAdmission?.toString() ?? '')
        .where((y) => y.isNotEmpty)
        .toSet()
        .toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      drawer: getSideDrawer(context),
      appBar: AppBar(
        title: const Text('Student Records',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_tabs.index == 0) ...[
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
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                _clearFilters();
                _pagination.resetToBrowse();
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Student',
              onPressed: _openAdd,
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(
                icon: Icon(Icons.people_outlined, size: 18),
                text: 'Students'),
            Tab(
                icon: Icon(Icons.history, size: 18),
                text: 'Global Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _StudentsTab(
            pagination: _pagination,
            filtersVisible: _filtersVisible,
            searchIdCtrl: _searchIdCtrl,
            searchNameCtrl: _searchNameCtrl,
            selectedCourse: _selectedCourse,
            selectedYear: _selectedYear,
            allYears: _allYears,
            hasActiveFilters: _hasActiveFilters,
            sortedStudents: _sorted,
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            onFilterChanged: _onFilterChanged,
            onCourseChanged: _onCourseChanged,
            onYearChanged: _onYearChanged,
            onSort: _onSort,
            onClearFilters: _clearFilters,
            onRetry: _onRetry,
            onView: _openDetail,
            onEdit: _openEdit,
            onDelete: _confirmDelete,
          ),
          _StudentGlobalLogTab(service: _service),
        ],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openAdd,
              backgroundColor: const Color(0xFF1A3C6E),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add Student',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}

// ── Students Tab ──────────────────────────────────────────────────────────────

class _StudentsTab extends StatelessWidget {
  final PaginationController pagination;
  final bool filtersVisible;
  final TextEditingController searchIdCtrl;
  final TextEditingController searchNameCtrl;
  final String? selectedCourse;
  final String? selectedYear;
  final List<String> allYears;
  final bool hasActiveFilters;
  final List<StudentModel> sortedStudents;
  final int sortColumnIndex;
  final bool sortAscending;
  final VoidCallback onFilterChanged;
  final void Function(String?) onCourseChanged;
  final void Function(String?) onYearChanged;
  final void Function(int, bool) onSort;
  final VoidCallback onClearFilters;
  final VoidCallback onRetry;
  final void Function(StudentModel) onView;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onDelete;

  const _StudentsTab({
    required this.pagination,
    required this.filtersVisible,
    required this.searchIdCtrl,
    required this.searchNameCtrl,
    required this.selectedCourse,
    required this.selectedYear,
    required this.allYears,
    required this.hasActiveFilters,
    required this.sortedStudents,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onFilterChanged,
    required this.onCourseChanged,
    required this.onYearChanged,
    required this.onSort,
    required this.onClearFilters,
    required this.onRetry,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: filtersVisible
              ? _FilterPanel(
                  idCtrl: searchIdCtrl,
                  nameCtrl: searchNameCtrl,
                  selectedCourse: selectedCourse,
                  courses: listOfCourses,
                  selectedYear: selectedYear,
                  allYears: allYears,
                  hasActiveFilters: hasActiveFilters,
                  onChanged: onFilterChanged,
                  onCourseChanged: onCourseChanged,
                  onYearChanged: onYearChanged,
                  onClear: onClearFilters,
                )
              : const SizedBox.shrink(),
        ),
        _StatsBar(
          total: pagination.totalCount,
          showing: pagination.students.length,
          isSearchMode: pagination.isSearchMode,
        ),
        if (pagination.error != null)
          Container(
            color: Colors.red.shade50,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.error_outline,
                  color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(pagination.error!,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 12))),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ]),
          ),
        Expanded(
          child: pagination.isLoading && pagination.students.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation(Color(0xFF1A3C6E)),
                  ),
                )
              : pagination.students.isEmpty
                  ? _EmptyState(hasFilters: hasActiveFilters)
                  : _StudentTable(
                      students: sortedStudents,
                      sortColumnIndex: sortColumnIndex,
                      sortAscending: sortAscending,
                      onSort: onSort,
                      onView: onView,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
        ),
        PaginationBar(controller: pagination),
      ],
    );
  }
}

// ── Global Log Tab ──────────────────────────────────────────────────────────────

class _StudentGlobalLogTab extends StatelessWidget {
  final StudentRepository service;
  const _StudentGlobalLogTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AuditLog>>(
      stream: service.watchAllStudentLogs(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snap.data ?? [];
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Unable to load logs.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
            ]),
          );
        }
        if (logs.isEmpty) {
          return const _EmptyState(hasFilters: false);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _AuditLogTile(log: logs[i]),
        );
      },
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final AuditLog log;
  const _AuditLogTile({required this.log});

  IconData get _icon {
    switch (log.action) {
      case 'create':
        return Icons.add_circle_outline;
      case 'delete':
        return Icons.remove_circle_outline;
      default:
        return Icons.edit_outlined;
    }
  }

  Color get _color {
    switch (log.action) {
      case 'create':
        return Colors.green.shade700;
      case 'delete':
        return Colors.red.shade600;
      default:
        return Colors.blue.shade700;
    }
  }

  String get _actionLabel {
    switch (log.action) {
      case 'create':
        return 'Created';
      case 'delete':
        return 'Deleted';
      default:
        return 'Updated';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_icon, color: _color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(log.personName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_actionLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _color)),
                ),
              ]),
              const SizedBox(height: 3),
              if (log.detail.isNotEmpty) ...[
                Text(log.detail,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 4),
              ],
              if (log.changedBy.isNotEmpty)
                Text(log.changedBy,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 1),
              Text(
                _fmtDateTime(log.timestamp),
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  String _fmtDateTime(DateTime d) {
    final date = '${d.day}/${d.month}/${d.year}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date  $time';
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
                'Filter Students',
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
                  label: 'Student ID',
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
  final bool isSearchMode;

  const _StatsBar({
    required this.total,
    required this.showing,
    required this.isSearchMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _StatChip(
            label: isSearchMode ? 'Results' : 'Total',
            value: total.toString(),
            color: isSearchMode
                ? Colors.amber.shade700
                : const Color(0xFF1A3C6E),
          ),
          const Spacer(),
          Text(
            'Showing $showing records',
            style:
            TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

class _StudentTable extends StatelessWidget {
  final List<StudentModel> students;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final void Function(StudentModel) onView;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onDelete;

  const _StudentTable({
    required this.students,
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

    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: isNarrow
          ? _MobileList(
              students: students,
              onView: onView,
              onEdit: onEdit,
              onDelete: onDelete,
            )
          : Column(
        children: [
          _TableHeader(
            sortColumnIndex: sortColumnIndex,
            sortAscending: sortAscending,
            onSort: onSort,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: students.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1),
              itemBuilder: (_, i) => _TableRow(
                student: students[i],
                isEven: i.isEven,
                onView: () => onView(students[i]),
                onEdit: () => onEdit(students[i]),
                onDelete: () => onDelete(students[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;

  const _TableHeader({
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A3C6E).withOpacity(0.07),
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
          children: [
        _HeaderCell('Student ID', 3, 0, sortColumnIndex,
            sortAscending, onSort),
        _HeaderCell(
            'Name', 4, 1, sortColumnIndex, sortAscending, onSort),
        _HeaderCell('Adm. Year', 2, 2, sortColumnIndex,
            sortAscending, onSort),
        _HeaderCell(
            'Course', 2, 3, sortColumnIndex, sortAscending, onSort),
        const Expanded(
          flex: 4,
          child: Text('Actions',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3C6E),
                  fontSize: 13)),
        ),
      ]),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final int col;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;

  const _HeaderCell(this.label, this.flex, this.col,
      this.sortColumnIndex, this.sortAscending, this.onSort);

  @override
  Widget build(BuildContext context) {
    final active = sortColumnIndex == col;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => onSort(col, active ? !sortAscending : true),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3C6E),
                  fontSize: 13)),
          if (active)
            Icon(
                sortAscending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 12,
                color: const Color(0xFF1A3C6E)),
        ]),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final StudentModel student;
  final bool isEven;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TableRow({
    required this.student,
    required this.isEven,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? Colors.white : Colors.grey.shade50,
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
          children: [
        // Student ID
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3C6E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                student.studentId.isEmpty ? '—' : student.studentId,
                style: const TextStyle(
                    color: Color(0xFF1A3C6E),
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        // Name
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: avatarColor(student.name),
                child: Text(
                  student.name.isNotEmpty
                      ? student.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  student.name.isEmpty ? '—' : student.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 7),
              student.photoUrl == null ? Text("!", style: TextStyle(color: Colors.red),) : SizedBox()
            ]),
          ),
        ),
        // Year
        Expanded(
          flex: 2,
          child: Text(
            student.yearOfAdmission?.toString() ?? '—',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        // Course
        Expanded(
          flex: 2,
          child: Align(alignment: Alignment.centerLeft,child: _CourseBadge(course: student.nameOfCourse)),
        ),
        // Actions
        Expanded(
          flex: 4,
          child: Row(children: [
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
              onPressed: student.isLocked ? null : onEdit,
            ),
            const SizedBox(width: 4),
            _ActionBtn(
              label: 'Delete',
              icon: Icons.delete_outline,
              color: Colors.red.shade600,
              onPressed: onDelete,
            ),
            const SizedBox(width: 4),
            student.photoUrl == null ? Text("Missing Photo", style: TextStyle(color: Colors.red),) : SizedBox()
          ]),
        ),
      ]),
    );
  }
}

class _MobileList extends StatelessWidget {
  final List<StudentModel> students;
  final void Function(StudentModel) onView;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onDelete;

  const _MobileList({
    required this.students,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF1A3C6E), Color(0xFF2E7D32), Color(0xFF6A1B9A),
      Color(0xFF00838F), Color(0xFF558B2F), Color(0xFF4527A0),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: students.length,
      separatorBuilder: (_, __) =>
      const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final s = students[i];
        return ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: _avatarColor(s.name),
            child: Text(
              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(s.name.isEmpty ? 'Unknown' : s.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Wrap(spacing: 6, runSpacing: 4, children: [
            if (s.studentId.isNotEmpty)
              _SmallTag(label: s.studentId, color: const Color(0xFF1A3C6E)),
            if (s.nameOfCourse.isNotEmpty)
              _SmallTag(label: s.nameOfCourse, color: Colors.teal),
            if (s.yearOfAdmission != null)
              _SmallTag(
                  label: s.yearOfAdmission.toString(),
                  color: Colors.amber.shade800),
          ]),
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

// ── Small helpers ─────────────────────────────────────────────────────────────

class _CourseBadge extends StatelessWidget {
  final String course;
  const _CourseBadge({required this.course});

  Color get _color {
    switch (course) {
      case 'B.ED': return Colors.blue.shade700;
      case 'D.ED': return Colors.green.shade700;
      case 'M.ED': return Colors.purple.shade700;
      case 'D.P.ED': return Colors.orange.shade700;
      case 'SKILL': return Colors.teal.shade700;
      default: return Colors.grey.shade600;
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
            color: _color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 13,
                color: onPressed != null ? color : Colors.grey.shade400),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: onPressed != null
                        ? color
                        : Colors.grey.shade400)),
          ]),
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
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          hasFilters ? Icons.search_off : Icons.people_outline,
          size: 64,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          hasFilters
              ? 'No students match your search'
              : 'No students yet',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500),
        ),
        const SizedBox(height: 6),
        Text(
          hasFilters
              ? 'Try different keywords or clear filters'
              : 'Tap + to add the first student',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        ),
      ]),
    );
  }
}
