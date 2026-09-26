import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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

  /// App-wide shared access stream. Every drawer, gate and card must use
  /// this (never a fresh `watchAccess()`) so all screens resolve the same
  /// session at the same time — and so the app holds one `users/{uid}`
  /// listener instead of one per widget.
  static Stream<AppSession?>? _sharedAccess;
  static Stream<AppSession?> watchAccessShared() => _sharedAccess ??=
      AccessService().watchAccess().asBroadcastStream();

  final FirebaseFirestore _db = db;
  static const _collection = 'users';

  /// Defaults for brand-new accounts: every module allowed.
  static const bool _defaultStudents = true;
  static const bool _defaultStaff = true;
  static const bool _defaultStock = true;
  static const bool _defaultBills = true;
  static const bool _defaultVisitors = true;

  /// Live access state for the signed-in user (null when signed out).
  Stream<AppSession?> watchAccess() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<AppSession?>.value(null);
      final email = (user.email ?? '').trim().toLowerCase();
      if (isAdminEmail(email)) {
        return Stream<AppSession?>.value(AppSession(
          uid: user.uid,
          email: email,
          isAdmin: true,
          canAccessStudents: true,
          canAccessStaff: true,
          canAccessStock: true,
          canAccessBills: true,
          canAccessVisitors: true,
        ));
      }
      return _db
          .collection(_collection)
          .doc(user.uid)
          .snapshots()
          .asyncMap((doc) async {
        if (!doc.exists) {
          // First login: inherit flags from a pre-provisioned doc for this
          // email (created by the admin's one-time helper) when one exists,
          // otherwise fall back to the defaults.
          var students = _defaultStudents;
          var staff = _defaultStaff;
          var stock = _defaultStock;
          var bills = _defaultBills;
          var visitors = _defaultVisitors;
          String? seedDocId;
          final seed = await _db
              .collection(_collection)
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (seed.docs.isNotEmpty) {
            final s = seed.docs.first.data();
            students = s['canAccessStudents'] as bool? ?? students;
            staff = s['canAccessStaff'] as bool? ?? staff;
            stock = s['canAccessStock'] as bool? ?? stock;
            bills = s['canAccessBills'] as bool? ?? bills;
            visitors = s['canAccessVisitors'] as bool? ?? visitors;
            seedDocId = seed.docs.first.id;
          }
          final now = DateTime.now().toIso8601String();
          await _db.collection(_collection).doc(user.uid).set({
            'email': email,
            'canAccessStudents': students,
            'canAccessStaff': staff,
            'canAccessStock': stock,
            'canAccessBills': bills,
            'canAccessVisitors': visitors,
            'createdAt': now,
            'updatedAt': now,
            'updatedBy': email,
          });
          // The uid doc is now the source of truth; drop the consumed
          // pre-provisioned doc so each account appears once.
          if (seedDocId != null && seedDocId != user.uid) {
            await _db.collection(_collection).doc(seedDocId).delete();
          }
          return AppSession(
            uid: user.uid,
            email: email,
            isAdmin: false,
            canAccessStudents: students,
            canAccessStaff: staff,
            canAccessStock: stock,
            canAccessBills: bills,
            canAccessVisitors: visitors,
          );
        }
        final d = doc.data()!;
        return AppSession(
          uid: user.uid,
          email: email,
          isAdmin: false,
          canAccessStudents: d['canAccessStudents'] ?? _defaultStudents,
          canAccessStaff: d['canAccessStaff'] ?? _defaultStaff,
          canAccessStock: d['canAccessStock'] ?? _defaultStock,
          canAccessBills: d['canAccessBills'] ?? _defaultBills,
          canAccessVisitors: d['canAccessVisitors'] ?? _defaultVisitors,
        );
      });
    });
  }

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
    required bool staff,
    required bool stock,
    required bool bills,
    required bool visitors,
  }) {
    final by = FirebaseAuth.instance.currentUser?.email ?? '';
    return _db.collection(_collection).doc(uid).update({
      'canAccessStudents': students,
      'canAccessStaff': staff,
      'canAccessStock': stock,
      'canAccessBills': bills,
      'canAccessVisitors': visitors,
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
      var staff = _defaultStaff;
      var stock = _defaultStock;
      var bills = _defaultBills;
      var visitors = _defaultVisitors;
      String? seedDocId;
      final seed = await _db
          .collection(_collection)
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (seed.docs.isNotEmpty && seed.docs.first.id != uid) {
        final s = seed.docs.first.data();
        students = s['canAccessStudents'] as bool? ?? students;
        staff = s['canAccessStaff'] as bool? ?? staff;
        stock = s['canAccessStock'] as bool? ?? stock;
        bills = s['canAccessBills'] as bool? ?? bills;
        visitors = s['canAccessVisitors'] as bool? ?? visitors;
        seedDocId = seed.docs.first.id;
      }
      final now = DateTime.now().toIso8601String();
      await _db.collection(_collection).doc(uid).set({
        'email': normalized,
        'canAccessStudents': students,
        'canAccessStaff': staff,
        'canAccessStock': stock,
        'canAccessBills': bills,
        'canAccessVisitors': visitors,
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
        canAccessStaff: staff,
        canAccessStock: stock,
        canAccessBills: bills,
        canAccessVisitors: visitors,
      );
    } finally {
      await secondaryAuth.signOut();
    }
  }
}
