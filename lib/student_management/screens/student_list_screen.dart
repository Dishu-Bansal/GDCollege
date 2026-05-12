import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gd_college/constants.dart';
import 'package:gd_college/widgets/drawer.dart';
import 'package:image_network/image_network.dart';
import '../models/student_model.dart';
import '../../services/firebase_student_service.dart';
import 'student_form_screen.dart';
import 'student_detail_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final FirebaseService _service = FirebaseService();

  // Filters
  final TextEditingController _searchIdCtrl = TextEditingController();
  final TextEditingController _searchNameCtrl = TextEditingController();
  String? _selectedCourse;
  String? _selectedYear;

  final List<StudentModel> _allLoaded = [];   // all pages fetched so far
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  bool _filtersVisible = false;

  // Sorting
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadNextPage();
    _scrollController.addListener(() {
      // Auto-load when user scrolls within 300px of the bottom
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        _loadNextPage();
      }
    });
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final result = await _service.fetchStudentsPage(startAfter: _lastDoc);

    setState(() {
      _allLoaded.addAll(result.students);
      _lastDoc = result.lastDoc;
      _hasMore = result.students.length == FirebaseService.pageSize;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _allLoaded.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    await _loadNextPage();
  }

  @override
  void dispose() {
    _searchIdCtrl.dispose();
    _searchNameCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
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
        await _service.deleteStudent(student.docId!);
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

  @override
  Widget build(BuildContext context) {
    final filtered = _applySort(_applyFilters(_allLoaded));
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Student Records',
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
            tooltip: 'Add Student',
            onPressed: _openAdd,
          ),
        ],
      ),
      drawer: getSideDrawer(context),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            // ── Filter Panel ──────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: _filtersVisible
                  ? _FilterPanel(
                      idCtrl: _searchIdCtrl,
                      nameCtrl: _searchNameCtrl,
                      selectedCourse: _selectedCourse,
                      courses: listOfCourses,
                      selectedYear: _selectedYear,
                      allYears: _allLoaded
                          .map((s) => s.yearOfAdmission?.toString() ?? '')
                          .where((y) => y.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort((a, b) => b.compareTo(a)),
                      hasActiveFilters: _hasActiveFilters,
                      onChanged: () => setState(() {}),
                      onCourseChanged: (v) =>
                          setState(() => _selectedCourse = v),
                      onYearChanged: (v) =>
                          setState(() => _selectedYear = v),
                      onClear: _clearFilters,
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Stats Bar ─────────────────────────────────────────────
            _StatsBar(total: _allLoaded.length, showing: filtered.length),

            // ── Table ─────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(hasFilters: _hasActiveFilters)
                  : _StudentTable(
                      students: filtered,
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      onSort: (col, asc) => setState(() {
                        _sortColumnIndex = col;
                        _sortAscending = asc;
                      }),
                      onView: _openDetail,
                      onEdit: _openEdit,
                      onDelete: _confirmDelete,
                      scrollController: _scrollController,
                      footer: _isLoading
                          ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                          : !_hasMore
                          ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'All ${_allLoaded.length} records loaded',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ),
                      )
                          : const SizedBox(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: const Color(0xFF1A3C6E),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Student',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
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

class _StudentTable extends StatelessWidget {
  final List<StudentModel> students;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final void Function(StudentModel) onView;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onDelete;
  final ScrollController scrollController;
  final Widget footer;

  const _StudentTable({
    required this.students,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.scrollController,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: isNarrow
                ? _MobileCardList(
                    scrollController: scrollController,
                    students: students,
                    onView: onView,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  )
                : _DataTable(
                    students: students,
                    sortColumnIndex: sortColumnIndex,
                    sortAscending: sortAscending,
                    onSort: onSort,
                    onView: onView,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
          ),
          footer,
        ],
      ),
    );
  }
}

// Desktop-style DataTable
class _DataTable extends StatelessWidget {
  final List<StudentModel> students;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final void Function(StudentModel) onView;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onDelete;

  const _DataTable({
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
    return SizedBox(
      width: double.infinity,
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
            label: const Text('Student ID'),
            onSort: (i, asc) => onSort(0, asc),
          ),
          DataColumn(
            label: const Text('Name'),
            onSort: (i, asc) => onSort(1, asc),
          ),
          DataColumn(
            label: const Text('Adm. Year'),
            numeric: true,
            onSort: (i, asc) => onSort(2, asc),
          ),
          DataColumn(
            label: const Text('Course'),
            onSort: (i, asc) => onSort(3, asc),
          ),
          const DataColumn(label: Text('Actions')),
        ],
        rows: students.asMap().entries.map((entry) {
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
                    s.studentId.isEmpty ? '—' : s.studentId,
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
                    if (s.photoUrl != null) ...[
                      ImageNetwork(image: s.photoUrl!, height: 50, width: 50, fitWeb: BoxFitWeb.fill, borderRadius: BorderRadius.all(Radius.circular(16),)),
                      const SizedBox(width: 8),
                    ] else ...[
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            const Color(0xFF1A3C6E).withOpacity(0.15),
                        child: Text(
                          s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A3C6E),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
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
                s.yearOfAdmission?.toString() ?? '—',
                textAlign: TextAlign.right,
              )),
              DataCell(_CourseBadge(course: s.nameOfCourse)),
              DataCell(_ActionButtons(
                student: s,
                onView: () => onView(s),
                onEdit: () => onEdit(s),
                onDelete: () => onDelete(s),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// Mobile card list (for narrow screens)
class _MobileCardList extends StatelessWidget {
  final List<StudentModel> students;
  final void Function(StudentModel) onView;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onDelete;
  final ScrollController scrollController;

  const _MobileCardList({
    required this.students,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final s = students[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF1A3C6E).withOpacity(0.15),
            backgroundImage:
                s.photoUrl != null ? NetworkImage(s.photoUrl!) : null,
            child: s.photoUrl == null
                ? Text(
                    s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Color(0xFF1A3C6E),
                        fontWeight: FontWeight.bold),
                  )
                : null,
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
                    color: Colors.amber.shade800),
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

class _ActionButtons extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionButtons({
    required this.student,
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
          onPressed: student.isLocked ? null : onEdit,
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
            hasFilters ? 'No students match your filters' : 'No students yet',
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
                : 'Tap the + button to add a student',
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
