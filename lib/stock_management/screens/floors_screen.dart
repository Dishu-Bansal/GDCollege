import 'package:flutter/material.dart';
import '../models/stock_models.dart';
import '../../repositories/stock_repository.dart';
import '../../providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/stock_widgets.dart';
import 'rooms_screen.dart';

class FloorsScreen extends ConsumerWidget {
  final BuildingModel building;
  const FloorsScreen({super.key, required this.building});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(stockRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(building.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Text('Floors',
                  style:
                  TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Floor',
            onPressed: () => _addFloor(context, service),
          ),
        ],
      ),
      body: StreamBuilder<List<FloorModel>>(
        stream: service.watchFloors(building.id!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final floors = snap.data ?? [];
          if (floors.isEmpty) {
            return StockEmptyState(
              message:
              'No floors in ${building.name}.\nAdd the first floor.',
              actionLabel: 'Add Floor',
              onAction: () => _addFloor(context, service),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: floors.length,
            itemBuilder: (_, i) => _FloorCard(
              floor: floors[i],
              building: building,
              service: service,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFloor(context, service),
        backgroundColor: const Color(0xFF1A3C6E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Floor',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _addFloor(
      BuildContext context, StockRepository service) async {
    final name = await showNameDialog(context,
        title: 'Add Floor',
        hint: 'e.g. Ground Floor, 1st Floor');
    if (name != null) await service.addFloor(building.id!, name);
  }
}

class _FloorCard extends StatelessWidget {
  final FloorModel floor;
  final BuildingModel building;
  final StockRepository service;

  const _FloorCard({
    required this.floor,
    required this.building,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      // Feature: Inspection Tracking - watch rooms on this floor to detect due
      child: StreamBuilder<List<RoomModel>>(
        stream: service.watchRooms(building.id!, floor.id!),
        builder: (context, snap) {
          final rooms = snap.data ?? [];
          final dueRooms =
              rooms.where((r) => r.isInspectionDue).toList();
          return _FloorCardTile(
            floor: floor,
            building: building,
            service: service,
            dueRooms: dueRooms,
          );
        },
      ),
    );
  }
}

class _FloorCardTile extends StatelessWidget {
  final FloorModel floor;
  final BuildingModel building;
  final StockRepository service;
  final List<RoomModel> dueRooms;

  const _FloorCardTile({
    required this.floor,
    required this.building,
    required this.service,
    required this.dueRooms,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RoomsScreen(building: building, floor: floor),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.layers_outlined,
                    color: Colors.teal, size: 26),
              ),
              if (dueRooms.isNotEmpty)
                const Positioned(
                  top: -4,
                  right: -4,
                  child: InspectionDueBadge(),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(floor.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                // Feature: Inspection Tracking - list rooms due or never
                // inspected with their last inspection date.
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
                  for (final r in dueRooms)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: InspectionStatusLine(
                          room: r, includeRoomName: true),
                    ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                final name = await showNameDialog(context,
                    title: 'Rename Floor', initial: floor.name);
                if (name != null) {
                  await service.updateFloor(
                      building.id!, floor.id!, name);
                }
              } else if (v == 'delete') {
                final ok = await confirmDelete(context,
                    label: floor.name);
                if (ok) {
                  await service.deleteFloor(
                      building.id!, floor.id!);
                }
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
        ]),
      ),
    );
  }
}
