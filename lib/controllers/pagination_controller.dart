import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import '../repositories/student_repository.dart';
import '../student_management/models/student_model.dart';

enum PageMode { browse, search }

/// Per-tab pagination over exactly one course group.
///
/// Browse mode pages server-side through the tab's own students
/// ([StudentRepository.fetchGroupPage]); search mode runs
/// ([StudentRepository.searchInGroup]) over the whole collection restricted
/// to the tab's group and slices client-side. Totals always come from the
/// database ([StudentRepository.countGroup]), never from loaded pages.
class PaginationController extends ChangeNotifier {
  static final DateTime _oldest = DateTime.fromMillisecondsSinceEpoch(0);

  final StudentRepository _service;
  final StudentGroup group;

  PaginationController(this._service, {required this.group});

  /// Client-side ordering applied to loaded pages/results. Defaults to Date
  /// Added, newest first (matches the server browse order, so it is a no-op
  /// until the user picks another sort column).
  Comparator<StudentModel> sorter = _byDateAddedDesc;

  static int _byDateAddedDesc(StudentModel a, StudentModel b) =>
      (b.createdAt ?? _oldest).compareTo(a.createdAt ?? _oldest);

  /// Re-applies [sorter] to whatever is currently displayed.
  void resort() {
    students.sort(sorter);
    notifyListeners();
  }

  // Shared state
  List<StudentModel> students = [];
  bool isLoading = false;
  String? error;

  // ── Browse state ──────────────────────────────────────────────────────────
  int _browsePage = 1;
  int _browseTotal = 0;
  final Map<int, DocumentSnapshot> _cursors = {};

  // ── Search state ──────────────────────────────────────────────────────────
  List<StudentModel> _allSearchResults = [];
  int _searchPage = 1;
  String _lastQuery = '';
  Set<String> _lastYears = const {};
  Set<String> _lastCourses = const {};
  int _searchSeq = 0;

  // ── Mode ──────────────────────────────────────────────────────────────────
  PageMode _mode = PageMode.browse;
  bool get isSearchMode => _mode == PageMode.search;

  // ── Derived getters ───────────────────────────────────────────────────────
  int get currentPage =>
      isSearchMode ? _searchPage : _browsePage;

  int get totalCount =>
      isSearchMode ? _allSearchResults.length : _browseTotal;

  int get totalPages =>
      (totalCount / StudentRepository.pageSize).ceil().clamp(1, 999999);

  bool get hasPrev => currentPage > 1;
  bool get hasNext => currentPage < totalPages;

  // ── Browse ────────────────────────────────────────────────────────────────

  Future<void> loadBrowsePage(int page) async {
    if (isLoading) return;
    _mode = PageMode.browse;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      // Need cursor for page-1 to get to page
      final startAfter = page > 1 ? _cursors[page - 1] : null;

      // If we need a cursor we don't have, walk forward from last known
      if (page > 1 && startAfter == null) {
        await _walkTo(page);
        return;
      }

      final result = await _service.fetchGroupPage(
        group: group,
        startAfter: startAfter,
      );

      if (result.lastDoc != null) {
        _cursors[page] = result.lastDoc!;
      }

      _browseTotal = await _service.countGroup(group);

      students = List<StudentModel>.of(result.students)..sort(sorter);
      _browsePage = page;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Walk forward page by page until we reach target, caching cursors
  Future<void> _walkTo(int target) async {
    // Find highest cached page below target as starting point
    DocumentSnapshot? cursor;
    int startPage = 1;
    for (int p = target - 1; p >= 1; p--) {
      if (_cursors.containsKey(p)) {
        cursor = _cursors[p];
        startPage = p + 1;
        break;
      }
    }

    for (int p = startPage; p <= target; p++) {
      final result = await _service.fetchGroupPage(
        group: group,
        startAfter: cursor,
      );
      if (result.lastDoc != null) {
        _cursors[p] = result.lastDoc!;
        cursor = result.lastDoc;
      }
      if (p == target) {
        students = List<StudentModel>.of(result.students)..sort(sorter);
        _browsePage = target;
      }
    }

    _browseTotal = await _service.countGroup(group);
    isLoading = false;
    notifyListeners();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> runSearch({
    required String query,
    Set<String>? years,
    Set<String>? courses,
  }) async {
    final seq = ++_searchSeq;
    _mode = PageMode.search;
    isLoading = true;
    error = null;
    _searchPage = 1;
    _lastQuery = query;
    _lastYears = years ?? const {};
    _lastCourses = courses ?? const {};
    notifyListeners();

    try {
      final results = await _service.searchInGroup(
        group: group,
        query: query,
        years: years,
        courses: courses,
      );
      // Drop stale responses from an older keystroke/chip tap.
      if (seq != _searchSeq) return;
      results.sort(sorter);
      _allSearchResults = results;
      students = _pageSlice(1);
    } catch (e) {
      if (seq != _searchSeq) return;
      error = e.toString();
      _allSearchResults = [];
      students = [];
    } finally {
      if (seq == _searchSeq) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void goToSearchPage(int page) {
    if (!isSearchMode) return;
    _searchPage = page.clamp(1, totalPages);
    students = _pageSlice(_searchPage);
    notifyListeners();
  }

  List<StudentModel> _pageSlice(int page) {
    final start = (page - 1) * StudentRepository.pageSize;
    final end = (start + StudentRepository.pageSize)
        .clamp(0, _allSearchResults.length);
    if (start >= _allSearchResults.length) return [];
    return _allSearchResults.sublist(start, end);
  }

  // ── Navigation (works for both modes) ────────────────────────────────────

  void next() {
    if (!hasNext) return;
    _navigate(currentPage + 1);
  }

  void prev() {
    if (!hasPrev) return;
    _navigate(currentPage - 1);
  }

  void first() => _navigate(1);
  void last() => _navigate(totalPages);
  void jumpTo(int page) => _navigate(page.clamp(1, totalPages));

  void _navigate(int page) {
    if (isSearchMode) {
      goToSearchPage(page);
    } else {
      loadBrowsePage(page);
    }
  }

  // ── Refresh ───────────────────────────────────────────────────────────────
  // Re-reads the current view after a mutation. Falls back to page 1 when
  // the current page can no longer load.

  Future<void> refresh() async {
    if (isSearchMode) {
      await runSearch(
        query: _lastQuery,
        years: _lastYears,
        courses: _lastCourses,
      );
      return;
    }
    await loadBrowsePage(currentPage);
    if (error != null) {
      _cursors.clear();
      await loadBrowsePage(1);
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  Future<void> resetToBrowse() async {
    _mode = PageMode.browse;
    _allSearchResults = [];
    _searchPage = 1;
    _lastQuery = '';
    _lastYears = const {};
    _lastCourses = const {};
    _cursors.clear();
    students = [];
    _browsePage = 1;
    _browseTotal = 0;
    await loadBrowsePage(1);
  }
}
