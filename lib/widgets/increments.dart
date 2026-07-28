import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single increment entry
class IncrementEntry {
  DateTime? date;
  String amount;

  IncrementEntry({this.date, this.amount = ''});
}

/// Drop-in widget for the Increments section inside your Salary card.
/// Usage:
///   IncrementsList(
///     entries: _increments,
///     onChanged: (updated) => setState(() => _increments = updated),
///   )
class IncrementsList extends StatefulWidget {
  final List<IncrementEntry> entries;
  final void Function(List<IncrementEntry> updated) onChanged;

  const IncrementsList({
    super.key,
    required this.entries,
    required this.onChanged,
  });

  @override
  State<IncrementsList> createState() => _IncrementsListState();
}

class _IncrementsListState extends State<IncrementsList> {
  // Keep one TextEditingController per row so text doesn't reset on rebuild
  final List<TextEditingController> _amountControllers = [];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  void _syncControllers() {
    // Add controllers for any new entries
    while (_amountControllers.length < widget.entries.length) {
      final idx = _amountControllers.length;
      _amountControllers.add(
        TextEditingController(text: widget.entries[idx].amount),
      );
    }
    // Remove controllers for deleted entries
    while (_amountControllers.length > widget.entries.length) {
      _amountControllers.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final c in _amountControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    final updated = [...widget.entries, IncrementEntry()];
    _amountControllers.add(TextEditingController());
    widget.onChanged(updated);
  }

  void _removeEntry(int index) {
    final updated = [...widget.entries]..removeAt(index);
    _amountControllers.removeAt(index).dispose();
    widget.onChanged(updated);
  }

  Future<void> _pickDate(int index) async {
    final current = widget.entries[index].date;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1A3C6E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final updated = [...widget.entries];
      updated[index] = IncrementEntry(
        date: picked,
        amount: updated[index].amount,
      );
      widget.onChanged(updated);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    _syncControllers();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label row
          Row(
            children: [
              const Text(
                'Increments',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              // + Add button — same style as your MultiFilePicker
              OutlinedButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A3C6E),
                  side: const BorderSide(color: Color(0xFF1A3C6E)),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Empty state
          if (widget.entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border:
                Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'No increments added yet',
                  style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ),
            )
          else
          // Column header
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 5,
                    child: Text('Date',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Text('Amount (₹)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500)),
                  ),
                  const SizedBox(width: 32), // space for delete icon
                ],
              ),
            ),

          // Entry rows
          ...List.generate(widget.entries.length, (i) {
            final entry = widget.entries[i];
            return _IncrementRow(
              index: i,
              entry: entry,
              amountController: _amountControllers[i],
              onPickDate: () => _pickDate(i),
              onAmountChanged: (v) {
                final updated = [...widget.entries];
                updated[i] =
                    IncrementEntry(date: updated[i].date, amount: v);
                widget.onChanged(updated);
              },
              onDelete: () => _removeEntry(i),
              formatDate: _formatDate,
            );
          }),

          // Summary chip — only visible when there are entries
          if (widget.entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            _IncrementSummary(entries: widget.entries),
          ],
        ],
      ),
    );
  }
}

// ── Single row ────────────────────────────────────────────────────────────────

class _IncrementRow extends StatelessWidget {
  final int index;
  final IncrementEntry entry;
  final TextEditingController amountController;
  final VoidCallback onPickDate;
  final void Function(String) onAmountChanged;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;

  const _IncrementRow({
    required this.index,
    required this.entry,
    required this.amountController,
    required this.onPickDate,
    required this.onAmountChanged,
    required this.onDelete,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3C6E).withValues(alpha: 0.04),
        border: Border.all(color: const Color(0xFF1A3C6E).withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // ── Date picker ───────────────────────────────────────────
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: entry.date != null
                        ? const Color(0xFF1A3C6E).withValues(alpha: 0.4)
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: entry.date != null
                          ? const Color(0xFF1A3C6E)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        entry.date != null
                            ? formatDate(entry.date!)
                            : 'Pick date',
                        style: TextStyle(
                          fontSize: 12,
                          color: entry.date != null
                              ? const Color(0xFF1A3C6E)
                              : Colors.grey.shade400,
                          fontWeight: entry.date != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Amount field ──────────────────────────────────────────
          Expanded(
            flex: 5,
            child: TextField(
              controller: amountController,
              onChanged: onAmountChanged,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                    color: Colors.grey.shade400, fontSize: 12),
                prefixText: '₹ ',
                prefixStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A3C6E),
                    fontWeight: FontWeight.w600),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                      color: Color(0xFF1A3C6E), width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // ── Delete button ─────────────────────────────────────────
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Colors.redAccent),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

// ── Summary chip ──────────────────────────────────────────────────────────────

class _IncrementSummary extends StatelessWidget {
  final List<IncrementEntry> entries;
  const _IncrementSummary({required this.entries});

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(
      0,
          (sum, e) => sum + (double.tryParse(e.amount) ?? 0),
    );
    final filled = entries.where((e) => e.date != null && e.amount.isNotEmpty);

    return Row(
      children: [
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3C6E).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${filled.length} increment${filled.length == 1 ? '' : 's'}  •  Total ₹${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A3C6E),
            ),
          ),
        ),
      ],
    );
  }
}