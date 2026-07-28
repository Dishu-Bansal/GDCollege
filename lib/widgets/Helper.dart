import 'package:flutter/material.dart';

import '../repositories/student_repository.dart';
import '../repositories/stock_repository.dart';
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
