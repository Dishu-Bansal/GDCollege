import 'package:flutter/material.dart';
import 'package:gd_college/models/user_session.dart';
import 'package:gd_college/screens/login_screen.dart';

import '../staff_management/screens/staff_list_screen.dart';
import '../student_management/screens/student_list_screen.dart';

getSideDrawer(BuildContext context){
 return Drawer(
   child: ListView(
     padding: EdgeInsets.zero,
     children: [
       const DrawerHeader(
         decoration: BoxDecoration(color: Colors.blue),
         child: Text(
           'Menu',
           style: TextStyle(color: Colors.white, fontSize: 24),
         ),
       ),
       ListTile(
         leading: const Icon(Icons.home),
         title: const Text('Student Management'),
         onTap: () {
           // Close the drawer and navigate
           // Navigator.pop(context);
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StudentListScreen()));
         },
       ),
       ListTile(
         leading: const Icon(Icons.people),
         title: const Text('Staff Management'),
         onTap: () {
           // Navigator.pop(context);
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StaffListScreen()));
         },
       ),
       ListTile(
         leading: const Icon(Icons.settings),
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