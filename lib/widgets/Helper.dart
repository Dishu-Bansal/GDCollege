import 'package:flutter/material.dart';

import '../services/firebase_student_service.dart';
import 'drawer.dart';

class Helper extends StatefulWidget {
  const Helper({super.key});

  @override
  State<Helper> createState() => _HelperState();
}

class _HelperState extends State<Helper> {
  String msg = "Migrate Data";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: getSideDrawer(context),
      body: Column(
        children: [
          MaterialButton(onPressed: () async {
            setState(() {
              msg = "Migrating...";
            });
            await FirebaseService().migrateExistingStudents();
            setState(() {
              msg = "done";
            });
          },
            child: Text(msg),
            color: Colors.blue,
          )
        ],
      ),
    );
  }
}
