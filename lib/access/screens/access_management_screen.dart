import 'package:flutter/material.dart';

import '../../widgets/drawer.dart';
import '../access_service.dart';
import '../app_session.dart';
import '../widgets/no_access_screen.dart';

/// Admin-only screen: pick any non-admin account from a dropdown, see its
/// current module flags, change them and save. Changes stream to the user's
/// signed-in devices live.
class AccessManagementScreen extends StatefulWidget {
  const AccessManagementScreen({super.key});

  @override
  State<AccessManagementScreen> createState() =>
      _AccessManagementScreenState();
}

class _AccessManagementScreenState extends State<AccessManagementScreen> {
  final _service = AccessService();
  late final Stream<AppSession?> _sessionStream = _service.watchAccess();
  late final Stream<List<AppUser>> _usersStream = _service.watchUsers();

  String? _selectedUid;
  bool _students = true;
  bool _staff = true;
  bool _stock = true;
  bool _bills = true;
  bool _visitors = true;
  bool _saving = false;

  void _pickUser(AppUser? user) {
    setState(() {
      _selectedUid = user?.uid;
      _students = user?.canAccessStudents ?? true;
      _staff = user?.canAccessStaff ?? true;
      _stock = user?.canAccessStock ?? true;
      _bills = user?.canAccessBills ?? true;
      _visitors = user?.canAccessVisitors ?? true;
    });
  }

  Future<void> _save() async {
    final uid = _selectedUid;
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _service.updatePermissions(
        uid: uid,
        students: _students,
        staff: _staff,
        stock: _stock,
        bills: _bills,
        visitors: _visitors,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Opens the create-account popup and auto-selects the new login below
  /// so its flags can be adjusted immediately.
  Future<void> _openCreate() async {
    final user = await showDialog<AppUser>(
      context: context,
      builder: (_) => const _CreateAccountDialog(),
    );
    if (user == null || !mounted) return;
    _pickUser(user);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Account created for ${user.email}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSession?>(
      stream: _sessionStream,
      builder: (context, sessionSnap) {
        final session = sessionSnap.data;
        // Still resolving the first event: show a loader. A resolved null
        // session means signed out, so render nothing instead of spinning
        // forever.
        if (sessionSnap.connectionState == ConnectionState.waiting &&
            !sessionSnap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (session == null) {
          return const Scaffold(body: SizedBox.shrink());
        }
        if (!session.isAdmin) {
          return noAccessScaffold(
              module: 'Access Management',
              drawer: getSideDrawer(context));
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          drawer: getSideDrawer(context),
          appBar: AppBar(
            title: const Text('Access Management',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openCreate,
            backgroundColor: const Color(0xFF1A3C6E),
            icon: const Icon(Icons.person_add_outlined,
                color: Colors.white),
            label: const Text('Create account',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          body: StreamBuilder<List<AppUser>>(
            stream: _usersStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              // Admin accounts are managed in code, not from this list.
              final users = (snap.data ?? [])
                  .where((u) => !AccessService.isAdminEmail(u.email))
                  .toList();
              final selected = users.where((u) => u.uid == _selectedUid);
              if (users.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No user accounts yet.\nAccounts appear here after their first login.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedUid,
                    decoration: const InputDecoration(
                      labelText: 'User Account',
                      prefixIcon: Icon(Icons.manage_accounts_outlined),
                    ),
                    items: [
                      for (final u in users)
                        DropdownMenuItem(
                          value: u.uid,
                          child: Text(u.email.isEmpty ? '(no email)' : u.email,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (uid) {
                      if (uid == null) {
                        _pickUser(null);
                        return;
                      }
                      AppUser? match;
                      for (final u in users) {
                        if (u.uid == uid) match = u;
                      }
                      _pickUser(match);
                    },
                  ),
                  if (selected.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Access',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    _accessRow('Student Management', _students,
                        (v) => setState(() => _students = v)),
                    const SizedBox(height: 12),
                    _accessRow('Staff Management', _staff,
                        (v) => setState(() => _staff = v)),
                    const SizedBox(height: 12),
                    _accessRow('Stock Management', _stock,
                        (v) => setState(() => _stock = v)),
                    const SizedBox(height: 12),
                    _accessRow('Bill Management', _bills,
                        (v) => setState(() => _bills = v)),
                    const SizedBox(height: 12),
                    _accessRow('Visitor Management', _visitors,
                        (v) => setState(() => _visitors = v)),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(_saving ? 'Saving…' : 'Save Access',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _accessRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Allow')),
            ButtonSegment(value: false, label: Text('Disallow')),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ]),
    );
  }
}

/// Popup for creating a new email/password login. Returns the created
/// [AppUser] on success, null when dismissed.
class _CreateAccountDialog extends StatefulWidget {
  const _CreateAccountDialog();

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  final _service = AccessService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use')) {
      return 'This email already has an account';
    }
    if (msg.contains('weak-password')) {
      return 'Password must be at least 6 characters';
    }
    if (msg.contains('invalid-email')) {
      return 'Enter a valid email address';
    }
    if (msg.contains('operation-not-allowed')) {
      return 'Email/password accounts are not enabled in Firebase Console';
    }
    if (msg.contains('network-request-failed')) {
      return 'Network error — check connection and retry';
    }
    return 'Could not create account: $e';
  }

  Future<void> _create() async {
    if (_busy) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final emailOk =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailOk || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(!emailOk
                ? 'Enter a valid email address'
                : 'Password must be at least 6 characters')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final user =
          await _service.createAccount(email: email, password: password);
      if (!mounted) return;
      Navigator.pop(context, user);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Create account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'New user email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _create(),
            decoration: InputDecoration(
              labelText: 'Temporary password (min 6 chars)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _busy ? null : _create,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }
}
