import 'package:flutter/material.dart';

/// Full-screen "no access" placeholder used by gated management screens.
/// The drawer is passed in by the caller so it keeps working without
/// importing navigation targets here.
Widget noAccessScaffold({required String module, required Widget drawer}) {
  return Scaffold(
    appBar: AppBar(title: Text(module)),
    drawer: drawer,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Access restricted',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'You do not have access to $module. '
              'Please contact the admin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    ),
  );
}
