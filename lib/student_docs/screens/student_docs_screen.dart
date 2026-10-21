import 'package:flutter/material.dart';
import '../../../access/widgets/access_gate.dart';
import '../../../constants.dart';
import '../../../widgets/drawer.dart';
import '../models/student_doc_models.dart';
import '../services/firebase_student_docs_service.dart';
import '../widgets/photo_viewer.dart';
import 'student_doc_detail_screen.dart';

/// Student Docs: batch-wise DMC + Degree tracking.
///
/// Three tabs (GD College / MLSN / Skill India), each with a year dropdown
/// and a course dropdown. Only the selected batch loads — never the whole
/// student list. Tapping a student opens their DMC/Degree workspace.
class StudentDocsScreen extends StatefulWidget {
  const StudentDocsScreen({super.key});

  @override
  State<StudentDocsScreen> createState() => _StudentDocsScreenState();
}

class _StudentDocsScreenState extends State<StudentDocsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccessGate(
      module: 'DMC & Degrees',
      canAccess: (s) => s.canAccessStudentDocs,
      drawer: getSideDrawer(context),
      child: _content(),
    );
  }

  Widget _content() {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      drawer: getSideDrawer(context),
      appBar: AppBar(
        title: const Text('DMC & Degrees',
            style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'GD College'),
            Tab(text: 'MLSN'),
            Tab(text: 'Skill India'),
            Tab(text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _BatchTab(
            key: const ValueKey('gd'),
            group: StudentGroup.gdCollege.name,
            courses: gdCollegeCourses.toList()..sort(),
            isNarrow: isNarrow,
          ),
          _BatchTab(
            key: const ValueKey('mlsn'),
            group: StudentGroup.mlsn.name,
            courses: mlsnCourses.toList()..sort(),
            isNarrow: isNarrow,
          ),
          _BatchTab(
            key: const ValueKey('skill'),
            group: StudentGroup.skillIndia.name,
            courses: const [],
            isNarrow: isNarrow,
          ),
          const _DocLogsTab(),
        ],
      ),
    );
  }
}

// ── One college tab ──────────────────────────────────────────────────────────

class _BatchTab extends StatefulWidget {
  final String group;
  final List<String> courses;
  final bool isNarrow;

  const _BatchTab({
    super.key,
    required this.group,
    required this.courses,
    required this.isNarrow,
  });

  @override
  State<_BatchTab> createState() => _BatchTabState();
}

class _BatchTabState extends State<_BatchTab>
    with AutomaticKeepAliveClientMixin {
  final _service = FirebaseStudentDocsService();
  final _searchCtrl = TextEditingController();

  late int _year;
  String? _course; // null = All courses
  Future<List<DocBatchEntry>>? _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<int> get _years {
    final now = DateTime.now().year;
    return [for (var y = now; y >= now - 8; y--) y];
  }

  void _reload() {
    setState(() {
      _future = _service.fetchBatch(
        group: widget.group,
        course: _course,
        year: _year,
      );
    });
  }

  List<DocBatchEntry> _applySearch(List<DocBatchEntry> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return all;
    return all
        .where((e) => e.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _filterBar(),
        Expanded(
          child: FutureBuilder<List<DocBatchEntry>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _errorState(snap.error.toString());
              }
              final all = _applySearch(snap.data ?? []);
              if (all.isEmpty) {
                return _emptyState(snap.data?.isEmpty ?? true);
              }
              final fullyDone = all
                  .where((e) =>
                      e.dmcProgress().$1 == e.dmcProgress().$2 &&
                      e.terminalDone())
                  .length;
              // Stock vs issued across the batch: a slot is "in stock"
              // once its scan sits with the office, "issued" once a
              // collector with full identity takes it.
              var dmcStock = 0, dmcIssued = 0;
              var termStock = 0, termIssued = 0;
              for (final e in all) {
                for (final s in docSlotsForCourse(e.course)) {
                  final rec = e.records[s.key];
                  if (rec == null || !rec.inStock) continue;
                  if (s.isDmc) {
                    dmcStock++;
                    if (rec.issued(isDmc: true)) dmcIssued++;
                  } else {
                    termStock++;
                    if (rec.issued(isDmc: false)) termIssued++;
                  }
                }
              }
              return Column(
                children: [
                  _summaryBar(
                    all.length,
                    fullyDone,
                    dmcStock: dmcStock,
                    dmcIssued: dmcIssued,
                    termStock: termStock,
                    termIssued: termIssued,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => _reload(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: all.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _StudentRow(
                          entry: all[i],
                          onOpen: () => _openDetail(all[i]),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _year,
                  decoration: const InputDecoration(
                    labelText: 'Admission Year',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: _years
                      .map((y) => DropdownMenuItem(
                          value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _year = v;
                      _reload();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: widget.courses.isEmpty
                    ? DropdownButtonFormField<String>(
                        initialValue: 'All',
                        decoration: const InputDecoration(
                          labelText: 'Course',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'All', child: Text('All'))
                        ],
                        onChanged: (_) {},
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _course ?? 'All',
                        decoration: const InputDecoration(
                          labelText: 'Course',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: 'All', child: Text('All')),
                          for (final c in widget.courses)
                            DropdownMenuItem(
                                value: c, child: Text(c)),
                        ],
                        onChanged: (v) {
                          _course = v == 'All' ? null : v;
                          _reload();
                        },
                      ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.refresh_outlined),
                tooltip: 'Reload batch',
                onPressed: _reload,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search student in this batch',
              hintStyle:
                  TextStyle(fontSize: 13, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search,
                  size: 18, color: Color(0xFF1A3C6E)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          setState(() => _searchCtrl.clear()),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBar(
    int total,
    int done, {
    required int dmcStock,
    required int dmcIssued,
    required int termStock,
    required int termIssued,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3C6E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total student${total == 1 ? '' : 's'}  •  $done fully complete',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A3C6E)),
          ),
          const SizedBox(height: 2),
          Text(
            'DMC — in stock: $dmcStock  •  issued: $dmcIssued'
            '      Degree/Cert — in stock: $termStock  •  issued: $termIssued',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool noBatch) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              noBatch ? 'No students in this batch' : 'No matches',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              noBatch
                  ? 'Try a different year or course.'
                  : 'Try a different search.',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String error) {
    final needsIndex = error.contains('index');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              needsIndex
                  ? 'This batch view needs a one-time database index.\nOpen the app error link in the debug console, or create a composite index on students (group, nameOfCourse, yearOfAdmission) in the Firebase console.'
                  : 'Could not load this batch.\n$error',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _reload, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(DocBatchEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDocDetailScreen(
          studentId: entry.id,
          studentName: entry.name,
          course: entry.course,
          yearOfAdmission: entry.yearOfAdmission,
        ),
      ),
    );
    _reload();
  }
}

// ── One student row ──────────────────────────────────────────────────────────

class _StudentRow extends StatelessWidget {
  final DocBatchEntry entry;
  final VoidCallback onOpen;

  const _StudentRow({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final (dmcDone, dmcTotal) = entry.dmcProgress();
    final terminalDone = entry.terminalDone();
    final terminalLabel =
        docSlotsForCourse(entry.course).any((s) => s.key == 'degree')
            ? 'Degree'
            : 'Certificate';
    final allDone = dmcDone == dmcTotal && terminalDone;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: allDone
                ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.studentId.isNotEmpty)
                        Container(
                          margin:
                              const EdgeInsets.only(right: 8, top: 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3C6E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.studentId,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Colors.black87),
                            children: [
                              TextSpan(text: entry.name),
                              if (entry.fatherName.isNotEmpty)
                                TextSpan(
                                  text:
                                      '  S/o ${entry.fatherName}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _CourseChip(
                        entry.course.isEmpty
                            ? 'Course not set'
                            : entry.course,
                      ),
                      _Chip(
                        'DMC $dmcDone/$dmcTotal',
                        done: dmcDone == dmcTotal,
                      ),
                      _Chip(
                        '$terminalLabel ${terminalDone ? "✓" : "…"}',
                        done: terminalDone,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_outlined,
                color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _CourseChip extends StatelessWidget {
  final String text;

  const _CourseChip(this.text);

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF1A3C6E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool done;

  const _Chip(this.text, {required this.done});

  @override
  Widget build(BuildContext context) {
    final color =
        done ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Logs tab ─────────────────────────────────────────────────────────────────

/// Most recent doc stock/issue events across all batches, newest first —
/// the same log pattern as the other modules.
class _DocLogsTab extends StatelessWidget {
  const _DocLogsTab();

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DocLogEntry>>(
      stream: FirebaseStudentDocsService().watchRecentDocLogs(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load logs.\n${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          );
        }
        final logs = snap.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_outlined,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'No doc activity yet',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uploading a scan logs “stocked”;\ncompleting the collector logs “issued”.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final log = logs[i];
            final color = log.stocked
                ? const Color(0xFF1565C0)
                : log.issued
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFEF6C00);
            final icon = log.stocked
                ? Icons.inventory_2_outlined
                : log.issued
                    ? Icons.handshake_outlined
                    : Icons.edit_outlined;
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
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DOC ${log.action} — ${log.studentName}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${log.slotLabel}'
                          '${log.course.isNotEmpty ? '  •  ${log.course}' : ''}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600),
                        ),
                        if (log.issued &&
                            (log.collectorName.isNotEmpty ||
                                log.collectorAadhar.isNotEmpty)) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32)
                                  .withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (log.collectorName.isNotEmpty)
                                  Text(
                                    'Collector: ${log.collectorName}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                if (log.collectorAadhar.isNotEmpty)
                                  Text(
                                    'Aadhaar: ${log.collectorAadhar}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            Colors.grey.shade700),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        for (final change in log.changes) ...[
                          const SizedBox(height: 4),
                          if (change.isFileChange)
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                MiniThumb(
                                    label: 'Old',
                                    url: change.oldUrl),
                                const SizedBox(width: 6),
                                MiniThumb(
                                    label: 'New',
                                    url: change.newUrl),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(top: 4),
                                    child: Text(
                                      change.field,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700),
                                children: [
                                  TextSpan(
                                    text: '${change.field}: ',
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        color: Colors.black87),
                                  ),
                                  TextSpan(
                                      text: change.oldValue),
                                  const TextSpan(text: '  →  '),
                                  TextSpan(
                                    text: change.newValue,
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${_fmtDateTime(log.timestamp)}${log.changedBy.isNotEmpty ? '  •  by ${log.changedBy}' : ''}',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
