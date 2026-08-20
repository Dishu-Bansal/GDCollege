import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../repositories/student_repository.dart';
import '../student_management/models/student_model.dart';

enum PageMode { browse, search }

class PaginationController extends ChangeNotifier {
  static final DateTime _oldest = DateTime.fromMillisecondsSinceEpoch(0);

  final StudentRepository _service;

  PaginationController(this._service);

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

      final result = await _service.fetchPage(startAfter: startAfter);

      if (result.lastDoc != null) {
        _cursors[page] = result.lastDoc!;
      }

      // Get total from meta doc
      final meta = await FirebaseFirestore.instance
          .collection('_meta')
          .doc('students')
          .get();
      _browseTotal = (meta.data()?['count'] ?? 0) as int;

      students = result.students;
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
      final result = await _service.fetchPage(startAfter: cursor);
      if (result.lastDoc != null) {
        _cursors[p] = result.lastDoc!;
        cursor = result.lastDoc;
      }
      if (p == target) {
        students = result.students;
        _browsePage = target;
      }
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> runSearch({
    required String query,
    String? course,
    String? year,
  }) async {
    if (isLoading) return;
    _mode = PageMode.search;
    isLoading = true;
    error = null;
    _searchPage = 1;
    notifyListeners();

    try {
      _allSearchResults = await _service.search(
        query: query,
        course: course,
        year: year,
      );
      // Keep the default view (Date Added, newest first) consistent across
      // pages — Firestore returns search results without a guaranteed order.
      _allSearchResults.sort((a, b) =>
          (b.createdAt ?? _oldest).compareTo(a.createdAt ?? _oldest));
      students = _pageSlice(1);
    } catch (e) {
      error = e.toString();
      _allSearchResults = [];
      students = [];
    } finally {
      isLoading = false;
      notifyListeners();
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

  // ── Reset ─────────────────────────────────────────────────────────────────

  void resetToBrowse() {
    _mode = PageMode.browse;
    _allSearchResults = [];
    _searchPage = 1;
    _cursors.clear();
    students = [];
    _browsePage = 1;
    _browseTotal = 0;
    loadBrowsePage(1);
  }
}
