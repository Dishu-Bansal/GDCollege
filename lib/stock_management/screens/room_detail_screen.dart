import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import '../models/stock_models.dart';
import '../../repositories/stock_repository.dart';
import '../../providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/stock_widgets.dart';
import 'rooms_screen.dart' show MediaUploadSheet;

class RoomDetailScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;

  const RoomDetailScreen({
    super.key,
    required this.building,
    required this.floor,
    required this.room,
  });


}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  StockRepository get _service => ref.read(stockRepositoryProvider);

  @override
  void initState() {
    super.initState();
    // 4 tabs: Items | Media | Log | Inspections
    _tabs = TabController(length: 4, vsync: this);
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
      appBar: AppBar(
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.room.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                  '${widget.building.name}  ›  ${widget.floor.name}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white70)),
            ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: 'Upload media',
            onPressed: _uploadMedia,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(
                icon: Icon(Icons.inventory_2_outlined, size: 18),
                text: 'Items'),
            Tab(
                icon: Icon(Icons.photo_library_outlined, size: 18),
                text: 'Media'),
            Tab(
                icon: Icon(Icons.history, size: 18), text: 'Log'),
            Tab(
                icon: Icon(Icons.checklist_outlined, size: 18),
                text: 'Inspect'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ItemsTab(
            building: widget.building,
            floor: widget.floor,
            room: widget.room,
            service: _service,
          ),
          _MediaTab(
            building: widget.building,
            floor: widget.floor,
            room: widget.room,
            service: _service,
          ),
          _LogTab(
            building: widget.building,
            floor: widget.floor,
            room: widget.room,
            service: _service,
          ),
          // Feature: Inspections
          _InspectionsTab(
            building: widget.building,
            floor: widget.floor,
            room: widget.room,
            service: _service,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(context),
        backgroundColor: const Color(0xFF1A3C6E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Item',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _addItem(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => _ItemFormDialog(
        onSave: (item) async {
          await _service.addItem(widget.building.id!,
              widget.floor.id!, widget.room.id!, item,
              buildingName: widget.building.name,
              floorName: widget.floor.name,
              roomName: widget.room.name);
        },
      ),
    );
  }

  Future<void> _uploadMedia() async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => MediaUploadSheet(
        building: widget.building,
        floor: widget.floor,
        room: widget.room,
        service: _service,
      ),
    );
  }
}

// ── Items Tab ─────────────────────────────────────────────────────────────────
List<StockItem> items = [];

class _ItemsTab extends StatelessWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockRepository service;

  const _ItemsTab({
    required this.building,
    required this.floor,
    required this.room,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockItem>>(
      stream: service.watchItems(building.id!, floor.id!, room.id!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        items = snap.data ?? [];

        if (items.isEmpty) {
          return const StockEmptyState(
              message:
              'No items in this room.\nTap + Add Item to begin.');
        }

        final totalValue =
        items.fold<double>(0, (s, i) => s + i.totalValue);

        return Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(children: [
              _SummaryChip(
                  label: '${items.length} Items',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF1A3C6E)),
              const SizedBox(width: 10),
              _SummaryChip(
                  label:
                  '₹${totalValue.toStringAsFixed(2)} Total',
                  icon: Icons.currency_rupee,
                  color: Colors.green.shade700),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
              itemBuilder: (_, i) => _ItemCard(
                item: items[i],
                building: building,
                floor: floor,
                room: room,
                service: service,
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final StockItem item;
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockRepository service;

  const _ItemCard({
    required this.item,
    required this.building,
    required this.floor,
    required this.room,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = item.currentQuantity <= -1;
    final isOut = item.currentQuantity == 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOut
              ? Colors.red.shade200
              : isLow
              ? Colors.orange.shade200
              : Colors.transparent,
          width: isOut || isLow ? 1.5 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + actions
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        '₹${item.unitPrice.toStringAsFixed(2)} / unit  •  '
                            'Total: ₹${item.totalValue.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600),
                      ),
                    ]),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await showDialog(
                      context: context,
                      builder: (_) => _ItemFormDialog(
                        initial: item,
                        onSave: (updated) async {
                          updated.id = item.id;
                          await service.updateItem(building.id!,
                              floor.id!, room.id!, updated);
                        },
                      ),
                    );
                  } else if (v == 'delete') {
                    final ok = await confirmDelete(context,
                        label: item.name);
                    if (ok) {
                      await service.deleteItem(building.id!,
                          floor.id!, room.id!, item.id!);
                    }
                  } else if (v == 'log') {
                    await showDialog(
                      context: context,
                      builder: (_) => _ItemLogDialog(
                        building: building,
                        floor: floor,
                        room: room,
                        item: item,
                        service: service,
                      ),
                    );
                  } else if (v == 'transfer') {
                    // Feature: Stock Transfer
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16))),
                      builder: (_) => _TransferSheet(
                        building: building,
                        floor: floor,
                        room: room,
                        item: item,
                        service: service,
                      ),
                    );
                  } else if (v == 'assign') {
                    // Feature: Consumable Assignment
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16))),
                      builder: (_) => _AssignSheet(
                        building: building,
                        floor: floor,
                        room: room,
                        item: item,
                        service: service,
                      ),
                    );
                  } else if (v == 'assignments') {
                    // Feature: View active assignments for this item
                    await showDialog(
                      context: context,
                      builder: (_) => _AssignmentsDialog(
                        building: building,
                        floor: floor,
                        room: room,
                        item: item,
                        service: service,
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  // const PopupMenuItem(
                  //     value: 'edit',
                  //     child: Row(children: [
                  //       Icon(Icons.edit_outlined, size: 16),
                  //       SizedBox(width: 8),
                  //       Text('Edit Item'),
                  //     ])),
                  const PopupMenuItem(
                      value: 'log',
                      child: Row(children: [
                        Icon(Icons.history, size: 16),
                        SizedBox(width: 8),
                        Text('View Log'),
                      ])),
                  // Feature: Stock Transfer
                  const PopupMenuItem(
                      value: 'transfer',
                      child: Row(children: [
                        Icon(Icons.swap_horiz_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Transfer'),
                      ])),
                  // Feature: Consumable Assignment
                  const PopupMenuItem(
                      value: 'assign',
                      child: Row(children: [
                        Icon(Icons.person_add_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Assign'),
                      ])),
                  const PopupMenuItem(
                      value: 'assignments',
                      child: Row(children: [
                        Icon(Icons.people_outline, size: 16),
                        SizedBox(width: 8),
                        Text('View Assignments'),
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
            ]),

            const SizedBox(height: 12),

            // Quantity row
            Row(children: [
              _QtyButton(
                icon: Icons.remove,
                color: Colors.red.shade600,
                enabled: item.currentQuantity > 0,
                onTap: () => _showAdjustSheet(context, -1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(children: [
                  Text(
                    '${item.currentQuantity}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isOut
                          ? Colors.red
                          : isLow
                          ? Colors.orange
                          : const Color(0xFF1A3C6E),
                    ),
                  ),
                  Text(
                    isOut
                        ? 'Out of Stock'
                        : isLow
                        ? 'Low Stock'
                        : 'in stock',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOut
                          ? Colors.red
                          : isLow
                          ? Colors.orange
                          : Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              _QtyButton(
                icon: Icons.add,
                color: Colors.green.shade700,
                enabled: true,
                onTap: () => _showAdjustSheet(context, 1),
              ),
            ]),

            // Feature: Consumable Assignment — show active assignments badge
            _ActiveAssignmentsBadge(
              itemId: item.id!,
              service: service,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdjustSheet(BuildContext context, int sign) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AdjustSheet(
        item: item,
        sign: sign,
        onConfirm: (qty, note) async {
          await service.adjustQuantity(
            buildingId: building.id!,
            floorId: floor.id!,
            roomId: room.id!,
            item: item,
            delta: sign * qty,
            note: note,
            buildingName: building.name,
            floorName: floor.name,
            roomName: room.name,
          );
        },
      ),
    );
  }
}

// ── Active Assignments Badge ──────────────────────────────────────────────────

class _ActiveAssignmentsBadge extends StatelessWidget {
  final String itemId;
  final StockRepository service;

  const _ActiveAssignmentsBadge(
      {required this.itemId, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConsumableAssignment>>(
      stream: service.watchAssignments(itemId: itemId),
      builder: (context, snap) {
        final assignments = snap.data ?? [];
        if (assignments.isEmpty) return const SizedBox.shrink();

        final totalOut = assignments.fold<int>(
            0, (s, a) => s + a.outstandingQty);
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.purple.shade200),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline,
                  size: 13, color: Colors.purple.shade700),
              const SizedBox(width: 5),
              Text(
                '$totalOut assigned out  •  '
                    '${assignments.length} active',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? color.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? color.withOpacity(0.3)
                : Colors.grey.shade200,
          ),
        ),
        child: Icon(icon,
            color: enabled ? color : Colors.grey.shade300,
            size: 22),
      ),
    );
  }
}

// ── Adjust quantity bottom sheet ──────────────────────────────────────────────

class _AdjustSheet extends StatefulWidget {
  final StockItem item;
  final int sign;
  final Future<void> Function(int qty, String note) onConfirm;

  const _AdjustSheet({
    required this.item,
    required this.sign,
    required this.onConfirm,
  });

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;
    setState(() => _saving = true);
    await widget.onConfirm(qty, _noteCtrl.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isIncrease = widget.sign > 0;
    final color =
    isIncrease ? Colors.green.shade700 : Colors.red.shade600;
    final preview = int.tryParse(_qtyCtrl.text) ?? 0;
    final newQty = isIncrease
        ? widget.item.currentQuantity + preview
        : (widget.item.currentQuantity - preview).clamp(0, 999999);

    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
                isIncrease ? Icons.add : Icons.remove,
                color: color,
                size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIncrease ? 'Increase Stock' : 'Decrease Stock',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: color),
                  ),
                  Text(widget.item.name,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600)),
                ]),
          ),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context)),
        ]),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(children: [
                  Text('Current',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500)),
                  Text('${widget.item.currentQuantity}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700)),
                ]),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.arrow_forward,
                      color: color, size: 20),
                ),
                Column(children: [
                  Text('New',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500)),
                  Text('$newQty',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ]),
              ]),
        ),

        const SizedBox(height: 16),

        TextField(
          controller: _qtyCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'Quantity',
            prefixIcon: IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () {
                final v =
                    (int.tryParse(_qtyCtrl.text) ?? 1) - 1;
                if (v > 0) _qtyCtrl.text = '$v';
                setState(() {});
              },
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                final v =
                    (int.tryParse(_qtyCtrl.text) ?? 0) + 1;
                _qtyCtrl.text = '$v';
                setState(() {});
              },
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            hintText: isIncrease
                ? 'e.g. Restocked from supplier'
                : 'e.g. Used for maintenance',
            prefixIcon:
            const Icon(Icons.notes_outlined, size: 18),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding:
              const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white))
                : Text(
                isIncrease
                    ? 'Confirm Increase'
                    : 'Confirm Decrease',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ── Stock Transfer bottom sheet ───────────────────────────────────────────────
// Feature: Stock Transfer

class _TransferSheet extends StatefulWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockItem item;
  final StockRepository service;

  const _TransferSheet({
    required this.building,
    required this.floor,
    required this.room,
    required this.item,
    required this.service,
  });

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  List<BuildingModel> _buildings = [];
  List<FloorModel> _floors = [];
  List<RoomModel> _rooms = [];

  BuildingModel? _toBuilding;
  FloorModel? _toFloor;
  RoomModel? _toRoom;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    widget.service.watchBuildings().first.then((b) {
      if (mounted) setState(() => _buildings = b);
    });
  }

  Future<void> _onBuildingChanged(BuildingModel? b) async {
    setState(() {
      _toBuilding = b;
      _toFloor = null;
      _toRoom = null;
      _floors = [];
      _rooms = [];
    });
    if (b == null) return;
    final floors = await widget.service.watchFloors(b.id!).first;
    if (mounted) setState(() => _floors = floors);
  }

  Future<void> _onFloorChanged(FloorModel? f) async {
    setState(() {
      _toFloor = f;
      _toRoom = null;
      _rooms = [];
    });
    if (f == null || _toBuilding == null) return;
    final rooms = await widget.service
        .watchRooms(_toBuilding!.id!, f.id!)
        .first;
    if (mounted) {
      setState(() {
        // Exclude the source room
        _rooms = rooms
            .where((r) =>
        !(r.id == widget.room.id &&
            f.id == widget.floor.id &&
            _toBuilding!.id == widget.building.id))
            .toList();
      });
    }
  }

  Future<void> _confirm() async {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0 ||
        _toBuilding == null ||
        _toFloor == null ||
        _toRoom == null) return;

    setState(() => _saving = true);
    try {
      await widget.service.transferItem(
        fromBuilding: widget.building,
        fromFloor: widget.floor,
        fromRoom: widget.room,
        toBuilding: _toBuilding!,
        toFloor: _toFloor!,
        toRoom: _toRoom!,
        item: widget.item,
        quantity: qty,
        note: _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxQty = widget.item.currentQuantity;

    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.swap_horiz_outlined,
                  color: Colors.blue.shade700, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transfer Item',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.blue.shade700)),
                    Text(widget.item.name,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600)),
                  ]),
            ),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),

          const SizedBox(height: 4),
          Text(
            'Available: $maxQty  •  From: ${widget.room.name}',
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade500),
          ),

          const SizedBox(height: 20),

          // Destination building
          DropdownButtonFormField<BuildingModel>(
            value: _toBuilding,
            decoration: InputDecoration(
              labelText: 'Destination Building',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            items: _buildings
                .map((b) => DropdownMenuItem(
                value: b, child: Text(b.name)))
                .toList(),
            onChanged: _onBuildingChanged,
          ),

          const SizedBox(height: 12),

          // Destination floor
          DropdownButtonFormField<FloorModel>(
            value: _toFloor,
            decoration: InputDecoration(
              labelText: 'Destination Floor',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            items: _floors
                .map((f) => DropdownMenuItem(
                value: f, child: Text(f.name)))
                .toList(),
            onChanged: _toBuilding == null
                ? null
                : _onFloorChanged,
          ),

          const SizedBox(height: 12),

          // Destination room
          DropdownButtonFormField<RoomModel>(
            value: _toRoom,
            decoration: InputDecoration(
              labelText: 'Destination Room',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            items: _rooms
                .map((r) => DropdownMenuItem(
                value: r, child: Text(r.name)))
                .toList(),
            onChanged: _toFloor == null
                ? null
                : (r) => setState(() => _toRoom = r),
          ),

          const SizedBox(height: 12),

          // Quantity
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly
            ],
            decoration: InputDecoration(
              labelText: 'Quantity to Transfer',
              helperText: 'Max: $maxQty',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
              (_saving || _toRoom == null) ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding:
                const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white))
                  : const Text('Confirm Transfer',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Assign Consumable bottom sheet ────────────────────────────────────────────
// Feature: Consumable Assignment

class _AssignSheet extends StatefulWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockItem item;
  final StockRepository service;

  const _AssignSheet({
    required this.building,
    required this.floor,
    required this.room,
    required this.item,
    required this.service,
  });

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final name = _nameCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (name.isEmpty || qty <= 0) return;

    setState(() => _saving = true);
    try {
      await widget.service.assignConsumable(
        building: widget.building,
        floor: widget.floor,
        room: widget.room,
        item: widget.item,
        quantity: qty,
        assignedTo: name,
        note: _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person_add_outlined,
                color: Colors.purple.shade700, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign to Staff',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.purple.shade700)),
                  Text(widget.item.name,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600)),
                ]),
          ),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context)),
        ]),

        const SizedBox(height: 4),
        Text(
          'Available: ${widget.item.currentQuantity}',
          style:
          TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),

        const SizedBox(height: 20),

        TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Staff Name *',
            prefixIcon:
            const Icon(Icons.person_outline, size: 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _qtyCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly
          ],
          decoration: InputDecoration(
            labelText: 'Quantity *',
            helperText: 'Max: ${widget.item.currentQuantity}',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              padding:
              const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white))
                : const Text('Assign',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ── Assignments dialog ────────────────────────────────────────────────────────

class _AssignmentsDialog extends StatelessWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockItem item;
  final StockRepository service;

  const _AssignmentsDialog({
    required this.building,
    required this.floor,
    required this.room,
    required this.item,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 400,
        height: 500,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Text('Assignments: ${item.name}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF1A3C6E))),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ConsumableAssignment>>(
              stream: service.watchAssignments(itemId: item.id),
              builder: (context, snap) {
                final assignments = snap.data ?? [];
                if (assignments.isEmpty) {
                  return const Center(
                      child: Text('No active assignments.',
                          style:
                          TextStyle(color: Colors.grey)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: assignments.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
                  itemBuilder: (_, i) => _AssignmentTile(
                    assignment: assignments[i],
                    building: building,
                    floor: floor,
                    room: room,
                    item: item,
                    service: service,
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  final ConsumableAssignment assignment;
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockItem item;
  final StockRepository service;

  const _AssignmentTile({
    required this.assignment,
    required this.building,
    required this.floor,
    required this.room,
    required this.item,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.person_outline,
                  size: 16, color: Colors.purple.shade700),
              const SizedBox(width: 6),
              Text(assignment.assignedTo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${assignment.outstandingQty} out',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              'Assigned ${_fmtDate(assignment.assignedAt)}  '
                  '•  Total: ${assignment.quantity}',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500),
            ),
            if (assignment.note.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(assignment.note,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 8),
            // Return button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16))),
                    builder: (_) => _ReturnSheet(
                      assignment: assignment,
                      building: building,
                      floor: floor,
                      room: room,
                      item: item,
                      service: service,
                    ),
                  );
                },
                icon: const Icon(Icons.assignment_return_outlined,
                    size: 16),
                label: const Text('Return'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple.shade700,
                  side:
                  BorderSide(color: Colors.purple.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ]),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}

// ── Return Consumable bottom sheet ────────────────────────────────────────────

class _ReturnSheet extends StatefulWidget {
  final ConsumableAssignment assignment;
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockItem item;
  final StockRepository service;

  const _ReturnSheet({
    required this.assignment,
    required this.building,
    required this.floor,
    required this.room,
    required this.item,
    required this.service,
  });

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  late final TextEditingController _qtyCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: '${widget.assignment.outstandingQty}');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;
    setState(() => _saving = true);
    try {
      await widget.service.returnConsumable(
        building: widget.building,
        floor: widget.floor,
        room: widget.room,
        item: widget.item,
        assignment: widget.assignment,
        returnQty: qty,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.assignment_return_outlined,
                color: Colors.green.shade700, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Return Stock',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.green.shade700)),
                  Text(
                      'From: ${widget.assignment.assignedTo}  •  '
                          '${widget.assignment.outstandingQty} outstanding',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600)),
                ]),
          ),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context)),
        ]),

        const SizedBox(height: 20),

        TextField(
          controller: _qtyCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly
          ],
          decoration: InputDecoration(
            labelText: 'Return Quantity',
            helperText:
            'Max: ${widget.assignment.outstandingQty}',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding:
              const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white))
                : const Text('Confirm Return',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ── Item form dialog (add / edit) ─────────────────────────────────────────────

class _ItemFormDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ItemFormDialog> createState() => _ItemFormDialogState();
  final StockItem? initial;
  final Future<void> Function(StockItem) onSave;

  const _ItemFormDialog({this.initial, required this.onSave});


}

class _ItemFormDialogState extends ConsumerState<_ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  StockRepository get _service => ref.read(stockRepositoryProvider);
  CatalogItem? _selectedCatalogItem;
  List<CatalogItem> _catalogSummaries = [];
  bool _isLoading = true;
  late TextEditingController? _nameCtrl;
  late final String itemid;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _storeNameCtrl;
  late final TextEditingController _billCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog(widget.initial);
    _nameCtrl =
        TextEditingController(text: widget.initial?.name ?? '');
    _priceCtrl = TextEditingController(
        text: widget.initial?.unitPrice.toString() ?? '');
    _qtyCtrl = TextEditingController(
        text:
        widget.initial?.currentQuantity.toString() ?? '0');
    _storeNameCtrl = TextEditingController(
        text: widget.initial?.store ?? '');
    _billCtrl = TextEditingController(
        text: widget.initial?.bill ?? '');
  }

  Future<void> _loadCatalog(StockItem? initial) async {
    if (initial != null) {
      _selectedCatalogItem = await _service.getCatalogItemById(initial!.id!);
    }
    final names = await _service.getCatalogItemSummaries();
    if (mounted) {
      setState(() {
        _catalogSummaries = names;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl?.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _storeNameCtrl.dispose();
    _billCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await widget.onSave(StockItem(
      id: _selectedCatalogItem != null ? _selectedCatalogItem!.id : null,
      name: _selectedCatalogItem == null ? _nameCtrl!.text.trim() : _selectedCatalogItem!.name,
      unitPrice: double.tryParse(_priceCtrl.text) ?? 0,
      currentQuantity: int.tryParse(_qtyCtrl.text) ?? 0,
      store: _storeNameCtrl.text.trim(),
      bill: _billCtrl.text.trim(),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      title: Text(
        widget.initial != null ? 'Edit Item' : 'Add Item',
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A3C6E)),
      ),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        Autocomplete<CatalogItem>(
        displayStringForOption: (option) => option.name,
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<CatalogItem>.empty();
          }
          return _catalogSummaries.where((option)
          {
            return option.name.toLowerCase().contains(
                textEditingValue.text.toLowerCase()) &&
                !(items.any((i) => i.id == option.id));
          });
        },
        onSelected: (CatalogItem selection) {
          // User picked a matching global item!
          setState(() {
            _selectedCatalogItem = selection;
            // Pre-fill the price with the global price for convenience
            // _priceController.text = selection.unitPrice.toString();
          });
        },
        // This is crucial: It exposes the text controller inside the autocomplete input field
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          _nameCtrl = textEditingController; // Bind it to our state

          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            decoration: const InputDecoration(
              labelText: 'Item Name',
              hintText: 'Type to search or enter new name',
            ),
            onChanged: (text) {
              // If the user modifies the text after choosing an item from the list,
              // break the link so it evaluates as a new item or checks matching lists again.
              if (_selectedCatalogItem != null && text != _selectedCatalogItem!.name) {
                setState(() {
                  _selectedCatalogItem = null;
                });
              }
            },
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          );
        },
      ),
      //TextFormField(
          //   controller: _nameCtrl,
          //   autofocus: true,
          //   decoration: InputDecoration(
          //     labelText: 'Item Name *',
          //     border: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(8)),
          //   ),
          //   validator: (v) =>
          //   v == null || v.isEmpty ? 'Required' : null,
          // ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
            decoration: InputDecoration(
              labelText: 'Unit Price (₹) *',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            validator: (v) =>
            v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly
            ],
            decoration: InputDecoration(
              labelText: 'Initial Quantity',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          TextFormField(
            controller: _storeNameCtrl,
            decoration: InputDecoration(
              labelText: 'Store Name',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          TextFormField(
            controller: _billCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly
            ],
            decoration: InputDecoration(
              labelText: 'Bill Number',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white))
              : Text(
              widget.initial != null ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ── Item log dialog ───────────────────────────────────────────────────────────

class _ItemLogDialog extends StatelessWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockItem item;
  final StockRepository service;

  const _ItemLogDialog({
    required this.building,
    required this.floor,
    required this.room,
    required this.item,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 400,
        height: 480,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Text('Log: ${item.name}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF1A3C6E))),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<StockLog>>(
              stream: service.watchLogs(
                  building.id!, floor.id!, room.id!,
                  itemId: item.id),
              builder: (context, snap) {
                final logs = snap.data ?? [];
                if (logs.isEmpty) {
                  return const Center(
                      child: Text('No log entries yet.',
                          style:
                          TextStyle(color: Colors.grey)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 6),
                  itemBuilder: (_, i) =>
                      _LogTile(log: logs[i]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Media Tab ─────────────────────────────────────────────────────────────────

class _MediaTab extends StatelessWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockRepository service;

  const _MediaTab({
    required this.building,
    required this.floor,
    required this.room,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RoomModel>>(
      stream: service
          .watchRooms(building.id!, floor.id!)
          .map((rooms) =>
          rooms.where((r) => r.id == room.id).toList()),
      builder: (context, snap) {
        final rooms = snap.data ?? [];
        final current = rooms.isNotEmpty ? rooms.first : room;
        final photos = current.photoUrls;
        final videos = current.videoUrls;

        // Feature: Media Freshness warning in media tab
        final isOverdue = current.isMediaOverdue;
        final lastUpload = current.lastMediaUploadedAt;

        if (photos.isEmpty && videos.isEmpty) {
          return StockEmptyState(
            message: 'No media uploaded for this room.',
            actionLabel: 'Upload Media',
            onAction: () => _upload(context),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Feature: Media Freshness warning banner
            if (isOverdue)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.orange.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lastUpload == null
                          ? 'No media has ever been uploaded for this room.'
                          : 'Last upload was ${DateTime.now().difference(lastUpload).inDays} days ago. '
                          'Media is overdue (>30 days).',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _upload(context),
                    child: const Text('Upload'),
                  ),
                ]),
              ),

            if (photos.isNotEmpty) ...[
              StockSectionHeader(
                title: 'Photos (${photos.length})',
                icon: Icons.photo_outlined,
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: photos.length,
                itemBuilder: (_, i) => _MediaTile(
                  url: photos[i],
                  isVideo: false,
                  onDelete: () async {
                    await service.removeRoomPhoto(
                        building.id!, floor.id!, room.id!,
                        photos[i]);
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (videos.isNotEmpty) ...[
              StockSectionHeader(
                title: 'Videos (${videos.length})',
                icon: Icons.videocam_outlined,
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: videos.length,
                itemBuilder: (_, i) => _MediaTile(
                  url: videos[i],
                  isVideo: true,
                  onDelete: () async {
                    await service.removeRoomVideo(
                        building.id!, floor.id!, room.id!,
                        videos[i]);
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _upload(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => MediaUploadSheet(
        building: building,
        floor: floor,
        room: room,
        service: service,
      ),
    );
  }
}

// ── Media Tile ───────────────────────────────────────────────────────────────
// Shows a photo (Image.network) or an inline HTML5 video on web,
// or a tappable thumbnail on mobile.

class _MediaTile extends StatelessWidget {
  final String url;
  final bool isVideo;
  final VoidCallback onDelete;

  const _MediaTile({
    required this.url,
    required this.isVideo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
        width: 200,
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isVideo ? _VideoTile(url: url) : _ImageTile(url: url),
        ),
      ),
      Positioned(
        top: 4,
        left: 175,
        child: GestureDetector(
          onTap: () async {
            final ok = await confirmDelete(context, label: 'this file');
            if (ok) onDelete();
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ),
      ),
    ]);
  }
}

// ── Image tile ────────────────────────────────────────────────────────────────

class _ImageTile extends StatelessWidget {
  final String url;
  const _ImageTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 10,
      child: Image.network(
        url,
        scale: 2,
        fit: BoxFit.fill,
        // Headers that satisfy Firebase Storage CORS on web
        // headers: kIsWeb ? const {'Access-Control-Allow-Origin': '*'} : null,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Colors.grey.shade100,
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                    progress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (_, error, __) => Container(
          color: Colors.grey.shade200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, color: Colors.grey, size: 24),
              const SizedBox(height: 4),
              Text('Load error',
                  style: TextStyle(
                      fontSize: 9, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Video tile ────────────────────────────────────────────────────────────────
// On web: registers an HTML <video> element and renders it via HtmlElementView.
// On mobile: shows a thumbnail with a tap-to-open-in-browser button.

class _VideoTile extends StatefulWidget {
  final String url;
  const _VideoTile({required this.url});

  @override
  State<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<_VideoTile> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _viewId = 'video-${widget.url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
      // Build the <video> element
      final videoElement = html.VideoElement()
        ..src = widget.url
        ..controls = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.borderRadius = '8px'
        ..setAttribute('playsinline', '');
      // Register so Flutter can embed it
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
            (_) => videoElement,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Mobile: show a play button; tapping opens the URL in the browser
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(widget.url);
          // use url_launcher if available; otherwise show a snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Open video in browser'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () async {
                  // launchUrl(uri) if url_launcher is a dependency
                },
              ),
            ),
          );
        },
        child: Container(
          color: Colors.grey.shade800,
          child: const Center(
            child: Icon(Icons.play_circle_outline,
                color: Colors.white, size: 32),
          ),
        ),
      );
    }

    // Web: embed the <video> element inline
    return HtmlElementView(viewType: _viewId);
  }
}

// ── Log Tab ───────────────────────────────────────────────────────────────────

class _LogTab extends StatelessWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockRepository service;

  const _LogTab({
    required this.building,
    required this.floor,
    required this.room,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockLog>>(
      stream:
      service.watchLogs(building.id!, floor.id!, room.id!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snap.data ?? [];
        if (logs.isEmpty) {
          return const StockEmptyState(
              message:
              'No stock movements yet.\nAdjust item quantities to see the log.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: 6),
          itemBuilder: (_, i) => _LogTile(log: logs[i]),
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  final StockLog log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final isIncrease = log.type == 'increase';
    final color =
    isIncrease ? Colors.green.shade700 : Colors.red.shade600;

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
              isIncrease
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
                Text(log.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                Row(children: [
                  Text(
                    '${log.previousQty} → ${log.newQty}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500),
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
                const SizedBox(height: 2),
                Text(
                  _fmtDateTime(log.timestamp),
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade400),
                ),
              ]),
        ),
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

// ── Inspections Tab ───────────────────────────────────────────────────────────
// Feature: Inspections

class _InspectionsTab extends StatelessWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockRepository service;

  const _InspectionsTab({
    required this.building,
    required this.floor,
    required this.room,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InspectionModel>>(
      stream: service.watchInspections(
          building.id!, floor.id!, room.id!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final inspections = snap.data ?? [];
        final inProgress = inspections
            .where((i) => i.status == 'in_progress')
            .toList();
        final completed = inspections
            .where((i) => i.status == 'completed')
            .toList();

        return Column(children: [
          // Start inspection button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: inProgress.isNotEmpty
                    ? null // disable if one is already running
                    : () => _startInspection(context),
                icon: const Icon(Icons.checklist_outlined),
                label: Text(
                  inProgress.isNotEmpty
                      ? 'Inspection In Progress…'
                      : 'Start Inspection',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3C6E),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // In-progress banner
          if (inProgress.isNotEmpty)
            InkWell(
              onTap: () => _openInspection(
                  context, inProgress.first),
              child: Container(
                color: Colors.amber.shade50,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(children: [
                  Icon(Icons.pending_outlined,
                      color: Colors.amber.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Inspection started ${_fmtDateTime(inProgress.first.startedAt)} — tap to continue',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: Colors.amber.shade800),
                ]),
              ),
            ),

          // Past inspections
          Expanded(
            child: completed.isEmpty
                ? const StockEmptyState(
                message:
                'No completed inspections yet.\nStart an inspection to begin.')
                : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: completed.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _InspectionSummaryTile(
                    inspection: completed[i],
                    onTap: () => _openReport(
                        context, completed[i]),
                  ),
            ),
          ),
        ]);
      },
    );
  }

  Future<void> _startInspection(BuildContext context) async {
    // Fetch current items to snapshot
    final items = await service
        .watchItems(building.id!, floor.id!, room.id!)
        .first;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Add items to this room before starting an inspection.')),
      );
      return;
    }

    final id = await service.startInspection(
      building: building,
      floor: floor,
      room: room,
      currentItems: items,
    );

    // Fetch the newly created inspection and open it
    final inspections = await service
        .watchInspections(building.id!, floor.id!, room.id!)
        .first;
    final inspection =
        inspections.where((i) => i.id == id).firstOrNull;
    if (inspection != null && context.mounted) {
      _openInspection(context, inspection);
    }
  }

  void _openInspection(
      BuildContext context, InspectionModel inspection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionExecutionScreen(
          building: building,
          floor: floor,
          room: room,
          inspection: inspection,
          service: service,
        ),
      ),
    );
  }

  void _openReport(
      BuildContext context, InspectionModel inspection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionReportScreen(
          inspection: inspection,
        ),
      ),
    );
  }

  String _fmtDateTime(DateTime d) {
    return '${d.day}/${d.month}/${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _InspectionSummaryTile extends StatelessWidget {
  final InspectionModel inspection;
  final VoidCallback onTap;

  const _InspectionSummaryTile({
    required this.inspection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = inspection.checklistItems.length;
    final matched =
        inspection.checklistItems.where((e) => e.matched).length;
    final discrepancies = total - matched;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: inspection.hasDiscrepancy
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              inspection.hasDiscrepancy
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: inspection.hasDiscrepancy
                  ? Colors.red.shade600
                  : Colors.green.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fmtDateTime(inspection.startedAt),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$total items checked  •  $matched matched'
                        '${discrepancies > 0 ? '  •  $discrepancies discrepancy' : ''}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (inspection.duration != null)
                    Text(
                      'Duration: ${_fmtDuration(inspection.duration!)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500),
                    ),
                ]),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day}/${d.month}/${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }
}

// ── Inspection Execution Screen ───────────────────────────────────────────────

class InspectionExecutionScreen extends StatefulWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final InspectionModel inspection;
  final StockRepository service;

  const InspectionExecutionScreen({
    super.key,
    required this.building,
    required this.floor,
    required this.room,
    required this.inspection,
    required this.service,
  });

  @override
  State<InspectionExecutionScreen> createState() =>
      _InspectionExecutionScreenState();
}

class _InspectionExecutionScreenState
    extends State<InspectionExecutionScreen> {
  late List<InspectionChecklistItem> _items;
  late List<TextEditingController> _ctrls;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.inspection.checklistItems
        .map((e) => InspectionChecklistItem(
      itemId: e.itemId,
      itemName: e.itemName,
      expectedQty: e.expectedQty,
      actualQty: e.actualQty,
      matched: e.matched,
      note: e.note,
    )));
    _ctrls = _items
        .map((e) => TextEditingController(text: '${e.actualQty}'))
        .toList();
    _noteCtrl.text = widget.inspection.overallNote;
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _updateItem(int i, int newActual) {
    setState(() {
      _items[i].actualQty = newActual;
      _items[i].matched = newActual == _items[i].expectedQty;
    });
    // Persist progress
    widget.service.updateInspectionChecklist(
      buildingId: widget.building.id!,
      floorId: widget.floor.id!,
      roomId: widget.room.id!,
      inspectionId: widget.inspection.id!,
      checklistItems: _items,
      overallNote: _noteCtrl.text.trim(),
    );
  }

  bool get _hasDiscrepancy => _items.any((e) => !e.matched);

  Future<void> _complete() async {
    // If discrepancies found, ask whether to upload media
    final hasMedia = widget.room.photoUrls.isNotEmpty ||
        widget.room.videoUrls.isNotEmpty;
    final mediaOverdue = widget.room.isMediaOverdue;

    if (_hasDiscrepancy && mediaOverdue && !hasMedia) {
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: const Text('Missing Media Evidence'),
          content: const Text(
              'Stock discrepancies were found but no photos/videos '
                  'have been uploaded this month. Consider uploading '
                  'proof before completing.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, 'skip'),
                child: const Text('Complete Anyway')),
            ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, 'upload'),
                child: const Text('Upload Now')),
          ],
        ),
      );

      if (choice == 'upload') {
        // Open media sheet then return without completing
        if (mounted) {
          await showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16))),
            builder: (_) => MediaUploadSheet(
              building: widget.building,
              floor: widget.floor,
              room: widget.room,
              service: widget.service,
            ),
          );
        }
        return;
      }
    }

    // Ask whether to sync quantities
    bool syncQty = false;
    if (_hasDiscrepancy) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: const Text('Sync Stock Quantities?'),
          content: const Text(
              'Discrepancies were found. Should the system update '
                  'stock quantities to match the actual counts you entered?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No, Keep as Is')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Sync')),
          ],
        ),
      );
      syncQty = choice ?? false;
    }

    setState(() => _saving = true);

    final updated = InspectionModel(
      id: widget.inspection.id,
      roomId: widget.inspection.roomId,
      roomName: widget.inspection.roomName,
      floorId: widget.inspection.floorId,
      floorName: widget.inspection.floorName,
      buildingId: widget.inspection.buildingId,
      buildingName: widget.inspection.buildingName,
      startedAt: widget.inspection.startedAt,
      status: 'completed',
      overallNote: _noteCtrl.text.trim(),
      hasDiscrepancy: _hasDiscrepancy,
      checklistItems: _items,
    );

    await widget.service.completeInspection(
      building: widget.building,
      floor: widget.floor,
      room: widget.room,
      inspection: updated,
      syncQuantities: syncQty,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final matched = _items.where((e) => e.matched).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Inspection',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text(widget.room.name,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70)),
            ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '$matched/${_items.length}',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // Progress bar
        LinearProgressIndicator(
          value: _items.isEmpty ? 0 : matched / _items.length,
          backgroundColor: Colors.grey.shade200,
          valueColor:
          const AlwaysStoppedAnimation(Color(0xFF1A3C6E)),
          minHeight: 3,
        ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length + 1, // +1 for note field
            separatorBuilder: (_, __) =>
            const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (i == _items.length) {
                // Overall note
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Overall Note (optional)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => widget.service
                        .updateInspectionChecklist(
                      buildingId: widget.building.id!,
                      floorId: widget.floor.id!,
                      roomId: widget.room.id!,
                      inspectionId: widget.inspection.id!,
                      checklistItems: _items,
                      overallNote: _noteCtrl.text.trim(),
                    ),
                  ),
                );
              }

              final item = _items[i];
              final ctrl = _ctrls[i];

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.matched
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                    width: 1.5,
                  ),
                ),
                child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          item.matched
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: item.matched
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item.itemName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                        Text(
                          'Expected: ${item.expectedQty}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Text('Actual count:',
                            style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 10),
                        _QtyButton(
                          icon: Icons.remove,
                          color: Colors.red.shade600,
                          enabled: item.actualQty > 0,
                          onTap: () {
                            final v = item.actualQty - 1;
                            ctrl.text = '$v';
                            _updateItem(i, v);
                          },
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                              const EdgeInsets.symmetric(
                                  vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(8)),
                            ),
                            onChanged: (v) {
                              final n =
                                  int.tryParse(v) ?? item.actualQty;
                              _updateItem(i, n);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        _QtyButton(
                          icon: Icons.add,
                          color: Colors.green.shade700,
                          enabled: true,
                          onTap: () {
                            final v = item.actualQty + 1;
                            ctrl.text = '$v';
                            _updateItem(i, v);
                          },
                        ),
                      ]),
                      if (!item.matched) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: item.note,
                          decoration: InputDecoration(
                            labelText: 'Note (why mismatch?)',
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(8)),
                          ),
                          onChanged: (v) {
                            setState(() => _items[i].note = v);
                          },
                        ),
                      ],
                    ]),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _complete,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3C6E),
                padding:
                const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white))
                  : const Text('Complete Inspection',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Inspection Report Screen ──────────────────────────────────────────────────

class InspectionReportScreen extends StatelessWidget {
  final InspectionModel inspection;

  const InspectionReportScreen(
      {super.key, required this.inspection});

  @override
  Widget build(BuildContext context) {
    final total = inspection.checklistItems.length;
    final matched =
        inspection.checklistItems.where((e) => e.matched).length;
    final discrepancies = total - matched;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Inspection Report',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inspection.roomName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF1A3C6E))),
                    Text(
                        '${inspection.floorName}  ›  '
                            '${inspection.buildingName}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
                    _ReportRow(
                        label: 'Started',
                        value: _fmt(inspection.startedAt)),
                    if (inspection.completedAt != null)
                      _ReportRow(
                          label: 'Completed',
                          value: _fmt(inspection.completedAt!)),
                    if (inspection.duration != null)
                      _ReportRow(
                          label: 'Duration',
                          value:
                          _fmtDuration(inspection.duration!)),
                    _ReportRow(
                        label: 'Items Checked',
                        value: '$total'),
                    _ReportRow(
                        label: 'Matched',
                        value: '$matched',
                        valueColor: Colors.green.shade700),
                    if (discrepancies > 0)
                      _ReportRow(
                          label: 'Discrepancies',
                          value: '$discrepancies',
                          valueColor: Colors.red.shade600),
                    if (inspection.overallNote.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Note: ${inspection.overallNote}',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic)),
                    ],
                  ]),
            ),
          ),
          const SizedBox(height: 16),

          // Checklist items
          StockSectionHeader(
              title: 'Checklist', icon: Icons.checklist),
          const SizedBox(height: 8),
          ...inspection.checklistItems.map((ci) =>
              _ChecklistReportTile(item: ci)),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';

  String _fmtDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ReportRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1A3C6E))),
      ]),
    );
  }
}

class _ChecklistReportTile extends StatelessWidget {
  final InspectionChecklistItem item;
  const _ChecklistReportTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.matched
              ? Colors.green.shade200
              : Colors.red.shade200,
        ),
      ),
      child: Row(children: [
        Icon(
          item.matched
              ? Icons.check_circle_outline
              : Icons.cancel_outlined,
          color: item.matched
              ? Colors.green.shade600
              : Colors.red.shade600,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(
                  'Expected: ${item.expectedQty}  •  '
                      'Actual: ${item.actualQty}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
                if (item.note.isNotEmpty)
                  Text(item.note,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic)),
              ]),
        ),
        if (!item.matched)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${item.actualQty - item.expectedQty > 0 ? '+' : ''}${item.actualQty - item.expectedQty}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700),
            ),
          ),
      ]),
    );
  }
}
