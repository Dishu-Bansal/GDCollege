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
import '../staff_management/screens/staff_list_screen.dart';
import '../stock_management/screens/buildings_screen.dart';
import '../student_management/screens/student_list_screen.dart';
import '../visitor_management/screens/visitor_management_screen.dart';
import 'Helper.dart';

/// Side drawer with module entries gated by the signed-in user's live
/// access flags. The Access Management entry is visible only to admins.
/// While flags resolve, everything shows (avoids a flashing empty drawer).
getSideDrawer(BuildContext context) {
  return Drawer(
    child: StreamBuilder<AppSession?>(
      stream: AccessService.watchAccessShared(),
      builder: (context, snap) {
        final session = snap.data;
        // Synchronous admin check: the entry renders on the first frame on
        // every screen instead of waiting for the stream to resolve.
        final isAdmin = session?.isAdmin == true ||
            AccessService.isAdminEmail(
                FirebaseAuth.instance.currentUser?.email);
        final showStudents = session == null || session.canAccessStudents;
        final showStaff = session == null || session.canAccessStaff;
        final showStock = session == null || session.canAccessStock;
        final showBills = session == null || session.canAccessBills;
        final showVisitors = session == null || session.canAccessVisitors;
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
            if (showStudents)
              ListTile(
                leading: const Icon(Icons.people_alt),
                title: const Text('Student Management'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StudentListScreen()));
                },
              ),
            if (showStaff)
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('Staff Management'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StaffListScreen()));
                },
              ),
            if (showStock)
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: const Text('Stock Management'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BuildingsScreen()));
                },
              ),
            if (showBills)
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Bill Management'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BillManagementScreen()));
                },
              ),
            if (showVisitors)
              ListTile(
                leading: const Icon(Icons.how_to_reg),
                title: const Text('Visitor Management'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VisitorManagementScreen()));
                },
              ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('User Sessions'),
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserSessionsScreen()));
              },
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Access Management'),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AccessManagementScreen()));
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Helper'),
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
