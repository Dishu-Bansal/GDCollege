import 'package:flutter/material.dart';
import 'package:gd_college/widgets/drawer.dart';
import '../models/stock_models.dart';
import '../../repositories/stock_repository.dart';
import '../../providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/stock_widgets.dart';
import 'floors_screen.dart';
import 'item_catalog_tab.dart';

class BuildingsScreen extends ConsumerStatefulWidget {
  const BuildingsScreen({super.key});

  @override
  ConsumerState<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends ConsumerState<BuildingsScreen>
    with SingleTickerProviderStateMixin {
  static const _kPrimary = Color(0xFF1A3C6E);
  late final TabController _tabs;

  StockRepository get _service => ref.read(stockRepositoryProvider);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      drawer: getSideDrawer(context),
      appBar: AppBar(
        title: const Text('Stock Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_tabs.index == 0)
            IconButton(
              icon: const Icon(Icons.add_business_outlined),
              tooltip: 'Add Building',
              onPressed: () => _addBuilding(context),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(
                icon: Icon(Icons.business_outlined, size: 18),
                text: 'Buildings'),
            Tab(
                icon: Icon(Icons.inventory_2_outlined, size: 18),
                text: 'Catalog'),
            Tab(
                icon: Icon(Icons.history, size: 18),
                text: 'Global Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _BuildingsTab(service: _service, onAdd: () => _addBuilding(context)),
          const ItemCatalogTab(),
          _GlobalLogTab(service: _service),
        ],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _addBuilding(context),
              backgroundColor: _kPrimary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Building',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  Future<void> _addBuilding(BuildContext context) async {
    final name = await showNameDialog(context,
        title: 'Add Building', hint: 'e.g. Main Block, Hostel A');
    if (name != null) await _service.addBuilding(name);
  }
}

class _BuildingsTab extends StatelessWidget {
  final StockRepository service;
  final VoidCallback onAdd;

  const _BuildingsTab({required this.service, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BuildingModel>>(
      stream: service.watchBuildings(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final buildings = snap.data ?? [];
        if (buildings.isEmpty) {
          return StockEmptyState(
            message:
                'No buildings yet.\nAdd your first building to get started.',
            actionLabel: 'Add Building',
            onAction: onAdd,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: buildings.length,
          itemBuilder: (_, i) => _BuildingCard(
            building: buildings[i],
            service: service,
          ),
        );
      },
    );
  }
}

class _BuildingCard extends StatelessWidget {
  final BuildingModel building;
  final StockRepository service;

  const _BuildingCard({required this.building, required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: StreamBuilder<List<FloorModel>>(
        stream: service.watchFloors(building.id!),
        builder: (context, floorSnap) {
          final floors = floorSnap.data ?? [];
          return _BuildingCardContent(
            building: building,
            service: service,
            floors: floors,
          );
        },
      ),
    );
  }
}

class _BuildingCardContent extends StatelessWidget {
  final BuildingModel building;
  final StockRepository service;
  final List<FloorModel> floors;

  const _BuildingCardContent({
    required this.building,
    required this.service,
    required this.floors,
  });

  @override
  Widget build(BuildContext context) {
    if (floors.isEmpty) {
      return _tile(context, dueRooms: const []);
    }

    return _MultiFloorRoomWatcher(
      building: building,
      floors: floors,
      service: service,
      builder: (dueRooms) => _tile(context, dueRooms: dueRooms),
    );
  }

  Widget _tile(BuildContext context,
      {required List<(RoomModel, String)> dueRooms}) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FloorsScreen(building: building),
        ),
      ),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3C6E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business,
                color: Color(0xFF1A3C6E), size: 26),
          ),
          if (dueRooms.isNotEmpty)
            const Positioned(
              top: -4,
              right: -4,
              child: InspectionDueBadge(),
            ),
        ],
      ),
      title: Text(building.name,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (building.createdAt != null)
            Text(
              'Added ${building.createdAt!.day}/${building.createdAt!.month}/${building.createdAt!.year}',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500),
            ),
          // Feature: Inspection Tracking - list rooms due or never
          // inspected across all floors with their last inspection date.
          if (dueRooms.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Inspection due for ${dueRooms.length} '
              'room${dueRooms.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  fontWeight: FontWeight.w500),
            ),
            for (final (room, floorName) in dueRooms)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: InspectionStatusLine(
                    room: room,
                    includeRoomName: true,
                    floorName: floorName),
              ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                final name = await showNameDialog(context,
                    title: 'Rename Building', initial: building.name);
                if (name != null) {
                  await service.updateBuilding(building.id!, name);
                }
              } else if (v == 'delete') {
                final ok =
                    await confirmDelete(context, label: building.name);
                if (ok) await service.deleteBuilding(building.id!);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'rename',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Rename'),
                  ])),
              const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ])),
            ],
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}

/// Watches room streams across multiple floors and collects every room whose
/// inspection is due (>14 days or never inspected), paired with its floor name.
class _MultiFloorRoomWatcher extends StatelessWidget {
  final BuildingModel building;
  final List<FloorModel> floors;
  final StockRepository service;
  final Widget Function(List<(RoomModel, String)> dueRooms) builder;

  const _MultiFloorRoomWatcher({
    required this.building,
    required this.floors,
    required this.service,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return _FloorRoomWatcher(
      building: building,
      floors: floors,
      index: 0,
      service: service,
      accumulated: const [],
      builder: builder,
    );
  }
}

class _FloorRoomWatcher extends StatelessWidget {
  final BuildingModel building;
  final List<FloorModel> floors;
  final int index;
  final StockRepository service;
  final List<(RoomModel, String)> accumulated;
  final Widget Function(List<(RoomModel, String)>) builder;

  const _FloorRoomWatcher({
    required this.building,
    required this.floors,
    required this.index,
    required this.service,
    required this.accumulated,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (index >= floors.length) return builder(accumulated);

    return StreamBuilder<List<RoomModel>>(
      stream: service.watchRooms(building.id!, floors[index].id!),
      builder: (context, snap) {
        final rooms = snap.data ?? [];
        final floorName = floors[index].name;
        final combined = [
          ...accumulated,
          for (final r in rooms.where((r) => r.isInspectionDue)) (r, floorName),
        ];

        return _FloorRoomWatcher(
          building: building,
          floors: floors,
          index: index + 1,
          service: service,
          accumulated: combined,
          builder: builder,
        );
      },
    );
  }
}

// ── Global Log Tab ──────────────────────────────────────────────────────────────

class _GlobalLogTab extends StatelessWidget {
  final StockRepository service;
  const _GlobalLogTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockLog>>(
      stream: service.watchAllLogs(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snap.data ?? [];
        if (snap.hasError) {
          return StockEmptyState(
            message:
                'Unable to load global logs.\nA Firestore composite index may be required.\n\nSee the error link in the console to create it.',
          );
        }
        if (logs.isEmpty) {
          return const StockEmptyState(
              message:
                  'No stock movements yet across any room.\nAdjust item quantities to see the log.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _GlobalLogTile(log: logs[i]),
        );
      },
    );
  }
}

class _GlobalLogTile extends StatelessWidget {
  final StockLog log;
  const _GlobalLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final isInspection = log.type == 'inspection';
    final isIncrease = log.type == 'increase';
    final color = isInspection
        ? const Color(0xFF1A3C6E)
        : isIncrease
            ? Colors.green.shade700
            : Colors.red.shade600;

    final location = <String>[];
    if (log.buildingName.isNotEmpty) location.add(log.buildingName);
    if (log.floorName.isNotEmpty) location.add(log.floorName);
    if (log.roomName.isNotEmpty) location.add(log.roomName);
    final locationText = location.join(' › ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
              isInspection
                  ? Icons.fact_check_outlined
                  : isIncrease
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
              color: color,
              size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(log.itemName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 3),
                if (isInspection)
                  Text(
                    log.note,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Row(children: [
                    Text(
                      '${log.previousQty} → ${log.newQty}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(width: 8),
                    if (log.note.isNotEmpty)
                      Expanded(
                        child: Text(
                          log.note,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ]),
                const SizedBox(height: 3),
                Row(children: [
                  if (locationText.isNotEmpty)
                    Expanded(
                      child: Text(
                        locationText,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey.shade400,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ]),
                const SizedBox(height: 1),
                Row(children: [
                  Text(
                    _fmtDateTime(log.timestamp),
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade400),
                  ),
                  if (log.changedBy.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      'by ${log.changedBy}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ]),
              ]),
        ),
        if (!isInspection) ...[
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${isIncrease ? '+' : '-'}${log.quantity}',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 18),
            ),
          ),
        ],
      ]),
    );
  }

  String _fmtDateTime(DateTime d) {
    final date = '${d.day}/${d.month}/${d.year}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date  $time';
  }
}
