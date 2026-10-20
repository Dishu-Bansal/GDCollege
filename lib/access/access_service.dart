import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../providers.dart';
import 'app_session.dart';

/// Resolves the signed-in user's access flags live from Firestore.
///
/// The admin address is hardcoded here and always has full access. Every
/// other account gets a `users/{uid}` document (auto-created with defaults
/// on first login); the admin edits its flags from the Access Management
/// screen and changes stream to signed-in devices live.
class AccessService {
  /// Hardcoded admin emails (compared case-insensitively).
  static const List<String> adminEmails = [
    'dishubansal@lklms.com',
  ];

  static bool isAdminEmail(String? email) =>
      adminEmails.contains((email ?? '').trim().toLowerCase());

  /// App-wide shared access state. Every drawer, gate and card must use
  /// [watchAccessShared] (never a fresh `watchAccess()`) so all screens
  /// resolve the same session — and so the app holds one `users/{uid}`
  /// listener instead of one per widget.
  ///
  /// A plain broadcast stream is NOT enough here: it does not replay, so a
  /// screen subscribing after the single emission (e.g. opening Access
  /// Management later) would wait forever. Each caller therefore gets its
  /// own stream that first replays the latest value, then follows live.
  ///
  /// The per-caller stream is broadcast-insulated: even if the framework
  /// ever attaches twice to the same instance (drawer open/close cycles,
  /// route transitions), it degrades to live-only for the second
  /// attachment instead of throwing "Stream has already been listened to".
  ///
  /// The replay is bound to the account signed in at subscribe time: a
  /// session cached from a previous login on this device is only replayed
  /// when its uid still matches the current user. Otherwise the caller
  /// goes straight to the live stream, so a newly signed-in account can
  /// never briefly (or permanently, if its own read stalls) see the
  /// previous account's screens.
  static final StreamController<AppSession?> _sharedController =
      StreamController<AppSession?>.broadcast();
  static AppSession? _latestAccess;
  static bool _hasLatestAccess = false;
  static bool _sharedStarted = false;

  static Stream<AppSession?> watchAccessShared() {
    if (!_sharedStarted) {
      _sharedStarted = true;
      AccessService().watchAccess().listen(
        (s) {
          _latestAccess = s;
          _hasLatestAccess = true;
          if (!_sharedController.isClosed) _sharedController.add(s);
        },
        onError: (Object e) {
          if (!_sharedController.isClosed) _sharedController.addError(e);
        },
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _replayThenLive(uid).asBroadcastStream(
      // Tear down the per-caller generator when its last listener leaves
      // so rebuilt screens don't accumulate dead subscriptions.
      onCancel: (sub) => sub.cancel(),
    );
  }

  static Stream<AppSession?> _replayThenLive(String? uid) async* {
    if (_hasLatestAccess && uid != null && _latestAccess?.uid == uid) {
      yield _latestAccess;
    }
    yield* _sharedController.stream;
  }

  final FirebaseFirestore _db = db;
  static const _collection = 'users';

  /// Defaults for brand-new accounts: every module allowed.
  static const bool _defaultStudents = true;
  static const bool _defaultStudentDocs = true;
  static const bool _defaultStaff = true;
  static const bool _defaultStock = true;
  static const bool _defaultBills = true;
  static const bool _defaultVisitors = true;

  /// Leads are admin-only by default: only dishubansal@lklms.com sees them
  /// unless the admin explicitly grants access.
  static const bool _defaultLeads = false;

  /// Live access state for the signed-in user (null when signed out).
  ///
  /// Implemented as a *switching* stream: every auth-state change cancels the
  /// previous account's `users/{uid}` listener before starting the next one.
  ///
  /// NOTE: this must not be built with `Stream.asyncExpand` — that operator
  /// pauses the auth stream until the converted stream completes, and a
  /// Firestore `snapshots()` listener never completes. Doing so kept the app
  /// pinned to the first account signed in on a device, so after logout +
  /// login the new account never resolved its own flags (the UI then failed
  /// open because no session was available).
  Stream<AppSession?> watchAccess() {
    final controller = StreamController<AppSession?>();
    StreamSubscription<User?>? authSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? accessSub;
    var cancelled = false;

    void emit(AppSession? session) {
      if (!cancelled) controller.add(session);
    }

    Future<AppSession> resolve(
      String uid,
      String email,
      DocumentSnapshot<Map<String, dynamic>> doc,
    ) async {
      if (doc.exists) {
        final d = doc.data()!;
        return AppSession(
          uid: uid,
          email: email,
          isAdmin: false,
          canAccessStudents: d['canAccessStudents'] ?? _defaultStudents,
          canAccessStudentDocs:
              d['canAccessStudentDocs'] ?? _defaultStudentDocs,
          canAccessStaff: d['canAccessStaff'] ?? _defaultStaff,
          canAccessStock: d['canAccessStock'] ?? _defaultStock,
          canAccessBills: d['canAccessBills'] ?? _defaultBills,
          canAccessVisitors: d['canAccessVisitors'] ?? _defaultVisitors,
          canAccessLeads: d['canAccessLeads'] ?? _defaultLeads,
        );
      }

      // First login: inherit flags from a pre-provisioned doc for this
      // email (created by the admin's one-time helper) when one exists,
      // otherwise fall back to the defaults, then write the uid doc.
      var students = _defaultStudents;
      var studentDocs = _defaultStudentDocs;
      var staff = _defaultStaff;
      var stock = _defaultStock;
      var bills = _defaultBills;
      var visitors = _defaultVisitors;
      var leads = _defaultLeads;
      String? seedDocId;
      final seed = await _db
          .collection(_collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (seed.docs.isNotEmpty) {
        final s = seed.docs.first.data();
        students = s['canAccessStudents'] as bool? ?? students;
        studentDocs = s['canAccessStudentDocs'] as bool? ?? studentDocs;
        staff = s['canAccessStaff'] as bool? ?? staff;
        stock = s['canAccessStock'] as bool? ?? stock;
        bills = s['canAccessBills'] as bool? ?? bills;
        visitors = s['canAccessVisitors'] as bool? ?? visitors;
        leads = s['canAccessLeads'] as bool? ?? leads;
        seedDocId = seed.docs.first.id;
      }
      final now = DateTime.now().toIso8601String();
      await _db.collection(_collection).doc(uid).set({
        'email': email,
        'canAccessStudents': students,
        'canAccessStudentDocs': studentDocs,
        'canAccessStaff': staff,
        'canAccessStock': stock,
        'canAccessBills': bills,
        'canAccessVisitors': visitors,
        'canAccessLeads': leads,
        'createdAt': now,
        'updatedAt': now,
        'updatedBy': email,
      });
      // The uid doc is now the source of truth; drop the consumed
      // pre-provisioned doc so each account appears once.
      if (seedDocId != null && seedDocId != uid) {
        await _db.collection(_collection).doc(seedDocId).delete();
      }
      return AppSession(
        uid: uid,
        email: email,
        isAdmin: false,
        canAccessStudents: students,
        canAccessStudentDocs: studentDocs,
        canAccessStaff: staff,
        canAccessStock: stock,
        canAccessBills: bills,
        canAccessVisitors: visitors,
        canAccessLeads: leads,
      );
    }

    void switchTo(User? user) {
      // Cancel the previous account's live listener before subscribing to
      // the new one — a stale listener must never deliver another user's
      // flags.
      accessSub?.cancel();
      accessSub = null;
      if (user == null) {
        emit(null);
        return;
      }
      final uid = user.uid;
      final email = (user.email ?? '').trim().toLowerCase();
      if (isAdminEmail(email)) {
        emit(_adminSession(uid, email));
        return;
      }
      accessSub = _db
          .collection(_collection)
          .doc(uid)
          .snapshots()
          .listen((doc) async {
        // Drop events from an account that has since been replaced.
        if (FirebaseAuth.instance.currentUser?.uid != uid) return;
        try {
          final session = await resolve(uid, email, doc);
          if (FirebaseAuth.instance.currentUser?.uid != uid) return;
          emit(session);
        } catch (e) {
          debugPrint('Access resolution failed for $email: $e');
          // Fail closed: a provisioning failure must never grant access.
          if (FirebaseAuth.instance.currentUser?.uid == uid) {
            emit(_lockedSession(uid, email));
          }
        }
      }, onError: (Object e, StackTrace st) {
        // Fail closed on a failed access read too.
        debugPrint('Access read failed for $email: $e');
        if (FirebaseAuth.instance.currentUser?.uid == uid) {
          emit(_lockedSession(uid, email));
        }
      });
    }

    authSub = FirebaseAuth.instance.authStateChanges().listen(
      switchTo,
      onError: (Object e, StackTrace st) {
        if (!cancelled) controller.addError(e, st);
      },
    );

    controller.onCancel = () async {
      cancelled = true;
      final a = authSub;
      final s = accessSub;
      authSub = null;
      accessSub = null;
      await a?.cancel();
      await s?.cancel();
    };

    return controller.stream;
  }

  static AppSession _adminSession(String uid, String email) => AppSession(
        uid: uid,
        email: email,
        isAdmin: true,
        canAccessStudents: true,
        canAccessStudentDocs: true,
        canAccessStaff: true,
        canAccessStock: true,
        canAccessBills: true,
        canAccessVisitors: true,
        canAccessLeads: true,
      );

  static AppSession _lockedSession(String uid, String email) => AppSession(
        uid: uid,
        email: email,
        isAdmin: false,
        canAccessStudents: false,
        canAccessStudentDocs: false,
        canAccessStaff: false,
        canAccessStock: false,
        canAccessBills: false,
        canAccessVisitors: false,
        canAccessLeads: false,
      );

  /// All accounts for the admin dropdown, ordered by email.
  Stream<List<AppUser>> watchUsers() {
    return _db
        .collection(_collection)
        .orderBy('email')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppUser.fromDoc(d.id, d.data())).toList());
  }

  /// Persists the access flags for one account (admin only by policy).
  Future<void> updatePermissions({
    required String uid,
    required bool students,
    required bool studentDocs,
    required bool staff,
    required bool stock,
    required bool bills,
    required bool visitors,
    required bool leads,
  }) {
    final by = FirebaseAuth.instance.currentUser?.email ?? '';
    return _db.collection(_collection).doc(uid).update({
      'canAccessStudents': students,
      'canAccessStudentDocs': studentDocs,
      'canAccessStaff': staff,
      'canAccessStock': stock,
      'canAccessBills': bills,
      'canAccessVisitors': visitors,
      'canAccessLeads': leads,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': by,
    });
  }

  /// Creates a new email/password login for a staff member (admin only by
  /// policy) and returns its access row. The account is created through a
  /// secondary Firebase app so the admin stays signed in. Flags pre-set
  /// for this email via the seed helper are inherited, otherwise the
  /// defaults apply.
  Future<AppUser> createAccount({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    FirebaseApp secondary;
    try {
      secondary = Firebase.app('account-creator');
    } on FirebaseException {
      secondary = await Firebase.initializeApp(
        name: 'account-creator',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
    try {
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalized,
        password: password,
      );
      final uid = cred.user!.uid;
      var students = _defaultStudents;
      var studentDocs = _defaultStudentDocs;
      var staff = _defaultStaff;
      var stock = _defaultStock;
      var bills = _defaultBills;
      var visitors = _defaultVisitors;
      var leads = _defaultLeads;
      String? seedDocId;
      final seed = await _db
          .collection(_collection)
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (seed.docs.isNotEmpty && seed.docs.first.id != uid) {
        final s = seed.docs.first.data();
        students = s['canAccessStudents'] as bool? ?? students;
        studentDocs = s['canAccessStudentDocs'] as bool? ?? studentDocs;
        staff = s['canAccessStaff'] as bool? ?? staff;
        stock = s['canAccessStock'] as bool? ?? stock;
        bills = s['canAccessBills'] as bool? ?? bills;
        visitors = s['canAccessVisitors'] as bool? ?? visitors;
        leads = s['canAccessLeads'] as bool? ?? leads;
        seedDocId = seed.docs.first.id;
      }
      final now = DateTime.now().toIso8601String();
      await _db.collection(_collection).doc(uid).set({
        'email': normalized,
        'canAccessStudents': students,
        'canAccessStudentDocs': studentDocs,
        'canAccessStaff': staff,
        'canAccessStock': stock,
        'canAccessBills': bills,
        'canAccessVisitors': visitors,
        'canAccessLeads': leads,
        'createdAt': now,
        'updatedAt': now,
        'updatedBy': FirebaseAuth.instance.currentUser?.email ?? '',
      });
      if (seedDocId != null) {
        await _db.collection(_collection).doc(seedDocId).delete();
      }
      return AppUser(
        uid: uid,
        email: normalized,
        canAccessStudents: students,
        canAccessStudentDocs: studentDocs,
        canAccessStaff: staff,
        canAccessStock: stock,
        canAccessBills: bills,
        canAccessVisitors: visitors,
        canAccessLeads: leads,
      );
    } finally {
      await secondaryAuth.signOut();
    }
  }
}
