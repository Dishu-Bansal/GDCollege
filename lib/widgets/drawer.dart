import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gd_college/access/access_service.dart';
import 'package:gd_college/access/app_session.dart';
import 'package:gd_college/access/screens/access_management_screen.dart';
import 'package:gd_college/screens/home_screen.dart';
import 'package:gd_college/screens/login_screen.dart';
import 'package:gd_college/screens/user_sessions_screen.dart';
import 'package:gd_college/services/session_service.dart';

import '../bill_management/screens/bill_management_screen.dart';
import '../fees_management/screens/fees_management_screen.dart';
import '../lead_management/screens/lead_management_screen.dart';
import '../staff_management/screens/staff_list_screen.dart';
import '../stock_management/screens/buildings_screen.dart';
import '../student_docs/screens/student_docs_screen.dart';
import '../student_management/screens/student_list_screen.dart';
import '../visitor_management/screens/visitor_management_screen.dart';
import 'Helper.dart';

/// Side drawer with module entries gated by the signed-in user's live
/// access flags. The Access Management entry is visible only to admins.
///
/// Module entries are hidden until the access session for the *current*
/// account resolves (fail closed) — a stale session from a previous login is
/// ignored, so it can never leave the next account's drawer unrestricted.
getSideDrawer(BuildContext context) {
  return Drawer(
    child: StreamBuilder<AppSession?>(
      stream: AccessService.watchAccessShared(),
      // The app-wide session is already known after the first resolution, so
      // re-opening the drawer paints the same entries on the first frame
      // instead of flashing "Loading access…". currentAppSession() below still
      // discards a cached session that belongs to another account.
      initialData: AccessService.cachedSession,
      builder: (context, snap) {
        final session = currentAppSession(snap.data);
        // Synchronous admin check: the entry renders on the first frame on
        // every screen instead of waiting for the stream to resolve.
        final isAdmin = session?.isAdmin == true ||
            AccessService.isAdminEmail(
                FirebaseAuth.instance.currentUser?.email);
        final showStudents = session?.canAccessStudents ?? false;
        final showStudentDocs = session?.canAccessStudentDocs ?? false;
        final showStaff = session?.canAccessStaff ?? false;
        final showStock = session?.canAccessStock ?? false;
        final showBills = session?.canAccessBills ?? false;
        final showVisitors = session?.canAccessVisitors ?? false;
        final showLeads = session?.canAccessLeads ?? false;
        final showFees = session?.canAccessFees ?? false;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Lala Kundan Lal',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    'Memorial Society',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
              },
            ),
            if (session == null)
              const ListTile(
                leading: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Loading access…'),
              ),
            if (showStudents)
              ListTile(
                leading: const Icon(Icons.people_alt),
                title: const Text('Students'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StudentListScreen()));
                },
              ),
            if (showStudentDocs)
              ListTile(
                leading: const Icon(Icons.folder_shared_outlined),
                title: const Text('DMC & Degrees'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentDocsScreen()));
                },
              ),
            if (showStaff)
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('Staff'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StaffListScreen()));
                },
              ),
            if (showStock)
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: const Text('Stock'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BuildingsScreen()));
                },
              ),
            if (showBills)
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Bills'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BillManagementScreen()));
                },
              ),
            if (showVisitors)
              ListTile(
                leading: const Icon(Icons.how_to_reg),
                title: const Text('Visitors'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VisitorManagementScreen()));
                },
              ),
            if (showLeads)
              ListTile(
                leading: const Icon(Icons.person_search_outlined),
                title: const Text('Leads'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LeadManagementScreen()));
                },
              ),
            if (showFees)
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Fees'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FeesManagementScreen()));
                },
              ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Login Sessions'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserSessionsScreen()));
                },
              ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Access Control'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AccessManagementScreen()));
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Tools'),
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Helper()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log Out'),
              onTap: () async {
                await SessionService.instance.logout();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
              },
            ),
          ],
        );
      },
    ),
  );
}
