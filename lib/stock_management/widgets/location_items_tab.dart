import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../repositories/stock_repository.dart';
import '../../widgets/stock_widgets.dart';
import '../models/stock_models.dart';

/// Consolidated, read-only items view for a building (floorId == null) or
/// a single floor. Groups room-level rows by catalog item, live.
///
/// Location comes from each doc's path (no backfill); names resolve via a
/// one-shot scoped walk. No actions here by design — stock moves happen in
/// the room.
class LocationItemsTab extends ConsumerStatefulWidget {
  final String buildingId;
  final String? floorId;
  final String scopeLabel; // e.g. 'Main Block' / 'Ground Floor'

  const LocationItemsTab({
    super.key,
    required this.buildingId,
    this.floorId,
    required this.scopeLabel,
  });

  @override
  ConsumerState<LocationItemsTab> createState() => _LocationItemsTabState();
}

class _LocationItemsTabState extends ConsumerState<LocationItemsTab> {
  late final Future<
      ({
        Map<String, String> floorNames,
        Map<String, String> roomNames
      })> _namesFuture;

  @override
  void initState() {
    super.initState();
    _namesFuture = ref
        .read(stockRepositoryProvider)
        .fetchLocationNames(widget.buildingId);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(stockRepositoryProvider);
    return FutureBuilder<
        ({
          Map<String, String> floorNames,
          Map<String, String> roomNames
        })>(
      future: _namesFuture,
      builder: (context, nameSnap) {
        if (nameSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final names = nameSnap.data;
        final floorNames = names?.floorNames ?? {};
        final roomNames = names?.roomNames ?? {};
        return StreamBuilder<List<ScopedStockItem>>(
          stream: service.watchAllRoomItems(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data ?? [];
            // Scope to this building (and floor), drop fully-consumed rows.
            final scoped = all.where((s) {
              if (s.buildingId != widget.buildingId) return false;
              if (widget.floorId != null && s.floorId != widget.floorId) {
                return false;
              }
              return s.item.currentQuantity > 0;
            }).toList();
            if (scoped.isEmpty) {
              return StockEmptyState(
                message:
                    'No items in ${widget.scopeLabel} yet.\nAdd stock from a room to see it here.',
              );
            }
            // Group by catalog item (room doc id == catalog item id).
            final groups = <String, List<ScopedStockItem>>{};
            for (final s in scoped) {
              (groups[s.item.id ?? ''] ??= []).add(s);
            }
            final ids = groups.keys.toList()
              ..sort((a, b) => (groups[a]!.first.item.name)
                  .compareTo(groups[b]!.first.item.name));
            final locationCount = scoped.length;

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: ids.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _SummaryHeader(
                    itemCount: ids.length,
                    locationCount: locationCount,
                  );
                }
                final rows = groups[ids[i - 1]]!;
                rows.sort((a, b) {
                  final fa = floorNames[a.floorId] ?? a.floorId;
                  final fb = floorNames[b.floorId] ?? b.floorId;
                  final c = fa.compareTo(fb);
                  if (c != 0) return c;
                  final ra = roomNames['${a.floorId}/${a.roomId}'] ?? a.roomId;
                  final rb = roomNames['${b.floorId}/${b.roomId}'] ?? b.roomId;
                  return ra.compareTo(rb);
                });
                return _ItemGroupCard(
                  rows: rows,
                  floorNames: floorNames,
                  roomNames: roomNames,
                  showFloor: widget.floorId == null,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int itemCount;
  final int locationCount;
  const _SummaryHeader(
      {required this.itemCount, required this.locationCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3C6E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF1A3C6E).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 18, color: Color(0xFF1A3C6E)),
          const SizedBox(width: 8),
          Text(
            '$itemCount item${itemCount == 1 ? '' : 's'}'
            ' across $locationCount location${locationCount == 1 ? '' : 's'}',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A3C6E),
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ItemGroupCard extends StatelessWidget {
  final List<ScopedStockItem> rows;
  final Map<String, String> floorNames;
  final Map<String, String> roomNames;
  final bool showFloor;

  const _ItemGroupCard({
    required this.rows,
    required this.floorNames,
    required this.roomNames,
    required this.showFloor,
  });

  @override
  Widget build(BuildContext context) {
    final first = rows.first.item;
    final total = rows.fold(0, (a, s) => a + s.item.currentQuantity);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor:
              const Color(0xFF1A3C6E).withValues(alpha: 0.1),
          child: Text(
            first.name.isNotEmpty ? first.name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Color(0xFF1A3C6E), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(first.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${rows.length} location${rows.length == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3C6E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$total ${first.unit}',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A3C6E),
                fontSize: 13),
          ),
        ),
        children: [
          for (final s in rows)
            ListTile(
              dense: true,
              leading: const Icon(Icons.place_outlined,
                  size: 18, color: Colors.grey),
              title: Text(
                showFloor
                    ? '${floorNames[s.floorId] ?? s.floorId}  •  '
                        '${roomNames['${s.floorId}/${s.roomId}'] ?? s.roomId}'
                    : (roomNames['${s.floorId}/${s.roomId}'] ?? s.roomId),
                style: const TextStyle(fontSize: 13),
              ),
              trailing: Text(
                '${s.item.currentQuantity} ${s.item.unit}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
