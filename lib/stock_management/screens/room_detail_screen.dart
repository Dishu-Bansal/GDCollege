import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:image_picker/image_picker.dart';
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
        building: widget.building,
        floor: widget.floor,
        room: widget.room,
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

class _ItemCard extends StatefulWidget {
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
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  CatalogItem? _catalog;
  bool _uploadingPhoto = false;

  StockItem get item => widget.item;
  BuildingModel get building => widget.building;
  FloorModel get floor => widget.floor;
  RoomModel get room => widget.room;
  StockRepository get service => widget.service;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    if (item.id == null) return;
    final cat = await service.getCatalogItemById(item.id!);
    if (mounted) setState(() => _catalog = cat);
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await service.uploadCatalogItemPhoto(
        xfile: file,
        catalogItemId: item.id!,
      );
      if (url != null) {
        final oldUrl = _catalog?.photoUrl ?? '';
        await service.updateCatalogItemPhoto(item.id!, url);
        await service.logItemPhotoChange(
          catalogItemId: item.id!,
          itemName: item.name,
          oldPhotoUrl: oldUrl,
          newPhotoUrl: url,
          building: building,
          floor: floor,
          room: room,
        );
        if (mounted) setState(() => _catalog?.photoUrl = url);
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

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
            // Top row: photo (or add-photo button when missing) + name + actions
            Row(children: [
              ItemPhotoButton(
                service: service,
                catalogItemId: item.id ?? '',
                photoUrl: _catalog?.photoUrl,
                size: 42,
                borderRadius: 6,
                itemName: item.name,
                logRoom: (
                  building: building,
                  floor: floor,
                  room: room,
                ),
                onPhotoUploaded: (url) =>
                    setState(() => _catalog?.photoUrl = url),
              ),
              const SizedBox(width: 10),
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
                        building: building,
                        floor: floor,
                        room: room,
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
                  } else if (v == 'photo') {
                    _pickAndUploadPhoto();
                  } else if (v == 'removePhoto') {
                    final oldUrl = _catalog?.photoUrl ?? '';
                    await service.updateCatalogItemPhoto(item.id!, '');
                    await service.logItemPhotoChange(
                      catalogItemId: item.id!,
                      itemName: item.name,
                      oldPhotoUrl: oldUrl,
                      newPhotoUrl: '',
                      building: building,
                      floor: floor,
                      room: room,
                    );
                    if (mounted) setState(() => _catalog?.photoUrl = null);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'photo',
                      child: Row(children: [
                        _uploadingPhoto
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.camera_alt_outlined, size: 16),
                        const SizedBox(width: 8),
                        Text(_catalog?.photoUrl != null ? 'Change Photo' : 'Add Photo'),
                      ])),
                  if (_catalog?.photoUrl != null)
                    const PopupMenuItem(
                        value: 'removePhoto',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove Photo',
                              style: TextStyle(color: Colors.red)),
                        ])),
                  const PopupMenuItem(
                      value: 'log',
                      child: Row(children: [
                        Icon(Icons.history, size: 16),
                        SizedBox(width: 8),
                        Text('View Log'),
                      ])),
                  const PopupMenuItem(
                      value: 'transfer',
                      child: Row(children: [
                        Icon(Icons.swap_horiz_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Transfer'),
                      ])),
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
        onConfirm: (qty, note, unitPrice, store, bill) async {
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
            unitPrice: unitPrice,
            store: store,
            bill: bill,
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
  final Future<void> Function(int qty, String note, double unitPrice, String store, String bill) onConfirm;

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
  final _priceCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  final _billCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    _priceCtrl.dispose();
    _storeCtrl.dispose();
    _billCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;
    setState(() => _saving = true);
    await widget.onConfirm(
      qty,
      _noteCtrl.text.trim(),
      double.tryParse(_priceCtrl.text) ?? 0,
      _storeCtrl.text.trim(),
      _billCtrl.text.trim(),
    );
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

        if (isIncrease) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Unit Price (₹) (optional)',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _storeCtrl,
            decoration: const InputDecoration(
              labelText: 'Store Name (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _billCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Bill Number (optional)',
            ),
          ),
        ],

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

  // From (source) side
  BuildingModel? _fromBuilding;
  FloorModel? _fromFloor;
  RoomModel? _fromRoom;
  List<FloorModel> _fromFloors = [];
  List<RoomModel> _fromRooms = [];

  // To (destination) side
  BuildingModel? _toBuilding;
  FloorModel? _toFloor;
  RoomModel? _toRoom;
  List<FloorModel> _toFloors = [];
  List<RoomModel> _toRooms = [];

  /// Quantity of the item available at the currently selected From location.
  /// Kept in sync with the From selection so the helper text and the service
  /// clamp always reflect the real source stock.
  int _maxQty = 0;

  @override
  void initState() {
    super.initState();
    // Feature: From is autofilled with the current building/floor/room combo.
    _fromBuilding = widget.building;
    _fromFloor = widget.floor;
    _fromRoom = widget.room;
    _maxQty = widget.item.currentQuantity;
    // Seed the From dropdowns with the current location so the autofilled
    // values render before the full lists stream in (keeps every dropdown
    // value inside its items list).
    _buildings = [widget.building];
    _fromFloors = [widget.floor];
    _fromRooms = [widget.room];
    _loadBuildings();
    _loadInitialFromLocation();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    try {
      final b = await widget.service.watchBuildings().first;
      if (mounted) setState(() => _buildings = b);
    } catch (_) {
      // Buildings are optional; dropdowns simply stay empty on failure.
    }
  }

  /// Preloads the floors and rooms of the autofilled From location so its
  /// dropdowns show the current building/floor/room immediately.
  Future<void> _loadInitialFromLocation() async {
    try {
      final floors = await widget.service
          .watchFloors(widget.building.id!)
          .first;
      if (!mounted) return;
      setState(() => _fromFloors = floors);
      final rooms = await widget.service
          .watchRooms(widget.building.id!, widget.floor.id!)
          .first;
      if (!mounted) return;
      // Apply the exclusion filter too, in case the To side was already
      // picked while the From location was still loading.
      setState(() => _fromRooms = _excludeToRoom(rooms));
    } catch (_) {
      // Ignore load failures; the user can re-pick the location manually.
    }
  }

  // ── From side handlers ───────────────────────────────────────────────────

  Future<void> _onFromBuildingChanged(BuildingModel? b) async {
    setState(() {
      _fromBuilding = b;
      _fromFloor = null;
      _fromRoom = null;
      _fromFloors = [];
      _fromRooms = [];
      _maxQty = 0;
    });
    if (b == null) return;
    final floors = await widget.service.watchFloors(b.id!).first;
    if (mounted && b.id == _fromBuilding?.id) {
      setState(() => _fromFloors = floors);
    }
    _refreshToRooms();
  }

  Future<void> _onFromFloorChanged(FloorModel? f) async {
    setState(() {
      _fromFloor = f;
      _fromRoom = null;
      _fromRooms = [];
      _maxQty = 0;
    });
    if (f == null || _fromBuilding == null) return;
    await _loadRooms(building: _fromBuilding!, floor: f, forFrom: true);
    _refreshToRooms();
  }

  void _onFromRoomChanged(RoomModel? r) {
    setState(() {
      _fromRoom = r;
      _maxQty = 0;
    });
    _syncFromQuantity();
    _refreshToRooms();
  }

  // ── To side handlers ─────────────────────────────────────────────────────

  Future<void> _onToBuildingChanged(BuildingModel? b) async {
    setState(() {
      _toBuilding = b;
      _toFloor = null;
      _toRoom = null;
      _toFloors = [];
      _toRooms = [];
    });
    if (b == null) return;
    final floors = await widget.service.watchFloors(b.id!).first;
    if (mounted && b.id == _toBuilding?.id) {
      setState(() => _toFloors = floors);
    }
    _refreshFromRooms();
  }

  Future<void> _onToFloorChanged(FloorModel? f) async {
    setState(() {
      _toFloor = f;
      _toRoom = null;
      _toRooms = [];
    });
    if (f == null || _toBuilding == null) return;
    await _loadRooms(building: _toBuilding!, floor: f, forFrom: false);
    _refreshFromRooms();
  }

  void _onToRoomChanged(RoomModel? r) {
    setState(() => _toRoom = r);
    _refreshFromRooms();
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  Future<void> _loadRooms({
    required BuildingModel building,
    required FloorModel floor,
    required bool forFrom,
  }) async {
    final buildingId = building.id!;
    final floorId = floor.id!;
    final rooms = await widget.service
        .watchRooms(buildingId, floorId)
        .first;
    if (!mounted) return;
    // Ignore stale responses: only apply if this is still the active
    // selection on that side.
    final isCurrent = forFrom
        ? (_fromBuilding?.id == buildingId && _fromFloor?.id == floorId)
        : (_toBuilding?.id == buildingId && _toFloor?.id == floorId);
    if (!isCurrent) return;
    setState(() {
      final list = forFrom ? _excludeToRoom(rooms) : _excludeFromRoom(rooms);
      if (forFrom) {
        _fromRooms = list;
      } else {
        _toRooms = list;
      }
    });
  }

  /// Rebuilds the To room list so it can never point at the From room when
  /// both sides sit in the same building+floor.
  Future<void> _refreshToRooms() async {
    if (_toBuilding == null || _toFloor == null) return;
    final buildingId = _toBuilding!.id!;
    final floorId = _toFloor!.id!;
    final rooms = await widget.service
        .watchRooms(buildingId, floorId)
        .first;
    if (!mounted) return;
    if (_toBuilding?.id != buildingId || _toFloor?.id != floorId) return;
    setState(() => _toRooms = _excludeFromRoom(rooms));
  }

  /// Rebuilds the From room list so it can never point at the To room when
  /// both sides sit in the same building+floor.
  Future<void> _refreshFromRooms() async {
    if (_fromBuilding == null || _fromFloor == null) return;
    final buildingId = _fromBuilding!.id!;
    final floorId = _fromFloor!.id!;
    final rooms = await widget.service
        .watchRooms(buildingId, floorId)
        .first;
    if (!mounted) return;
    if (_fromBuilding?.id != buildingId || _fromFloor?.id != floorId) return;
    setState(() => _fromRooms = _excludeToRoom(rooms));
  }

  List<RoomModel> _excludeToRoom(List<RoomModel> rooms) {
    final tb = _toBuilding, tf = _toFloor, tr = _toRoom;
    if (tb != null &&
        tf != null &&
        tr != null &&
        _fromBuilding != null &&
        _fromFloor != null &&
        tb.id == _fromBuilding!.id &&
        tf.id == _fromFloor!.id) {
      return rooms.where((r) => r.id != tr.id).toList();
    }
    return rooms;
  }

  List<RoomModel> _excludeFromRoom(List<RoomModel> rooms) {
    final fb = _fromBuilding, ff = _fromFloor, fr = _fromRoom;
    if (fb != null &&
        ff != null &&
        fr != null &&
        _toBuilding != null &&
        _toFloor != null &&
        fb.id == _toBuilding!.id &&
        ff.id == _toFloor!.id) {
      return rooms.where((r) => r.id != fr.id).toList();
    }
    return rooms;
  }

  /// Keeps [_maxQty] in line with the item's actual stock at the selected
  /// From location — the autofilled current room, or a room chosen after
  /// using Reverse.
  Future<void> _syncFromQuantity() async {
    final here = _fromBuilding?.id == widget.building.id &&
        _fromFloor?.id == widget.floor.id &&
        _fromRoom?.id == widget.room.id;
    if (here) {
      if (mounted) setState(() => _maxQty = widget.item.currentQuantity);
      return;
    }
    if (_fromBuilding == null || _fromFloor == null || _fromRoom == null) {
      if (mounted) setState(() => _maxQty = 0);
      return;
    }
    final buildingId = _fromBuilding!.id!;
    final floorId = _fromFloor!.id!;
    final roomId = _fromRoom!.id!;
    try {
      final items = await widget.service
          .watchItems(buildingId, floorId, roomId)
          .first;
      final found = items.where((s) => s.id == widget.item.id).firstOrNull;
      if (!mounted) return;
      if (_fromBuilding?.id != buildingId ||
          _fromFloor?.id != floorId ||
          _fromRoom?.id != roomId) {
        return;
      }
      setState(() => _maxQty = found?.currentQuantity ?? 0);
    } catch (_) {
      if (mounted) setState(() => _maxQty = 0);
    }
  }

  /// Feature: Reverse swaps From and To, so the current combination becomes
  /// the destination and the user picks a different source.
  void _reverse() {
    setState(() {
      final tb = _toBuilding, tf = _toFloor, tr = _toRoom;
      final tfs = _toFloors, trs = _toRooms;
      _toBuilding = _fromBuilding;
      _toFloor = _fromFloor;
      _toRoom = _fromRoom;
      _toFloors = _fromFloors;
      _toRooms = _fromRooms;
      _fromBuilding = tb;
      _fromFloor = tf;
      _fromRoom = tr;
      _fromFloors = tfs;
      _fromRooms = trs;
      _maxQty = 0;
    });
    _syncFromQuantity();
    _refreshToRooms();
    _refreshFromRooms();
  }

  Future<void> _confirm() async {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0 ||
        _maxQty <= 0 ||
        _fromBuilding == null ||
        _fromFloor == null ||
        _fromRoom == null ||
        _toBuilding == null ||
        _toFloor == null ||
        _toRoom == null) {
      return;
    }

    // Safety net: never transfer a room into itself.
    final sameLocation = _fromBuilding!.id == _toBuilding!.id &&
        _fromFloor!.id == _toFloor!.id &&
        _fromRoom!.id == _toRoom!.id;
    if (sameLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From and To cannot be the same room')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.service.transferItem(
        fromBuilding: _fromBuilding!,
        fromFloor: _fromFloor!,
        fromRoom: _fromRoom!,
        toBuilding: _toBuilding!,
        toFloor: _toFloor!,
        toRoom: _toRoom!,
        // Pass a copy carrying the source room's live quantity so the
        // service clamps against the actual stock of the From location.
        item: StockItem(
          id: widget.item.id,
          name: widget.item.name,
          unitPrice: widget.item.unitPrice,
          currentQuantity: _maxQty,
          createdAt: widget.item.createdAt,
          store: widget.item.store,
          bill: widget.item.bill,
          unit: widget.item.unit,
          sourceBillId: widget.item.sourceBillId,
        ),
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
    final canConfirm = _fromRoom != null && _toRoom != null && _maxQty > 0;

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

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Available: $_maxQty',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),

          const SizedBox(height: 16),

          // From block — autofilled with the current location.
          _LocationBlock(
            title: 'From',
            color: Colors.blue,
            buildings: _buildings,
            building: _fromBuilding,
            floors: _fromFloors,
            floor: _fromFloor,
            rooms: _fromRooms,
            room: _fromRoom,
            onBuildingChanged: _onFromBuildingChanged,
            onFloorChanged: _onFromFloorChanged,
            onRoomChanged: _onFromRoomChanged,
          ),

          // Reverse control — swaps From and To.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: OutlinedButton.icon(
                  onPressed: _reverse,
                  icon: const Icon(Icons.swap_vert, size: 18),
                  label: const Text('Reverse'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade300),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ]),
          ),

          // To block — the destination.
          _LocationBlock(
            title: 'To',
            color: Colors.green,
            buildings: _buildings,
            building: _toBuilding,
            floors: _toFloors,
            floor: _toFloor,
            rooms: _toRooms,
            room: _toRoom,
            onBuildingChanged: _onToBuildingChanged,
            onFloorChanged: _onToFloorChanged,
            onRoomChanged: _onToRoomChanged,
          ),

          const SizedBox(height: 16),

          // Quantity
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly
            ],
            decoration: InputDecoration(
              labelText: 'Quantity to Transfer',
              helperText: 'Max: $_maxQty',
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

          // Cancel + Confirm
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (_saving || !canConfirm) ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
        ]),
      ),
    );
  }
}

/// A From/To location picker used inside the transfer sheet: cascading
/// building → floor → room dropdowns with a coloured header.
class _LocationBlock extends StatelessWidget {
  final String title;
  final Color color;
  final List<BuildingModel> buildings;
  final BuildingModel? building;
  final List<FloorModel> floors;
  final FloorModel? floor;
  final List<RoomModel> rooms;
  final RoomModel? room;
  final ValueChanged<BuildingModel?> onBuildingChanged;
  final ValueChanged<FloorModel?> onFloorChanged;
  final ValueChanged<RoomModel?> onRoomChanged;

  const _LocationBlock({
    required this.title,
    required this.color,
    required this.buildings,
    required this.building,
    required this.floors,
    required this.floor,
    required this.rooms,
    required this.room,
    required this.onBuildingChanged,
    required this.onFloorChanged,
    required this.onRoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.arrow_right_alt, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: color)),
        ]),
        const SizedBox(height: 10),
        _dropdown<BuildingModel>(
          label: 'Building',
          value: building,
          hint: 'Select building',
          enabled: true,
          items: buildings
              .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
              .toList(),
          // Match by id: the autofilled From values come from the sheet's
          // widget (different instances than the streamed lists), and the
          // lists are replaced with fresh instances on every load.
          same: (a, b) => a.id == b.id,
          onChanged: onBuildingChanged,
        ),
        const SizedBox(height: 10),
        _dropdown<FloorModel>(
          label: 'Floor',
          value: floor,
          hint: 'Select floor',
          enabled: building != null,
          items: floors
              .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
              .toList(),
          same: (a, b) => a.id == b.id,
          onChanged: onFloorChanged,
        ),
        const SizedBox(height: 10),
        _dropdown<RoomModel>(
          label: 'Room',
          value: room,
          hint: 'Select room',
          enabled: floor != null,
          items: rooms
              .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
              .toList(),
          same: (a, b) => a.id == b.id,
          onChanged: onRoomChanged,
        ),
      ]),
    );
  }

  /// A controlled dropdown styled like a form field. `DropdownButtonFormField`
  /// is not used because its `value` is deprecated and its `initialValue`
  /// would not track programmatic changes (cascading resets, Reverse).
  ///
  /// A `DropdownButton` asserts that its `value` is an item it is given, so
  /// we resolve the requested [value] to the actual item instance that
  /// matches via [same] (identity for these models, so [same] compares ids).
  /// While the matching item is absent — a list still streaming in, or a
  /// cascade reset — the dropdown shows its hint instead of asserting.
  Widget _dropdown<T>({
    required String label,
    required T? value,
    required String hint,
    required bool enabled,
    required List<DropdownMenuItem<T>> items,
    required bool Function(T a, T b) same,
    required ValueChanged<T?> onChanged,
  }) {
    T? selected;
    if (value != null) {
      for (final i in items) {
        final itemValue = i.value;
        if (itemValue != null && same(itemValue, value)) {
          selected = itemValue;
          break;
        }
      }
    }
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selected,
          isExpanded: true,
          isDense: true,
          hint: Text(hint,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
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
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;

  const _ItemFormDialog({
    this.initial,
    required this.onSave,
    required this.building,
    required this.floor,
    required this.room,
  });
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
    // _nameCtrl is reassigned to Autocomplete's controller in fieldViewBuilder;
    // Autocomplete owns its lifecycle, so we must not dispose it.
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _storeNameCtrl.dispose();
    _billCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final store = _storeNameCtrl.text.trim();
    final bill = _billCtrl.text.trim();

    // If a catalog item was selected that already exists in this room,
    // adjust the existing item's quantity by the difference (the qty field
    // holds the new absolute quantity when editing).
    if (_selectedCatalogItem != null) {
      final existing = items.where(
          (i) => i.id == _selectedCatalogItem!.id).firstOrNull;
      if (existing != null) {
        // In edit mode the qty field holds the new absolute quantity;
        // in add mode it is the amount to add on top of what's already there.
        final delta = widget.initial != null
            ? qty - existing.currentQuantity
            : qty;
        if (delta == 0) {
          setState(() => _saving = false);
          if (mounted) Navigator.pop(context);
          return;
        }
        await _service.adjustQuantity(
          buildingId: widget.building.id!,
          floorId: widget.floor.id!,
          roomId: widget.room.id!,
          item: existing,
          delta: delta,
          note: '',
          buildingName: widget.building.name,
          floorName: widget.floor.name,
          roomName: widget.room.name,
          unitPrice: price,
          store: store,
          bill: bill,
        );
        if (mounted) Navigator.pop(context);
        return;
      }
    }

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
                textEditingValue.text.toLowerCase());
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
    final isPhoto = log.type == 'photo';
    final isInspection = log.type == 'inspection';
    final isIncrease = log.type == 'increase';
    final color = isPhoto
        ? Colors.indigo.shade600
        : isInspection
            ? const Color(0xFF1A3C6E)
            : isIncrease
                ? Colors.green.shade700
                : Colors.red.shade600;

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
              isPhoto
                  ? Icons.photo_camera_outlined
                  : isInspection
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
                Text(log.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                if (isPhoto)
                  Row(children: [
                    LogPhotoThumb(url: log.oldPhotoUrl ?? ''),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward,
                          size: 14, color: Colors.grey),
                    ),
                    LogPhotoThumb(url: log.newPhotoUrl ?? ''),
                  ])
                else if (isInspection)
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
        if (!isInspection && !isPhoto) ...[
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
              onTap: () async {
                final synced = await service.syncInspectionChecklist(
                  buildingId: building.id!,
                  floorId: floor.id!,
                  roomId: room.id!,
                  inspection: inProgress.first,
                );
                if (context.mounted) {
                  _openInspection(context, synced);
                }
              },
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

  /// Photo URLs of the catalog items on the checklist (catalog id → url).
  final Map<String, String> _catalogPhotos = {};

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
    _loadCatalogPhotos();
  }

  Future<void> _loadCatalogPhotos() async {
    try {
      final summaries = await widget.service.getCatalogItemSummaries();
      if (!mounted) return;
      setState(() {
        _catalogPhotos
          ..clear()
          ..addEntries(summaries
              .where((c) =>
              c.id != null && (c.photoUrl?.isNotEmpty ?? false))
              .map((c) => MapEntry(c.id!, c.photoUrl!)));
      });
    } catch (_) {
      // Photos are optional; keep the add-photo button if they fail to load.
    }
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

  /// Opens the stock transfer sheet for a mismatched checklist item. The live
  /// item is fetched from the room so the sheet shows the current quantity.
  Future<void> _transferMismatchedItem(int i) async {
    final entry = _items[i];
    if (entry.itemId.isEmpty) return;

    final all = await widget.service
        .watchItems(widget.building.id!, widget.floor.id!, widget.room.id!)
        .first;
    final stockItem = all.where((s) => s.id == entry.itemId).firstOrNull;
    if (stockItem == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item not found in this room')),
        );
      }
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TransferSheet(
        building: widget.building,
        floor: widget.floor,
        room: widget.room,
        item: stockItem,
        service: widget.service,
      ),
    );
  }

  /// Picks and uploads a photo for the catalog item of a mismatched checklist
  /// item (same flow as the item card's Add Photo action).
  Future<void> _addItemPhoto(int i) async {
    final entry = _items[i];
    if (entry.itemId.isEmpty) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;

    try {
      final url = await widget.service.uploadCatalogItemPhoto(
        xfile: file,
        catalogItemId: entry.itemId,
      );
      if (url != null) {
        await widget.service.updateCatalogItemPhoto(entry.itemId, url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Photo added for ${entry.itemName}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')),
        );
      }
    }
  }

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
                        // Feature: Item photos - photo slot on the left for
                        // every checklist item (add-photo when missing).
                        ItemPhotoButton(
                          service: widget.service,
                          catalogItemId: item.itemId,
                          photoUrl: _catalogPhotos[item.itemId],
                          size: 38,
                          borderRadius: 6,
                          itemName: item.itemName,
                          onPhotoUploaded: (url) =>
                              setState(() => _catalogPhotos[item.itemId] = url),
                        ),
                        const SizedBox(width: 8),
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
                        // Feature: Inspection actions - transfer stock out or
                        // attach an item photo while resolving a mismatch.
                        const SizedBox(height: 10),
                        Row(children: [
                          OutlinedButton.icon(
                            onPressed:
                                _saving ? null : () => _transferMismatchedItem(i),
                            icon: const Icon(Icons.swap_horiz_outlined,
                                size: 16),
                            label: const Text('Transfer'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              side: BorderSide(color: Colors.blue.shade200),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed:
                                _saving ? null : () => _addItemPhoto(i),
                            icon: const Icon(Icons.camera_alt_outlined,
                                size: 16),
                            label: const Text('Add Photo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal.shade700,
                              side: BorderSide(color: Colors.teal.shade200),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ]),
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
