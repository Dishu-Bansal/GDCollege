/// Access state for the signed-in user, resolved live from the `users`
/// Firestore collection (plus the hardcoded admin list).
class AppSession {
  final String uid;
  final String email;
  final bool isAdmin;
  final bool canAccessStudents;
  final bool canAccessStaff;
  final bool canAccessStock;
  final bool canAccessBills;
  final bool canAccessVisitors;

  const AppSession({
    required this.uid,
    required this.email,
    required this.isAdmin,
    required this.canAccessStudents,
    required this.canAccessStaff,
    required this.canAccessStock,
    required this.canAccessBills,
    required this.canAccessVisitors,
  });
}

/// One row of the `users` collection: an account the admin can manage.
class AppUser {
  final String uid;
  final String email;
  final bool canAccessStudents;
  final bool canAccessStaff;
  final bool canAccessStock;
  final bool canAccessBills;
  final bool canAccessVisitors;

  const AppUser({
    required this.uid,
    required this.email,
    required this.canAccessStudents,
    required this.canAccessStaff,
    required this.canAccessStock,
    required this.canAccessBills,
    required this.canAccessVisitors,
  });

  factory AppUser.fromDoc(String uid, Map<String, dynamic> d) => AppUser(
        uid: uid,
        email: (d['email'] ?? '').toString(),
        canAccessStudents: d['canAccessStudents'] ?? true,
        canAccessStaff: d['canAccessStaff'] ?? true,
        canAccessStock: d['canAccessStock'] ?? true,
        canAccessBills: d['canAccessBills'] ?? true,
        canAccessVisitors: d['canAccessVisitors'] ?? true,
      );
}
