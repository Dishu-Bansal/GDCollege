import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../widgets/stock_widgets.dart';
import '../models/stock_models.dart';

/// "Catalog" tab of Stock Management.
///
/// Shows every unique item from `itemsCatalog` with its current total
/// quantity, the Building › Floor › Room breakdown of where it is stocked,
/// and its recent price-history (item) log.
class ItemCatalogTab extends ConsumerStatefulWidget {
  const ItemCatalogTab({super.key});

  @override
  ConsumerState<ItemCatalogTab> createState() => _ItemCatalogTabState();
}

class _ItemCatalogTabState extends ConsumerState<ItemCatalogTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;
  List<CatalogItem> _catalog = [];
  Map<String, List<ItemLocationStock>> _locations = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(stockRepositoryProvider);
      final (catalog, locations) = await (
        service.getCatalogItemSummaries(),
        service.fetchItemLocationStock(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _locations = locations;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _onItemPhotoUploaded(String itemId, String url) {
    if (!mounted) return;
    setState(() {
      final i = _catalog.indexWhere((c) => c.id == itemId);
      if (i != -1) _catalog[i].photoUrl = url;
    });
  }

  List<CatalogItem> get _filtered {
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? List<CatalogItem>.from(_catalog)
        : _catalog
            .where((c) => c.name.toLowerCase().contains(q))
            .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search items…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ]),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading && _catalog.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _catalog.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Unable to load catalog.\n$_error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_catalog.isEmpty ? 'No items in the catalog yet.'
              : 'No items match "$_query".',
              style: TextStyle(color: Colors.grey.shade500)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
      itemCount: items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _CatalogItemCard(
          item: items[i],
          locations: _locations[items[i].id] ?? const [],
          onPhotoUploaded: (url) =>
              _onItemPhotoUploaded(items[i].id ?? '', url),
        ),
      ),
    );
  }
}

// ── Item card ─────────────────────────────────────────────────────────────────

class _CatalogItemCard extends ConsumerWidget {
  final CatalogItem item;
  final List<ItemLocationStock> locations;
  final ValueChanged<String>? onPhotoUploaded;

  const _CatalogItemCard({
    required this.item,
    required this.locations,
    this.onPhotoUploaded,
  });

  void _openBreakdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _BreakdownSheet(item: item, locations: locations),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = this.item;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        // Item picture (or add-photo button when missing)
        ItemPhotoButton(
          service: ref.read(stockRepositoryProvider),
          catalogItemId: item.id ?? '',
          photoUrl: item.photoUrl,
          size: 48,
          onPhotoUploaded: onPhotoUploaded,
        ),
        const SizedBox(width: 12),
        // Name, quantity, price
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text('Qty: ${item.totalQuantity} · ${_money(item.lastPrice)}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Breakdown button
        OutlinedButton.icon(
          onPressed: () => _openBreakdown(context),
          icon: const Icon(Icons.table_rows_outlined, size: 16),
          label: const Text('Breakdown'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: const Color(0xFF1A3C6E)),
            foregroundColor: const Color(0xFF1A3C6E),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      ]),
    );
  }
}

// ── Breakdown bottom sheet ────────────────────────────────────────────────────

class _BreakdownSheet extends ConsumerStatefulWidget {
  final CatalogItem item;
  final List<ItemLocationStock> locations;

  const _BreakdownSheet({required this.item, required this.locations});

  @override
  ConsumerState<_BreakdownSheet> createState() => _BreakdownSheetState();
}

class _BreakdownSheetState extends ConsumerState<_BreakdownSheet> {
  late final Future<List<ItemPriceLog>> _logFuture;

  @override
  void initState() {
    super.initState();
    _logFuture = _loadLog();
  }

  Future<List<ItemPriceLog>> _loadLog() async {
    final id = widget.item.id;
    if (id == null) return const [];
    try {
      return await ref
          .read(stockRepositoryProvider)
          .fetchItemPriceHistory(id, limit: 50);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final locations = widget.locations;
    final roomTotal = locations.fold(0, (sum, l) => sum + l.quantity);
    final mismatch = item.totalQuantity != roomTotal;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Expanded(
                child: Text(item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Text('Total: ${item.totalQuantity}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A3C6E))),
            ]),
          ),
          if (mismatch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Note: room quantities sum to $roomTotal, which differs '
                  'from the catalog total.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.orange.shade800,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ),
          const Divider(height: 16),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                // ── Room-wise breakdown ──
                _sectionTitle('Room-wise breakdown'),
                const SizedBox(height: 6),
                if (locations.isEmpty)
                  Text('Not currently in any room.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500))
                else
                  for (final loc in locations)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Icon(Icons.location_on_outlined,
                            size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${loc.buildingName} › ${loc.floorName} › ${loc.roomName}',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                        Text('${loc.quantity}',
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                const SizedBox(height: 20),
                // ── Item logs ──
                _sectionTitle('Item logs'),
                const SizedBox(height: 6),
                FutureBuilder<List<ItemPriceLog>>(
                  future: _logFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF1A3C6E)),
                          ),
                        ),
                      );
                    }
                    final logs = snap.data ?? const [];
                    if (logs.isEmpty) {
                      return Text('No log entries yet.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade500));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final log in logs)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    log.type == 'decrease'
                                        ? Icons.remove_circle_outline
                                        : Icons.add_circle_outline,
                                    size: 16,
                                    color: log.type == 'decrease'
                                        ? Colors.red.shade600
                                        : Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_logLine(log),
                                        style:
                                            const TextStyle(fontSize: 13)),
                                  ),
                                ]),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade600,
            letterSpacing: 0.3),
      );

  String _logLine(ItemPriceLog log) {
    final date = '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year}';
    final sign = log.type == 'decrease' ? '-' : '+';
    final parts = [
      date,
      '$sign${log.quantity}',
      if (log.price > 0) '@ ${_money(log.price)}',
      if (log.store.isNotEmpty) log.store,
      if (log.bill.isNotEmpty) 'Bill ${log.bill}',
    ];
    return parts.join(' · ');
  }
}

String _money(double v) => '₹ ${v.toStringAsFixed(2)}';
