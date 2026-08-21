import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers.dart';
import '../../stock_management/models/stock_models.dart';
import '../models/bill_models.dart';

class BillFormScreen extends ConsumerStatefulWidget {
  final BillModel? existingBill;
  const BillFormScreen({super.key, this.existingBill});

  @override
  ConsumerState<BillFormScreen> createState() => _BillFormScreenState();
}

class _ItemEditData {
  TextEditingController qtyCtrl;
  TextEditingController priceCtrl;
  TextEditingController? nameCtrl;
  String unit;
  CatalogItem? selected;
  String name;

  _ItemEditData({this.name = ''})
    : qtyCtrl = TextEditingController(text: '1'),
      priceCtrl = TextEditingController(),
      unit = 'Pieces';

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _BillFormScreenState extends ConsumerState<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _billNumberCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _paymentByCtrl = TextEditingController();
  final _reimbursedByCtrl = TextEditingController();

  late DateTime _billDate;
  DateTime? _paymentDate;
  DateTime? _reimbursementDate;
  bool _reimbursementRequired = false;
  bool _saving = false;

  final List<_ItemEditData> _items = [];
  List<CatalogItem> _catalogSummaries = [];

  Uint8List? _photoBytes;
  String? _photoName;
  bool _removeExistingPhoto = false;

  bool get _isEdit => widget.existingBill != null;

  @override
  void initState() {
    super.initState();
    final bill = widget.existingBill;
    _billDate = bill?.billDate ?? DateTime.now();
    _paymentDate = bill?.paymentDate;
    _reimbursementDate = bill?.reimbursementDate;
    _reimbursementRequired = bill?.reimbursementRequired ?? false;
    if (bill != null) {
      _billNumberCtrl.text = bill.billNumber;
      _storeNameCtrl.text = bill.storeName;
      _paymentByCtrl.text = bill.paymentBy;
      _reimbursedByCtrl.text = bill.reimbursedBy;
      for (final i in bill.items) {
        _items.add(
          _ItemEditData(name: i.name)
            ..qtyCtrl.text = '${i.quantity}'
            ..priceCtrl.text = i.pricePerUnit == 0
                ? ''
                : i.pricePerUnit.toStringAsFixed(2)
            ..unit = i.unit
            ..selected = i.catalogItemId != null
                ? CatalogItem(id: i.catalogItemId, name: i.name)
                : null,
        );
      }
    }
    if (_items.isEmpty) {
      _items.add(_ItemEditData());
    }
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final names = await ref
          .read(stockRepositoryProvider)
          .getCatalogItemSummaries();
      if (mounted) setState(() => _catalogSummaries = names);
    } catch (_) {
      // Autocomplete still works with free text if the catalog is unavailable.
    }
  }

  @override
  void dispose() {
    _billNumberCtrl.dispose();
    _storeNameCtrl.dispose();
    _paymentByCtrl.dispose();
    _reimbursedByCtrl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBillDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate ?? _billDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _pickReimbursementDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reimbursementDate ?? _paymentDate ?? _billDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _reimbursementDate = picked);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    final XFile? img = action == 'camera'
        ? await picker.pickImage(source: ImageSource.camera, imageQuality: 80)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) {
      final bytes = await img.readAsBytes();
      if (mounted) {
        setState(() {
          _photoBytes = bytes;
          _photoName = img.name;
          _removeExistingPhoto = false;
        });
      }
    }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  /// Running total of the items currently entered in the form.
  double get _liveTotal {
    var total = 0.0;
    for (final d in _items) {
      final qty = int.tryParse(d.qtyCtrl.text) ?? 0;
      final price = double.tryParse(d.priceCtrl.text) ?? 0;
      total += qty * price;
    }
    return total;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final items = <BillItem>[];
    for (final d in _items) {
      final name = (d.nameCtrl?.text ?? d.name).trim();
      final qty = int.tryParse(d.qtyCtrl.text) ?? 0;
      final price = double.tryParse(d.priceCtrl.text) ?? 0;
      if (name.isEmpty || qty <= 0 || price <= 0) continue;
      items.add(
        BillItem(
          name: name,
          quantity: qty,
          pricePerUnit: price,
          unit: d.unit,
          catalogItemId: d.selected?.id,
        ),
      );
    }

    if (items.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one item with name, quantity and price.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final paymentBy = _paymentByCtrl.text.trim();
    final reimbursedBy = _reimbursedByCtrl.text.trim();

    // Reimbursement only makes sense when the original payment is recorded.
    if (_reimbursementRequired && (_paymentDate == null || paymentBy.isEmpty)) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reimbursement requires the payment date and paid by to be '
            'filled first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // A bill is paid when it needs no reimbursement and the original payment
    // is recorded, or when it needs reimbursement and both the payment and
    // the reimbursement details are recorded. A bill already settled stays
    // settled when re-edited.
    final hasReimbursement =
        _reimbursementDate != null && reimbursedBy.isNotEmpty;
    final paid =
        (_isEdit && (widget.existingBill?.paid ?? false)) ||
        (!_reimbursementRequired && paymentBy.isNotEmpty) ||
        (_reimbursementRequired && hasReimbursement);
    final paymentDate =
        _paymentDate ??
        ((paid && !_reimbursementRequired) ? DateTime.now() : null);

    final bill = BillModel(
      id: widget.existingBill?.id,
      billNumber: _billNumberCtrl.text.trim(),
      storeName: _storeNameCtrl.text.trim(),
      billDate: _billDate,
      paymentDate: paymentDate,
      paymentBy: paymentBy,
      reimbursementDate: _reimbursementDate,
      reimbursedBy: reimbursedBy,
      reimbursementRequired: _reimbursementRequired,
      paid: paid,
      photoUrl: widget.existingBill?.photoUrl,
      items: items,
      createdAt: widget.existingBill?.createdAt,
      createdBy: widget.existingBill?.createdBy ?? '',
    );

    try {
      final repo = ref.read(billRepositoryProvider);
      if (_isEdit) {
        await repo.updateBill(
          bill,
          photoBytes: _photoBytes,
          photoName: _photoName,
          removePhoto: _removeExistingPhoto,
        );
      } else {
        await repo.createBill(
          bill,
          photoBytes: _photoBytes,
          photoName: _photoName,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Bill' : 'Add Bill',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCard([
              _buildField(
                _billNumberCtrl,
                'Bill Number *',
                hint: 'e.g. INV-2026-014',
              ),
              _buildField(_storeNameCtrl, 'Store Name *'),
              _buildDateTile(
                'Bill Date *',
                _fmtDate(_billDate),
                _pickBillDate,
                Icons.event,
              ),
              _buildDateTile(
                _reimbursementRequired ? 'Payment Date *' : 'Payment Date',
                _paymentDate == null ? 'Not set' : _fmtDate(_paymentDate!),
                _pickPaymentDate,
                Icons.payments_outlined,
                error: _reimbursementRequired && _paymentDate == null
                    ? 'Required for reimbursement'
                    : null,
              ),
              _buildField(
                _paymentByCtrl,
                'Payment By',
                hint: 'Name of the person / source',
                required: _reimbursementRequired,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Reimbursement required',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: _reimbursementRequired
                    ? null
                    : const Text(
                        'Bill needs to be reimbursed after payment',
                        style: TextStyle(fontSize: 12),
                      ),
                value: _reimbursementRequired,
                onChanged: (v) =>
                    setState(() => _reimbursementRequired = v ?? false),
              ),
              if (_reimbursementRequired) ...[
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildDateTile(
                  'Reimbursement Date',
                  _reimbursementDate == null
                      ? 'Not set'
                      : _fmtDate(_reimbursementDate!),
                  _pickReimbursementDate,
                  Icons.receipt_long_outlined,
                ),
                _buildField(
                  _reimbursedByCtrl,
                  'Reimbursed By',
                  hint: 'Who reimbursed this bill',
                  required: false,
                  onChanged: (_) => setState(() {}),
                ),
                if (_reimbursementDate != null &&
                    _reimbursedByCtrl.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'This bill will be marked as paid.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
              ],
            ]),
            const SizedBox(height: 16),
            _sectionCard([
              Row(
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF1A3C6E),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _items.add(_ItemEditData())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3C6E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Total: ₹ ${_liveTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF1A3C6E),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _items.length; i++) ...[
                _BillItemRow(
                  index: i,
                  data: _items[i],
                  catalogSummaries: _catalogSummaries,
                  canRemove: _items.length > 1,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() {
                    _items[i].dispose();
                    _items.removeAt(i);
                  }),
                ),
                if (i != _items.length - 1) const SizedBox(height: 10),
              ],
            ]),
            const SizedBox(height: 16),
            _sectionCard([
              Text(
                'Bill Photo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              if (_photoBytes != null)
                _photoPreview(
                  Image.memory(
                    _photoBytes!,
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                  onRemove: () => setState(() {
                    _photoBytes = null;
                    _photoName = null;
                  }),
                )
              else if (_isEdit &&
                  widget.existingBill?.photoUrl != null &&
                  !_removeExistingPhoto)
                _photoPreview(
                  Image.network(
                    widget.existingBill!.photoUrl!,
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                  onRemove: () => setState(() => _removeExistingPhoto = true),
                  onReplace: _pickImage,
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add Bill Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A3C6E),
                    side: const BorderSide(color: Color(0xFF1A3C6E)),
                  ),
                ),
            ]),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A3C6E),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _saving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Add Bill'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool required = true,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: required ? label : '$label (optional)',
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _buildDateTile(
    String label,
    String value,
    VoidCallback onTap,
    IconData icon, {
    String? error,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: error,
            errorMaxLines: 2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: Icon(icon, size: 20),
          ),
          child: Text(value),
        ),
      ),
    );
  }

  Widget _photoPreview(
    Widget image, {
    VoidCallback? onRemove,
    VoidCallback? onReplace,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
        const SizedBox(height: 8),
        Row(
          children: [
            if (onReplace != null)
              TextButton.icon(
                onPressed: onReplace,
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('Replace'),
              ),
            if (onRemove != null)
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Bill item row ──────────────────────────────────────────────────────────────

class _BillItemRow extends StatefulWidget {
  final int index;
  final _ItemEditData data;
  final List<CatalogItem> catalogSummaries;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _BillItemRow({
    required this.index,
    required this.data,
    required this.catalogSummaries,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_BillItemRow> createState() => _BillItemRowState();
}

class _BillItemRowState extends State<_BillItemRow> {
  @override
  void initState() {
    super.initState();
    // Prefill the Autocomplete-owned controller once it is attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.data.nameCtrl != null &&
          widget.data.nameCtrl!.text.isEmpty &&
          widget.data.name.isNotEmpty) {
        widget.data.nameCtrl!.text = widget.data.name;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Item ${widget.index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              if (widget.canRemove)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.redAccent,
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          Autocomplete<CatalogItem>(
            displayStringForOption: (option) => option.name,
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<CatalogItem>.empty();
              }
              final q = textEditingValue.text.toLowerCase();
              return widget.catalogSummaries.where(
                (o) => o.name.toLowerCase().contains(q),
              );
            },
            onSelected: (selection) {
              setState(() {
                widget.data.selected = selection;
                widget.data.name = selection.name;
              });
              widget.onChanged();
            },
            fieldViewBuilder:
                (context, textEditingController, focusNode, onFieldSubmitted) {
                  widget.data.nameCtrl = textEditingController;
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Item Name *',
                      hintText: 'Type to search or enter new name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (text) {
                      if (widget.data.selected != null &&
                          text != widget.data.selected!.name) {
                        setState(() => widget.data.selected = null);
                      }
                      widget.onChanged();
                    },
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  );
                },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.data.qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Qty *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (v) {
                    final q = int.tryParse(v ?? '');
                    return (q == null || q <= 0) ? 'Invalid' : null;
                  },
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: widget.data.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Price/unit *',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (v) {
                    final p = double.tryParse(v ?? '');
                    return (p == null || p <= 0) ? 'Invalid' : null;
                  },
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: widget.data.unit,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: stockUnits
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => widget.data.unit = v);
                      widget.onChanged();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
