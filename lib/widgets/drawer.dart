import 'package:flutter/material.dart';
import 'package:gd_college/models/user_session.dart';
import 'package:gd_college/screens/home_screen.dart';
import 'package:gd_college/screens/login_screen.dart';

import '../bill_management/screens/bill_management_screen.dart';
import '../staff_management/screens/staff_list_screen.dart';
import '../stock_management/screens/buildings_screen.dart';
import '../student_management/screens/student_list_screen.dart';
import 'Helper.dart';

getSideDrawer(BuildContext context){
 return Drawer(
   child: ListView(
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
       ListTile(
         leading: const Icon(Icons.people_alt),
         title: const Text('Student Management'),
         onTap: () {
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StudentListScreen()));
         },
       ),
       ListTile(
         leading: const Icon(Icons.badge),
         title: const Text('Staff Management'),
         onTap: () {
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StaffListScreen()));
         },
       ),
       ListTile(
         leading: const Icon(Icons.inventory_2),
         title: const Text('Stock Management'),
         onTap: () {
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BuildingsScreen()));
         },
       ),
       ListTile(
         leading: const Icon(Icons.receipt_long),
         title: const Text('Bill Management'),
         onTap: () {
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BillManagementScreen()));
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
           await UserSession().logOut();
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
         },
       ),
     ],
   ),
 );
}