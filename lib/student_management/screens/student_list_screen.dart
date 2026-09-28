import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gd_college/constants.dart';
import 'package:gd_college/widgets/drawer.dart';
import '../../access/widgets/access_gate.dart';
import '../../controllers/pagination_controller.dart';
import '../../models/audit_log.dart';
import '../models/student_facets.dart';
import '../models/student_model.dart';
import '../../repositories/student_repository.dart';
import '../../providers.dart';
import '../../widgets/pagination_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'student_form_screen.dart';
import 'student_detail_screen.dart';
import 'student_download_dialog.dart';

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
  int _tabIndex = 0;

  StudentRepository get _service => ref.read(studentRepositoryProvider);

  // One pagination controller per course-group tab. Each tab queries exactly
  // its own students server-side (browse pages, group search, DB totals).
  late final List<PaginationController> _pageCtrls;

  // Whole-collection chip options per group (one small meta read).
  StudentFacets _facets = StudentFacets.empty;

  // Per-group filter state (search text + chips). Results live in the
  // tab's PaginationController.
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
  // Per-group "Missing documents" filter. Backed by the denormalized
  // missingDocsCount flag (server query), narrowed further in memory.
  final List<bool> _missingDocsOnly = List.generate(
    _groupCount,
    (_) => false,
  );
  // Cached campus-wide incomplete fetch per tab (one read burst per toggle,
  // reused across filter/page changes) + the tab's current page.
  final List<Future<List<StudentModel>>?> _incompleteFutures =
      List.generate(_groupCount, (_) => null);
  final List<int> _missingPage = List.generate(_groupCount, (_) => 0);
  final List<Timer?> _debounce = List.generate(_groupCount, (_) => null);

  int _sortColumnIndex = 0; // 0 = Date Added
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _groupCount + 1, vsync: this);
    _tabs.addListener(_onTabChanged);
    final service = ref.read(studentRepositoryProvider);
    _pageCtrls = [
      for (final group in StudentGroup.values)
        PaginationController(service, group: group)..sorter = _compareStudents,
    ];
    for (final c in _pageCtrls) {
      c.loadBrowsePage(1);
    }
    _loadFacets();
  }

  void _onTabChanged() {
    // Rebuild only when the settled tab actually changes — not on every
    // animation tick while swiping.
    if (_tabs.index != _tabIndex && mounted) {
      setState(() => _tabIndex = _tabs.index);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    for (final t in _debounce) {
      t?.cancel();
    }
    for (final c in _searchCtrls) {
      c.dispose();
    }
    for (final c in _pageCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Whole-collection chip options ──────────────────────────────────

  Future<void> _loadFacets() async {
    try {
      final facets = await _service.fetchStudentFacets();
      if (!mounted) return;
      setState(() => _facets = facets);
    } catch (_) {
      // Chips stay empty; the list itself still works.
    }
  }

  /// Admission-year chips for tab [g]: every year present in the group's
  /// entire collection, newest first.
  List<String> _yearOptions(int g) {
    final group = StudentGroup.values[g].name;
    return [for (final y in _facets.yearsOf(group)) '$y'];
  }

  /// Course chips for tab [g]: every course present in the group's entire
  /// collection, in canonical course-list order.
  List<String> _courseOptions(int g) {
    final group = StudentGroup.values[g].name;
    final courses = _facets.coursesOf(group).toList();
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
  // ── Server-side search ───────────────────────────────────────────────
  //
  // When a tab has an active search text or chip filter, its content comes
  // from `StudentRepository.searchInGroup`, which queries the tab's group
  // across the ENTIRE collection (n-gram index for text, whereIn for
  // chips) — never just the loaded pages.

  bool _hasActiveFilters(int g) =>
      _searchCtrls[g].text.isNotEmpty ||
      _selectedYears[g].isNotEmpty ||
      _selectedCourses[g].isNotEmpty ||
      _missingDocsOnly[g];

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

  /// Runs the tab's group search over the whole collection. Selections are
  /// read live from the tab's filter state.
  Future<void> _runSearch(int g) {
    return _pageCtrls[g].runSearch(
      query: _searchCtrls[g].text.trim(),
      years: _selectedYears[g],
      courses: _selectedCourses[g],
    );
  }

  // ── Filter / sort handlers ───────────────────────────────────────────────

  void _onSearchChanged(int g, String _) {
    // Debounce: wait for a typing pause before hitting the server.
    _debounce[g]?.cancel();
    if (_missingDocsOnly[g]) {
      // Missing-docs mode filters the cached fetch: back to page 1.
      setState(() => _missingPage[g] = 0);
      return;
    }
    if (!_hasActiveFilters(g)) {
      _pageCtrls[g].resetToBrowse();
      return;
    }
    _debounce[g] = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(g),
    );
  }

  void _toggleYear(int g, String year) {
    setState(() {
      if (!_selectedYears[g].remove(year)) _selectedYears[g].add(year);
      _missingPage[g] = 0;
    });
    _filterChipsChanged(g);
  }

  void _toggleCourse(int g, String course) {
    setState(() {
      if (!_selectedCourses[g].remove(course)) _selectedCourses[g].add(course);
      _missingPage[g] = 0;
    });
    _filterChipsChanged(g);
  }

  /// Chips apply immediately (no debounce): group search, or back to the
  /// tab's browse pages when no filter remains. In missing-docs mode the
  /// server controller is idle — only the page resets.
  void _filterChipsChanged(int g) {
    if (_missingDocsOnly[g]) return;
    if (!_hasActiveFilters(g)) {
      _pageCtrls[g].resetToBrowse();
      return;
    }
    _runSearch(g);
  }

  void _toggleMissingDocs(int g) {
    setState(() {
      _missingDocsOnly[g] = !_missingDocsOnly[g];
      _missingPage[g] = 0;
      if (_missingDocsOnly[g]) {
        // One read burst; reused across filter/page changes while active.
        _incompleteFutures[g] ??= _service.fetchIncompleteStudents();
      } else {
        _incompleteFutures[g] = null;
      }
    });
    // Leaving missing-docs mode returns to browse/search.
    if (!_missingDocsOnly[g]) _filterChipsChanged(g);
  }

  /// Re-runs the tab's incomplete fetch (e.g. after editing uploads).
  void _refreshMissingDocs(int g) {
    setState(() {
      _missingPage[g] = 0;
      _incompleteFutures[g] = _service.fetchIncompleteStudents();
    });
  }

  void _setMissingPage(int g, int page) {
    setState(() => _missingPage[g] = page);
  }

  void _clearFilters(int g) {
    _debounce[g]?.cancel();
    setState(() {
      _searchCtrls[g].clear();
      _selectedYears[g].clear();
      _selectedCourses[g].clear();
      _missingDocsOnly[g] = false;
      _missingPage[g] = 0;
      _incompleteFutures[g] = null;
    });
    _pageCtrls[g].resetToBrowse();
  }

  Future<void> _clearAllFilters() async {
    for (var g = 0; g < _groupCount; g++) {
      _debounce[g]?.cancel();
      _searchCtrls[g].clear();
      _selectedYears[g].clear();
      _selectedCourses[g].clear();
      _missingDocsOnly[g] = false;
      _missingPage[g] = 0;
      _incompleteFutures[g] = null;
    }
    setState(() {});
    // Back to page 1 of each tab's browse view, then fresh chip options.
    await Future.wait([for (final c in _pageCtrls) c.resetToBrowse()]);
    if (mounted) await _loadFacets();
  }

  /// Header sort: column → Firestore field. Browse tabs re-query the whole
  /// group server-side (sort spans all students); filtered tabs re-sort
  /// their full fetched result set.
  static const _sortFields = [
    'createdAt', // 0 = Date Added
    'studentId', // 1 = Student ID
    'name', // 2 = Name
    'yearOfAdmission', // 3 = Adm. Year
    'nameOfCourse', // 4 = Course
  ];

  void _onSort(int col, bool asc) {
    setState(() {
      _sortColumnIndex = col;
      _sortAscending = asc;
    });
    // Search-mode tabs keep their client ordering in sync; browse tabs
    // reload page 1 in the new server order.
    for (final c in _pageCtrls) {
      c.sorter = _compareStudents;
      c.setSort(_sortFields[col], !asc);
    }
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
        if (!mounted) return;
        // A delete can empty a chip value or shift pages: re-read the
        // current views (pages + DB totals) and the chip options.
        await _refreshAfterMutation();
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
    if (mounted) await _refreshAfterMutation();
  }

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentFormScreen()),
    );
    if (mounted) await _refreshAfterMutation();
  }

  /// Download popup for the current tab's group, pre-seeded with the tab's
  /// year/course chip selections.
  void _openDownload(int g) {
    showStudentDownloadDialog(
      context: context,
      group: StudentGroup.values[g],
      service: _service,
      yearOptions: _yearOptions(g),
      initialYears: _selectedYears[g],
      courseOptions: _courseOptions(g),
      initialCourses: _selectedCourses[g],
    );
  }

  /// Re-reads every tab's current view (pages + DB totals) and the
  /// whole-collection chip options. Used after add/edit/delete, where group
  /// membership, totals, or facet values may have changed.
  Future<void> _refreshAfterMutation() async {
    await Future.wait([for (final c in _pageCtrls) c.refresh()]);
    if (mounted) await _loadFacets();
  }

  @override
  Widget build(BuildContext context) {
    return AccessGate(
      module: 'Student Management',
      canAccess: (s) => s.canAccessStudents,
      drawer: getSideDrawer(context),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final bool showGroupActions = _tabIndex < _groupCount;

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
              onPressed: _clearAllFilters,
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Download Excel',
              onPressed: () => _openDownload(_tabIndex),
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
          tabs: [
            for (final g in StudentGroup.values)
              Tab(icon: Icon(_groupIcon(g), size: 18), text: g.label),
            const Tab(icon: Icon(Icons.history, size: 18), text: 'Global Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (var g = 0; g < _groupCount; g++)
            _GroupStudentsTab(
              title: StudentGroup.values[g].label,
              group: StudentGroup.values[g],
              controller: _pageCtrls[g],
              searchCtrl: _searchCtrls[g],
              yearOptions: _yearOptions(g),
              selectedYears: _selectedYears[g],
              courseOptions: _courseOptions(g),
              selectedCourses: _selectedCourses[g],
              hasActiveFilters: _hasActiveFilters(g),
              missingDocsOnly: _missingDocsOnly[g],
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              onSort: _onSort,
              onSearchChanged: (v) => _onSearchChanged(g, v),
              onYearToggled: (v) => _toggleYear(g, v),
              onCourseToggled: (v) => _toggleCourse(g, v),
              onMissingDocsToggled: () => _toggleMissingDocs(g),
              onClear: () => _clearFilters(g),
              onView: _openDetail,
              onEdit: _openEdit,
              onDelete: _confirmDelete,
              sorter: _compareStudents,
              incompleteFuture: _incompleteFutures[g],
              missingPage: _missingPage[g],
              onMissingPageChanged: (p) => _setMissingPage(g, p),
              onMissingRefresh: () => _refreshMissingDocs(g),
            ),
          _StudentGlobalLogTab(service: _service),
        ],
      ),
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

// ── One course-group tab (GD College / MLSN / Skill India) ─────────────────
// The tab shows exactly its group's students: paged browse or whole-group
// search, driven by its PaginationController. Totals and chip options come
// from the database, never from loaded pages.

class _GroupStudentsTab extends StatelessWidget {
  final String title;
  final StudentGroup group;
  final PaginationController controller;
  final TextEditingController searchCtrl;
  final List<String> yearOptions;
  final Set<String> selectedYears;
  final List<String> courseOptions;
  final Set<String> selectedCourses;
  final bool hasActiveFilters;
  final bool missingDocsOnly;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final ValueChanged<String> onSearchChanged;
  final void Function(String) onYearToggled;
  final void Function(String) onCourseToggled;
  final VoidCallback onMissingDocsToggled;
  final VoidCallback onClear;
  final void Function(StudentModel) onView;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onDelete;
  final int Function(StudentModel, StudentModel) sorter;
  final Future<List<StudentModel>>? incompleteFuture;
  final int missingPage;
  final void Function(int page) onMissingPageChanged;
  final VoidCallback onMissingRefresh;

  const _GroupStudentsTab({
    required this.title,
    required this.group,
    required this.controller,
    required this.searchCtrl,
    required this.yearOptions,
    required this.selectedYears,
    required this.courseOptions,
    required this.selectedCourses,
    required this.hasActiveFilters,
    required this.missingDocsOnly,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.onSearchChanged,
    required this.onYearToggled,
    required this.onCourseToggled,
    required this.onMissingDocsToggled,
    required this.onClear,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.sorter,
    required this.incompleteFuture,
    required this.missingPage,
    required this.onMissingPageChanged,
    required this.onMissingRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final loadingInitial =
            controller.isLoading && controller.students.isEmpty;
        return Column(
          children: [
            _SearchChipsPanel(
              searchCtrl: searchCtrl,
              yearOptions: yearOptions,
              selectedYears: selectedYears,
              courseOptions: courseOptions,
              selectedCourses: selectedCourses,
              hasActiveFilters: hasActiveFilters,
              missingDocsOnly: missingDocsOnly,
              onSearchChanged: onSearchChanged,
              onYearToggled: onYearToggled,
              onCourseToggled: onCourseToggled,
              onMissingDocsToggled: onMissingDocsToggled,
              onClear: onClear,
            ),
            if (controller.error != null)
              Container(
                color: Colors.red.shade50,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.error!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: missingDocsOnly
                  ? _MissingDocsList(
                      group: group,
                      future: incompleteFuture,
                      query: searchCtrl.text.trim(),
                      years: selectedYears,
                      courses: selectedCourses,
                      sorter: sorter,
                      page: missingPage,
                      onView: onView,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      onPageChanged: onMissingPageChanged,
                      onRefresh: onMissingRefresh,
                    )
                  : loadingInitial
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                                Color(0xFF1A3C6E)),
                          ),
                        )
                      : controller.students.isEmpty
                          ? _EmptyState(
                              hasFilters: hasActiveFilters,
                              emptyTitle: !hasActiveFilters &&
                                      controller.totalCount == 0
                                  ? 'No $title students yet'
                                  : null,
                            )
                          : _StudentTable(
                              students: controller.students,
                              sortColumnIndex: sortColumnIndex,
                              sortAscending: sortAscending,
                              onSort: onSort,
                              onView: onView,
                              onEdit: onEdit,
                              onDelete: onDelete,
                            ),
            ),
            if (!missingDocsOnly)
              PaginationBar(controller: controller),
          ],
        );
      },
    );
  }
}

// ── Missing-documents mode ──────────────────────────────────────────────────
// One cached server-flagged fetch, narrowed in memory by group/text/chips,
// shown 50 per page (1300+ incomplete records would stall a single list).

class _MissingDocsList extends StatelessWidget {
  static const int pageSize = 50;

  final StudentGroup group;
  final Future<List<StudentModel>>? future;
  final String query;
  final Set<String> years;
  final Set<String> courses;
  final int Function(StudentModel, StudentModel) sorter;
  final int page;
  final void Function(StudentModel) onView;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onDelete;
  final void Function(int page) onPageChanged;
  final VoidCallback onRefresh;

  const _MissingDocsList({
    required this.group,
    required this.future,
    required this.query,
    required this.years,
    required this.courses,
    required this.sorter,
    required this.page,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onPageChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudentModel>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF1A3C6E)),
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text('Error: ${snap.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        final q = query.toLowerCase();
        final incomplete = (snap.data ?? []).where((s) {
          if (s.group != group.name) return false;
          if (q.isNotEmpty &&
              !s.name.toLowerCase().contains(q) &&
              !s.studentId.toLowerCase().contains(q)) {
            return false;
          }
          if (years.isNotEmpty &&
              !years.contains(s.yearOfAdmission?.toString())) {
            return false;
          }
          if (courses.isNotEmpty && !courses.contains(s.nameOfCourse)) {
            return false;
          }
          return true;
        }).toList()
          ..sort(sorter);
        final pageCount =
            (incomplete.length / pageSize).ceil().clamp(1, 1 << 30);
        final safePage = page.clamp(0, pageCount - 1);
        final pageItems = incomplete
            .skip(safePage * pageSize)
            .take(pageSize)
            .toList();
        if (incomplete.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined,
                    size: 56, color: Colors.green.shade300),
                const SizedBox(height: 12),
                Text(
                  'All documents complete',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${incomplete.length} student${incomplete.length == 1 ? '' : 's'} missing documents',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onRefresh,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.refresh,
                          size: 16, color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _StudentTable(
                students: pageItems,
                sortColumnIndex: -1,
                sortAscending: true,
                onSort: (_, __) {},
                onView: onView,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
            _MissingDocsPager(
              page: safePage,
              pageCount: pageCount,
              total: incomplete.length,
              onPageChanged: onPageChanged,
            ),
          ],
        );
      },
    );
  }
}

/// Prev/next pager for missing-docs mode (50 per page).
class _MissingDocsPager extends StatelessWidget {
  final int page;
  final int pageCount;
  final int total;
  final void Function(int page) onPageChanged;

  const _MissingDocsPager({
    required this.page,
    required this.pageCount,
    required this.total,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) {
      return Container(
        width: double.infinity,
        color: Colors.grey.shade100,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          'Showing all $total',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      );
    }
    return Container(
      color: Colors.grey.shade100,
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
            onPressed:
                page > 0 ? () => onPageChanged(page - 1) : null,
          ),
          Text(
            'Page ${page + 1} of $pageCount · $total students',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
            onPressed: page < pageCount - 1
                ? () => onPageChanged(page + 1)
                : null,
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
  final bool missingDocsOnly;
  final ValueChanged<String> onSearchChanged;
  final void Function(String) onYearToggled;
  final void Function(String) onCourseToggled;
  final VoidCallback onMissingDocsToggled;
  final VoidCallback onClear;
  const _SearchChipsPanel({
    required this.searchCtrl,
    required this.yearOptions,
    required this.selectedYears,
    required this.courseOptions,
    required this.selectedCourses,
    required this.hasActiveFilters,
    required this.missingDocsOnly,
    required this.onSearchChanged,
    required this.onYearToggled,
    required this.onCourseToggled,
    required this.onMissingDocsToggled,
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Missing documents',
                  style: TextStyle(fontSize: 12)),
              avatar: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: missingDocsOnly
                    ? Colors.white
                    : Colors.red.shade700,
              ),
              selected: missingDocsOnly,
              onSelected: (_) => onMissingDocsToggled(),
              tooltip:
                  'Show only students missing required documents',
              selectedColor: Colors.red.shade600,
              labelStyle: TextStyle(
                color: missingDocsOnly
                    ? Colors.white
                    : Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: Colors.red.shade300),
            ),
          ),
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
                      ? const Text("!",
                          style: TextStyle(color: Colors.red))
                      : const SizedBox.shrink(),
                  _DocsAlert(student: student),
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
              if (s.missingDocsCount > 0)
                Tooltip(
                  message: 'Missing: ${s.missingDocs.join(', ')}',
                  child: _SmallTag(
                      label: 'Docs missing', color: Colors.red),
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

/// Red warning on a student row when required documents are missing.
/// Driven by the stored denormalized flags (refreshed on every save).
class _DocsAlert extends StatelessWidget {
  final StudentModel student;
  const _DocsAlert({required this.student});

  @override
  Widget build(BuildContext context) {
    if (student.missingDocsCount <= 0) return const SizedBox.shrink();
    return Tooltip(
      message: 'Missing documents: ${student.missingDocs.join(', ')}',
      child: const Icon(Icons.warning_amber_rounded,
          size: 16, color: Colors.red),
    );
  }
}

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
