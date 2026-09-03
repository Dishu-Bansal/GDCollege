import 'package:flutter/material.dart';
import 'package:gd_college/constants.dart';
import 'package:gd_college/widgets/drawer.dart';
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
  static final DateTime _oldest = DateTime.fromMillisecondsSinceEpoch(0);

  // The three course-group tabs come first; the Global Log is the last tab.
  static final int _groupCount = StudentGroup.values.length;

  late final TabController _tabs;

  StudentRepository get _service => ref.read(studentRepositoryProvider);

  // Full dataset loaded once and split into the three groups.
  List<StudentModel> _all = [];
  bool _loading = true;
  String? _error;

  // Per-group filter/sort state.
  final List<TextEditingController> _searchCtrls = List.generate(
    _groupCount,
    (_) => TextEditingController(),
  );
  final List<Set<String>> _selectedYears = List.generate(
    _groupCount,
    (_) => <String>{},
  );
  final List<Set<String>> _selectedCourses = List.generate(
    _groupCount,
    (_) => <String>{},
  );
  final List<List<StudentModel>> _groupBase = List.generate(
    _groupCount,
    (_) => <StudentModel>[],
  );
  final List<List<String>> _yearOptions = List.generate(
    _groupCount,
    (_) => <String>[],
  );
  final List<List<String>> _courseOptions = List.generate(
    _groupCount,
    (_) => <String>[],
  );

  int _sortColumnIndex = 0; // 0 = Date Added
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _groupCount + 1, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _searchCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await _service.fetchAllStudents();
      if (!mounted) return;
      _buildGroups(students);
      setState(() {
        _all = students;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _buildGroups(List<StudentModel> students) {
    for (var g = 0; g < _groupCount; g++) {
      final group = StudentGroup.values[g];
      final members = students
          .where((s) => studentGroupOfCourse(s.nameOfCourse) == group)
          .toList();
      _groupBase[g] = members;
      _yearOptions[g] = _uniqueYearsOf(members);
      _courseOptions[g] = _uniqueCoursesOf(members);
    }
  }

  /// Admission years that actually exist in [members], newest first.
  List<String> _uniqueYearsOf(List<StudentModel> members) {
    final years =
        members
            .map((s) => s.yearOfAdmission)
            .whereType<int>()
            .where((y) => y > 0)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return [for (final y in years) '$y'];
  }

  /// Distinct courses in [members], ordered by the canonical course list
  /// (unknown/legacy values sort after it alphabetically).
  List<String> _uniqueCoursesOf(List<StudentModel> members) {
    final courses = members
        .map((s) => s.nameOfCourse.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    courses.sort((a, b) {
      final ia = listOfCourses.indexWhere(
        (x) => x.toLowerCase() == a.toLowerCase(),
      );
      final ib = listOfCourses.indexWhere(
        (x) => x.toLowerCase() == b.toLowerCase(),
      );
      final ra = ia < 0 ? listOfCourses.length : ia;
      final rb = ib < 0 ? listOfCourses.length : ib;
      if (ra != rb) return ra.compareTo(rb);
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return courses;
  }

  bool _studentMatches(StudentModel s, String needle) {
    bool hit(String? v) => v != null && v.toLowerCase().contains(needle);
    return hit(s.name) ||
        hit(s.studentId) ||
        hit(s.fatherName) ||
        hit(s.mobileNo1);
  }

  // ── Derived per-group views ──────────────────────────────────────────────

  bool _hasActiveFilters(int g) =>
      _searchCtrls[g].text.isNotEmpty ||
      _selectedYears[g].isNotEmpty ||
      _selectedCourses[g].isNotEmpty;

  int _compareStudents(StudentModel a, StudentModel b) {
    int cmp;
    switch (_sortColumnIndex) {
      case 0:
        cmp = (a.createdAt ?? _oldest).compareTo(b.createdAt ?? _oldest);
        break;
      case 1:
        cmp = a.studentId.compareTo(b.studentId);
        break;
      case 2:
        cmp = a.name.compareTo(b.name);
        break;
      case 3:
        cmp = (a.yearOfAdmission ?? 0).compareTo(b.yearOfAdmission ?? 0);
        break;
      case 4:
        cmp = a.nameOfCourse.compareTo(b.nameOfCourse);
        break;
      default:
        cmp = 0;
    }
    return _sortAscending ? cmp : -cmp;
  }

  /// Students of group [g] after applying its search text, admission-year and
  /// course chips, sorted with the current sort column.
  List<StudentModel> _visibleStudents(int g) {
    final base = _groupBase[g];
    final needle = _searchCtrls[g].text.trim().toLowerCase();
    final years = _selectedYears[g];
    final courses = _selectedCourses[g];

    final filtered = base.where((s) {
      if (needle.isNotEmpty && !_studentMatches(s, needle)) return false;
      if (years.isNotEmpty) {
        final year = s.yearOfAdmission?.toString();
        if (year == null || !years.contains(year)) return false;
      }
      if (courses.isNotEmpty && !courses.contains(s.nameOfCourse)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort(_compareStudents);
    return filtered;
  }

  // ── Filter / sort handlers ───────────────────────────────────────────────

  void _onSearchChanged(int g, String _) => setState(() {});

  void _toggleYear(int g, String year) {
    setState(() {
      if (!_selectedYears[g].remove(year)) _selectedYears[g].add(year);
    });
  }

  void _toggleCourse(int g, String course) {
    setState(() {
      if (!_selectedCourses[g].remove(course)) _selectedCourses[g].add(course);
    });
  }

  void _clearFilters(int g) {
    setState(() {
      _searchCtrls[g].clear();
      _selectedYears[g].clear();
      _selectedCourses[g].clear();
    });
  }

  void _clearAllFilters() {
    for (var g = 0; g < _groupCount; g++) {
      _searchCtrls[g].clear();
      _selectedYears[g].clear();
      _selectedCourses[g].clear();
    }
  }

  void _onSort(int col, bool asc) {
    setState(() {
      _sortColumnIndex = col;
      _sortAscending = asc;
    });
  }

  // ── Actions ──────────────────────────────────────────────────────────────

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
                    '?\n\nThis action cannot be undone and all associated data will be permanently removed.',
              ),
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
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${student.name.isEmpty ? "Student" : student.name} deleted.',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _openDetail(StudentModel student) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
    );
  }

  Future<void> _openEdit(StudentModel student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormScreen(existingStudent: student),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentFormScreen()),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final bool showGroupActions = _tabs.index < _groupCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      drawer: getSideDrawer(context),
      appBar: AppBar(
        title: const Text(
          'Student Records',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (showGroupActions) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                _clearAllFilters();
                _load();
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            for (final g in StudentGroup.values)
              Tab(icon: Icon(_groupIcon(g), size: 18), text: g.label),
            const Tab(icon: Icon(Icons.history, size: 18), text: 'Global Log'),
          ],
        ),
      ),
      body: _loading && _all.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF1A3C6E)),
              ),
            )
          : _error != null && _all.isEmpty
          ? _LoadError(error: _error!, onRetry: _load)
          : TabBarView(
              controller: _tabs,
              children: [
                for (var g = 0; g < _groupCount; g++)
                  _GroupStudentsTab(
                    title: StudentGroup.values[g].label,
                    baseCount: _groupBase[g].length,
                    error: _error,
                    searchCtrl: _searchCtrls[g],
                    yearOptions: _yearOptions[g],
                    selectedYears: _selectedYears[g],
                    courseOptions: _courseOptions[g],
                    selectedCourses: _selectedCourses[g],
                    hasActiveFilters: _hasActiveFilters(g),
                    results: _visibleStudents(g),
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    onSort: _onSort,
                    onSearchChanged: (v) => _onSearchChanged(g, v),
                    onYearToggled: (v) => _toggleYear(g, v),
                    onCourseToggled: (v) => _toggleCourse(g, v),
                    onClear: () => _clearFilters(g),
                    onRetry: _load,
                    onView: _openDetail,
                    onEdit: _openEdit,
                    onDelete: _confirmDelete,
                  ),
                _StudentGlobalLogTab(service: _service),
              ],
            ),
      floatingActionButton: showGroupActions
          ? FloatingActionButton.extended(
              onPressed: _openAdd,
              backgroundColor: const Color(0xFF1A3C6E),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'Add Student',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  IconData _groupIcon(StudentGroup g) {
    switch (g) {
      case StudentGroup.gdCollege:
        return Icons.school;
      case StudentGroup.mlsn:
        return Icons.local_hospital_outlined;
      case StudentGroup.skillIndia:
        return Icons.work_outline;
    }
  }
}

// ── Load error ───────────────────────────────────────────────────────────────

class _LoadError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _LoadError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Unable to load students.\n$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── One course-group tab (GD College / MLSN / Skill India) ─────────────────

class _GroupStudentsTab extends StatelessWidget {
  final String title;
  final int baseCount;
  final String? error;
  final TextEditingController searchCtrl;
  final List<String> yearOptions;
  final Set<String> selectedYears;
  final List<String> courseOptions;
  final Set<String> selectedCourses;
  final bool hasActiveFilters;
  final List<StudentModel> results;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final ValueChanged<String> onSearchChanged;
  final void Function(String) onYearToggled;
  final void Function(String) onCourseToggled;
  final VoidCallback onClear;
  final VoidCallback onRetry;
  final void Function(StudentModel) onView;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onDelete;

  const _GroupStudentsTab({
    required this.title,
    required this.baseCount,
    required this.error,
    required this.searchCtrl,
    required this.yearOptions,
    required this.selectedYears,
    required this.courseOptions,
    required this.selectedCourses,
    required this.hasActiveFilters,
    required this.results,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.onSearchChanged,
    required this.onYearToggled,
    required this.onCourseToggled,
    required this.onClear,
    required this.onRetry,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchChipsPanel(
          searchCtrl: searchCtrl,
          yearOptions: yearOptions,
          selectedYears: selectedYears,
          courseOptions: courseOptions,
          selectedCourses: selectedCourses,
          hasActiveFilters: hasActiveFilters,
          onSearchChanged: onSearchChanged,
          onYearToggled: onYearToggled,
          onCourseToggled: onCourseToggled,
          onClear: onClear,
        ),
        if (error != null)
          Container(
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        _GroupStatsRow(
          count: results.length,
          baseCount: baseCount,
          hasActiveFilters: hasActiveFilters,
        ),
        Expanded(
          child: results.isEmpty
              ? _EmptyState(
                  hasFilters: baseCount > 0 && hasActiveFilters,
                  emptyTitle: baseCount == 0 ? 'No $title students yet' : null,
                )
              : _StudentTable(
                  students: results,
                  sortColumnIndex: sortColumnIndex,
                  sortAscending: sortAscending,
                  onSort: onSort,
                  onView: onView,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
        ),
      ],
    );
  }
}

class _GroupStatsRow extends StatelessWidget {
  final int count;
  final int baseCount;
  final bool hasActiveFilters;

  const _GroupStatsRow({
    required this.count,
    required this.baseCount,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    final accent = hasActiveFilters
        ? Colors.amber.shade700
        : const Color(0xFF1A3C6E);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  hasActiveFilters ? 'results' : 'students',
                  style: TextStyle(
                    fontSize: 11,
                    color: accent.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            hasActiveFilters
                ? '$count of $baseCount matched'
                : '$baseCount total',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ── Global Log Tab ──────────────────────────────────────────────────────────

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Unable to load logs.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
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
      child: Row(
        children: [
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.personName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _actionLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (log.detail.isNotEmpty) ...[
                  Text(
                    log.detail,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                ],
                if (log.changedBy.isNotEmpty)
                  Text(
                    log.changedBy,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                const SizedBox(height: 1),
                Text(
                  _fmtDateTime(log.timestamp),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime d) {
    final date = '${d.day}/${d.month}/${d.year}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date  $time';
  }
}

// ── Search & Chip Filters ───────────────────────────────────────────────────

/// Permanent search bar plus multi-select admission-year and course chips.
/// Chip options come from the data of the tab being shown (years and courses
/// that actually exist in that tab).
class _SearchChipsPanel extends StatelessWidget {
  final TextEditingController searchCtrl;
  final List<String> yearOptions;
  final Set<String> selectedYears;
  final List<String> courseOptions;
  final Set<String> selectedCourses;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final void Function(String) onYearToggled;
  final void Function(String) onCourseToggled;
  final VoidCallback onClear;
  const _SearchChipsPanel({
    required this.searchCtrl,
    required this.yearOptions,
    required this.selectedYears,
    required this.courseOptions,
    required this.selectedCourses,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onYearToggled,
    required this.onCourseToggled,
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
                    hintText: 'Search by name or student ID',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Color(0xFF1A3C6E),
                    ),
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
                      horizontal: 10,
                      vertical: 10,
                    ),
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
                        color: Color(0xFF1A3C6E),
                        width: 1.5,
                      ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
            ],
          ),
          if (yearOptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ChipGroupRow(
              label: 'Admission Year',
              options: yearOptions,
              selected: selectedYears,
              onToggled: onYearToggled,
            ),
          ],
          if (courseOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ChipGroupRow(
              label: 'Course',
              options: courseOptions,
              selected: selectedCourses,
              onToggled: onCourseToggled,
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled row of multi-select chips. Values selected within a group are
/// OR-ed together (2025 + 2024 -> either admission year).
class _ChipGroupRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final Set<String> selected;
  final void Function(String) onToggled;
  const _ChipGroupRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggled,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Color(0xFF1A3C6E),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final o in options)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _SelectChip(
                      label: o,
                      selected: selected.contains(o),
                      onTap: () => onToggled(o),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A3C6E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1A3C6E) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : Colors.black87,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Table ───────────────────────────────────────────────────────────────────

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    separatorBuilder: (_, __) => const Divider(height: 1),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _HeaderCell(
            'Date Added',
            3,
            0,
            sortColumnIndex,
            sortAscending,
            onSort,
          ),
          _HeaderCell(
            'Student ID',
            3,
            1,
            sortColumnIndex,
            sortAscending,
            onSort,
          ),
          _HeaderCell('Name', 4, 2, sortColumnIndex, sortAscending, onSort),
          _HeaderCell(
            'Adm. Year',
            2,
            3,
            sortColumnIndex,
            sortAscending,
            onSort,
          ),
          _HeaderCell('Course', 2, 4, sortColumnIndex, sortAscending, onSort),
          const Expanded(
            flex: 4,
            child: Text(
              'Actions',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A3C6E),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
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

  const _HeaderCell(
    this.label,
    this.flex,
    this.col,
    this.sortColumnIndex,
    this.sortAscending,
    this.onSort,
  );

  @override
  Widget build(BuildContext context) {
    final active = sortColumnIndex == col;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => onSort(col, active ? !sortAscending : true),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A3C6E),
                fontSize: 13,
              ),
            ),
            if (active)
              Icon(
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: const Color(0xFF1A3C6E),
              ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Date Added
          Expanded(
            flex: 3,
            child: Text(
              student.createdAt == null ? '—' : _fmtDate(student.createdAt!),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          // Student ID
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3C6E).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  student.studentId.isEmpty ? '—' : student.studentId,
                  style: const TextStyle(
                    color: Color(0xFF1A3C6E),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
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
              child: Row(
                children: [
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
                        fontWeight: FontWeight.bold,
                      ),
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
                  student.photoUrl == null
                      ? Text("!", style: TextStyle(color: Colors.red))
                      : const SizedBox.shrink(),
                ],
              ),
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: _CourseBadge(course: student.nameOfCourse),
            ),
          ),
          // Actions
          Expanded(
            flex: 4,
            child: Row(
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
                if (student.photoUrl == null)
                  const Text(
                    "Missing Photo",
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ],
      ),
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
      Color(0xFF1A3C6E),
      Color(0xFF2E7D32),
      Color(0xFF6A1B9A),
      Color(0xFF00838F),
      Color(0xFF558B2F),
      Color(0xFF4527A0),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: _avatarColor(s.name),
            child: Text(
              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            s.name.isEmpty ? 'Unknown' : s.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (s.studentId.isNotEmpty)
                _SmallTag(label: s.studentId, color: const Color(0xFF1A3C6E)),
              if (s.nameOfCourse.isNotEmpty)
                _SmallTag(label: s.nameOfCourse, color: Colors.teal),
              if (s.yearOfAdmission != null)
                _SmallTag(
                  label: s.yearOfAdmission.toString(),
                  color: Colors.amber.shade800,
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
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Small helpers ───────────────────────────────────────────────────────────

String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

class _CourseBadge extends StatelessWidget {
  final String course;
  const _CourseBadge({required this.course});

  Color get _color {
    switch (course.trim().toUpperCase()) {
      case 'B.ED':
        return Colors.blue.shade700;
      case 'D.ED':
        return Colors.green.shade700;
      case 'M.ED':
        return Colors.purple.shade700;
      case 'D.P.ED':
        return Colors.orange.shade700;
      case 'SKILL':
      case 'SKILLING':
      case 'DDUGKY 2021':
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final String? emptyTitle;
  const _EmptyState({required this.hasFilters, this.emptyTitle});

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
            hasFilters
                ? 'No students match your search'
                : (emptyTitle ?? 'No students yet'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try different keywords or clear filters'
                : 'Tap + to add the first student',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
