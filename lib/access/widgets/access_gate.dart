import 'package:flutter/material.dart';

import '../access_service.dart';
import '../app_session.dart';
import 'no_access_screen.dart';

/// Wraps a module screen: streams the signed-in user's live access flags and
/// swaps in the "access restricted" placeholder when the module is not
/// allowed.
///
/// Fails closed: while the session is still resolving (or when it belongs to
/// a previous login / the stream errored) the module content is never
/// rendered — a spinner is shown while loading and the restricted screen
/// otherwise.
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
        // Ignore a session that belongs to another (previous) account.
        final session = currentAppSession(snap.data);
        if (session == null) {
          final loading =
              snap.connectionState == ConnectionState.waiting &&
                  !snap.hasError;
          if (loading) {
            return Scaffold(
              drawer: drawer,
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          return noAccessScaffold(module: module, drawer: drawer);
        }
        if (!canAccess(session)) {
          return noAccessScaffold(module: module, drawer: drawer);
        }
        return child;
      },
    );
  }
}
