import 'package:flutter/material.dart';

import '../access_service.dart';
import '../app_session.dart';
import 'no_access_screen.dart';

/// Wraps a module screen: streams the signed-in user's live access flags
/// and swaps in the "access restricted" placeholder when the module was
/// revoked. While flags are still resolving (or signed out) the content
/// renders normally to avoid a flash of the lock screen.
class AccessGate extends StatelessWidget {
  final String module;
  final bool Function(AppSession) canAccess;
  final Widget drawer;
  final Widget child;

  const AccessGate({
    super.key,
    required this.module,
    required this.canAccess,
    required this.drawer,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSession?>(
      stream: AccessService.watchAccessShared(),
      builder: (context, snap) {
        final session = snap.data;
        if (session != null && !canAccess(session)) {
          return noAccessScaffold(module: module, drawer: drawer);
        }
        return child;
      },
    );
  }
}
