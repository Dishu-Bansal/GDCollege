import 'package:firebase_auth/firebase_auth.dart';

/// Access state for the signed-in user, resolved live from the `users`
/// Firestore collection (plus the hardcoded admin list).
class AppSession {
  final String uid;
  final String email;
  final bool isAdmin;
  final bool canAccessStudents;
  final bool canAccessStudentDocs;
  final bool canAccessStaff;
  final bool canAccessStock;
  final bool canAccessBills;
  final bool canAccessVisitors;
  final bool canAccessLeads;

  const AppSession({
    required this.uid,
    required this.email,
    required this.isAdmin,
    required this.canAccessStudents,
    required this.canAccessStudentDocs,
    required this.canAccessStaff,
    required this.canAccessStock,
    required this.canAccessBills,
    required this.canAccessVisitors,
    required this.canAccessLeads,
  });
}

/// One row of the `users` collection: an account the admin can manage.
class AppUser {
  final String uid;
  final String email;
  final bool canAccessStudents;
  final bool canAccessStudentDocs;
  final bool canAccessStaff;
  final bool canAccessStock;
  final bool canAccessBills;
  final bool canAccessVisitors;
  final bool canAccessLeads;

  const AppUser({
    required this.uid,
    required this.email,
    required this.canAccessStudents,
    required this.canAccessStudentDocs,
    required this.canAccessStaff,
    required this.canAccessStock,
    required this.canAccessBills,
    required this.canAccessVisitors,
    required this.canAccessLeads,
  });

  factory AppUser.fromDoc(String uid, Map<String, dynamic> d) => AppUser(
        uid: uid,
        email: (d['email'] ?? '').toString(),
        canAccessStudents: d['canAccessStudents'] ?? true,
        canAccessStudentDocs: d['canAccessStudentDocs'] ?? true,
        canAccessStaff: d['canAccessStaff'] ?? true,
        canAccessStock: d['canAccessStock'] ?? true,
        canAccessBills: d['canAccessBills'] ?? true,
        canAccessVisitors: d['canAccessVisitors'] ?? true,
        canAccessLeads: d['canAccessLeads'] ?? false,
      );
}

/// Returns [session] only when it belongs to the account that is currently
/// signed in. A cached session from a previous login on this device (or a
/// stream that has not resolved yet) yields null, so callers fail closed
/// instead of granting the previous account's access.
AppSession? currentAppSession(AppSession? session) {
  if (session == null) return null;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  return (uid != null && session.uid == uid) ? session : null;
}
