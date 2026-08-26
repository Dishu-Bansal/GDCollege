import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants.dart';
import '../../providers.dart';
import '../../widgets/drawer.dart';
import '../../widgets/stock_widgets.dart';
import '../models/visitor_models.dart';
import '../repositories/visitor_repository.dart';
import 'visitor_detail_screen.dart';
import 'visitor_entry_form_screen.dart';

/// Visitor Management: currently-inside people, unique visitors and the
/// global visitor log.
class VisitorManagementScreen extends ConsumerStatefulWidget {
  const VisitorManagementScreen({super.key});

  @override
  ConsumerState<VisitorManagementScreen> createState() =>
      _VisitorManagementScreenState();
}

class _VisitorManagementScreenState
    extends ConsumerState<VisitorManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openEntryForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VisitorEntryFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(visitorRepositoryProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      drawer: getSideDrawer(context),
      appBar: AppBar(
        title: const Text('Visitor Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(
                icon: Icon(Icons.how_to_reg, size: 18),
                text: 'Inside'),
            Tab(
                icon: Icon(Icons.people_alt_outlined, size: 18),
                text: 'Visitors'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _InsideTab(service: service),
          _VisitorsTab(service: service),
          _LogsTab(service: service),
        ],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openEntryForm,
              backgroundColor: const Color(0xFF1A3C6E),
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text(
                'Check In',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}

// ── Helpers shared by the tabs ───────────────────────────────────────────────

String _initialOf(String name) =>
    name.isEmpty ? '?' : name.trim().characters.first.toUpperCase();

String _fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _fmtDateTime(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _TypeChip extends StatelessWidget {
  final bool isStaff;

  const _TypeChip({required this.isStaff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isStaff
            ? Colors.blue.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isStaff ? 'Staff' : 'Visitor',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isStaff ? Colors.blue.shade700 : Colors.orange.shade800,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ),
    ]);
  }
}

// ── Tab 1: people currently inside ───────────────────────────────────────────

class _InsideTab extends StatelessWidget {
  final VisitorRepository service;

  const _InsideTab({required this.service});

  Future<void> _checkOut(BuildContext context, VisitorVisitModel visit) async {
    try {
      await service.checkOut(visit.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${visit.name} checked out')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check out failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VisitorVisitModel>>(
      stream: service.watchInside(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        final visits = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting && visits.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (visits.isEmpty) {
          return const StockEmptyState(
            message:
                'No one is currently inside.\nUse the Check In button to add an entry.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: visits.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _InsideCard(
            visit: visits[i],
            onCheckOut: () => _checkOut(context, visits[i]),
          ),
        );
      },
    );
  }
}

class _InsideCard extends StatelessWidget {
  final VisitorVisitModel visit;
  final VoidCallback onCheckOut;

  const _InsideCard({required this.visit, required this.onCheckOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: avatarColor(visit.name),
            child: Text(
              _initialOf(visit.name),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visit.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  // Wrap (not Row) so the chip and "In since" never overflow
                  // into the Check Out button on narrow screens.
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _TypeChip(isStaff: visit.isStaff),
                      Text(
                        'In since ${_fmtTime(visit.checkInAt)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ]),
          ),
          OutlinedButton(
            onPressed: onCheckOut,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Check Out'),
          ),
        ]),
        if (visit.purpose.isNotEmpty ||
            visit.vehicleNumber.isNotEmpty ||
            visit.fromPlace.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (visit.purpose.isNotEmpty)
              _InfoItem(Icons.info_outline, visit.purpose),
            if (visit.vehicleNumber.isNotEmpty)
              _InfoItem(Icons.directions_car_outlined, visit.vehicleNumber),
            if (visit.fromPlace.isNotEmpty)
              _InfoItem(Icons.place_outlined, visit.fromPlace),
          ]),
        ],
        if (visit.accompanyingPeople.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('With: ${visit.accompanyingPeople.join(', ')}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ]),
    );
  }
}

// ── Tab 2: unique visitors ───────────────────────────────────────────────────

class _VisitorsTab extends StatelessWidget {
  final VisitorRepository service;

  const _VisitorsTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VisitorModel>>(
      stream: service.watchVisitors(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        final visitors = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting &&
            visitors.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (visitors.isEmpty) {
          return const StockEmptyState(
            message:
                'No visitors yet.\nCheck in a visitor to start building history.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: visitors.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final v = visitors[i];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: avatarColor(v.name),
                  child: Text(
                    _initialOf(v.name),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(v.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${v.visitCount} visit${v.visitCount == 1 ? '' : 's'}'
                  '${v.lastVisitAt != null ? '  •  Last: ${_fmtDateTime(v.lastVisitAt!)}' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisitorDetailScreen(
                        visitor: v,
                        service: service,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab 3: global visitor log ────────────────────────────────────────────────

class _LogsTab extends StatelessWidget {
  final VisitorRepository service;

  const _LogsTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VisitorVisitModel>>(
      stream: service.watchAllVisits(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        final visits = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting && visits.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (visits.isEmpty) {
          return const StockEmptyState(
            message: 'No visitor entries yet.\nCheck-ins will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: visits.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _LogCard(visit: visits[i]),
        );
      },
    );
  }
}

class _LogCard extends StatelessWidget {
  final VisitorVisitModel visit;

  const _LogCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarColor(visit.name),
            child: Text(
              _initialOf(visit.name),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visit.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _TypeChip(isStaff: visit.isStaff),
                      Text(
                        visit.isInside ? 'Inside' : 'Completed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: visit.isInside
                              ? Colors.green.shade700
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ]),
          ),
          Text(
            _fmtDateTime(visit.checkInAt),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          visit.isInside
              ? 'Checked in at ${_fmtDateTime(visit.checkInAt)}'
              : 'Checked in ${_fmtDateTime(visit.checkInAt)}  •  '
                  'Checked out ${_fmtDateTime(visit.checkOutAt!)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        if (visit.purpose.isNotEmpty ||
            visit.vehicleNumber.isNotEmpty ||
            visit.fromPlace.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (visit.purpose.isNotEmpty)
              _InfoItem(Icons.info_outline, visit.purpose),
            if (visit.vehicleNumber.isNotEmpty)
              _InfoItem(Icons.directions_car_outlined, visit.vehicleNumber),
            if (visit.fromPlace.isNotEmpty)
              _InfoItem(Icons.place_outlined, visit.fromPlace),
          ]),
        ],
        if (visit.accompanyingPeople.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('With: ${visit.accompanyingPeople.join(', ')}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ]),
    );
  }
}
