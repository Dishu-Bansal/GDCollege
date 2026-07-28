import 'package:flutter/material.dart';
import 'package:gd_college/widgets/drawer.dart';
import '../models/stock_models.dart';
import '../../repositories/stock_repository.dart';
import '../../providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/stock_widgets.dart';
import 'floors_screen.dart';

class BuildingsScreen extends ConsumerWidget {
  const BuildingsScreen({super.key});

  static const _kPrimary = Color(0xFF1A3C6E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(stockRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      drawer: getSideDrawer(context),
      appBar: AppBar(
        title: const Text('Stock Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_outlined),
            tooltip: 'Add Building',
            onPressed: () => _addBuilding(context, service),
          ),
        ],
      ),
      body: StreamBuilder<List<BuildingModel>>(
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
              onAction: () => _addBuilding(context, service),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addBuilding(context, service),
        backgroundColor: _kPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Building',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _addBuilding(
      BuildContext context, StockRepository service) async {
    final name = await showNameDialog(context,
        title: 'Add Building', hint: 'e.g. Main Block, Hostel A');
    if (name != null) await service.addBuilding(name);
  }
}

class _BuildingCard extends StatelessWidget {
  final BuildingModel building;
  final StockRepository service;

  const _BuildingCard(
      {required this.building, required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      // Feature: Media Freshness â€” stream all rooms under this building's
      // floors to determine if any room is overdue.
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
      return _tile(context, hasOverdue: false);
    }

    // Combine room streams for all floors to detect any overdue room
    return _MultiFloorRoomWatcher(
      building: building,
      floors: floors,
      service: service,
      builder: (hasOverdue) => _tile(context, hasOverdue: hasOverdue),
    );
  }

  Widget _tile(BuildContext context, {required bool hasOverdue}) {
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
          if (hasOverdue)
            const Positioned(
              top: -4,
              right: -4,
              child: MediaOverdueBadge(),
            ),
        ],
      ),
      title: Text(building.name,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: building.createdAt != null
          ? Text(
        'Added ${building.createdAt!.day}/${building.createdAt!.month}/${building.createdAt!.year}',
        style: TextStyle(
            fontSize: 11, color: Colors.grey.shade500),
      )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                final name = await showNameDialog(context,
                    title: 'Rename Building',
                    initial: building.name);
                if (name != null) {
                  await service.updateBuilding(building.id!, name);
                }
              } else if (v == 'delete') {
                final ok = await confirmDelete(context,
                    label: building.name);
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

/// Watches room streams across multiple floors and reports whether any room
/// has overdue media. This is purely client-side â€” no extra Firestore queries
/// beyond what is already streamed.
class _MultiFloorRoomWatcher extends StatelessWidget {
  final BuildingModel building;
  final List<FloorModel> floors;
  final StockRepository service;
  final Widget Function(bool hasOverdue) builder;

  const _MultiFloorRoomWatcher({
    required this.building,
    required this.floors,
    required this.service,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    // Use the first floor as the anchor; for a production app with many floors
    // you'd combine multiple StreamBuilders or use rxdart's CombineLatestStream.
    // For simplicity we watch all floors sequentially.
    return _FloorRoomWatcher(
      building: building,
      floors: floors,
      index: 0,
      service: service,
      accumulatedOverdue: false,
      builder: builder,
    );
  }
}

class _FloorRoomWatcher extends StatelessWidget {
  final BuildingModel building;
  final List<FloorModel> floors;
  final int index;
  final StockRepository service;
  final bool accumulatedOverdue;
  final Widget Function(bool) builder;

  const _FloorRoomWatcher({
    required this.building,
    required this.floors,
    required this.index,
    required this.service,
    required this.accumulatedOverdue,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (index >= floors.length) return builder(accumulatedOverdue);

    return StreamBuilder<List<RoomModel>>(
      stream: service.watchRooms(building.id!, floors[index].id!),
      builder: (context, snap) {
        final rooms = snap.data ?? [];
        final floorOverdue = rooms.any((r) => r.isMediaOverdue);
        final nowOverdue = accumulatedOverdue || floorOverdue;

        if (nowOverdue) return builder(true);

        return _FloorRoomWatcher(
          building: building,
          floors: floors,
          index: index + 1,
          service: service,
          accumulatedOverdue: nowOverdue,
          builder: builder,
        );
      },
    );
  }
}
