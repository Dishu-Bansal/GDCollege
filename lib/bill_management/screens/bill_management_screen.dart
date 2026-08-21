import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../widgets/drawer.dart';
import '../models/bill_models.dart';
import 'bill_form_screen.dart';

class BillManagementScreen extends ConsumerStatefulWidget {
  const BillManagementScreen({super.key});

  @override
  ConsumerState<BillManagementScreen> createState() =>
      _BillManagementScreenState();
}

class _BillManagementScreenState extends ConsumerState<BillManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BillFormScreen()),
    );
  }

  void _openEdit(BillModel bill) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BillFormScreen(existingBill: bill)),
    );
  }

  Future<void> _confirmMarkPaid(BillModel bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.payments, color: Color(0xFF2E7D32), size: 24),
          SizedBox(width: 8),
          Text('Mark as Paid'),
        ]),
        content: Text(
            'Confirm that bill #${bill.billNumber} has been paid/reimbursed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(billRepositoryProvider).markBillPaid(bill.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill marked as paid.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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
      drawer: getSideDrawer(context),
      appBar: AppBar(
        title: const Text('Bill Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Bills'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _BillsTab(
            onEdit: _openEdit,
            onMarkPaid: _confirmMarkPaid,
          ),
          const _BillLogsTab(),
        ],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openAdd,
              backgroundColor: const Color(0xFF1A3C6E),
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: const Text('Add Bill',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}

// ── Bills tab ─────────────────────────────────────────────────────────────────

class _BillsTab extends ConsumerWidget {
  final void Function(BillModel) onEdit;
  final void Function(BillModel) onMarkPaid;

  const _BillsTab({required this.onEdit, required this.onMarkPaid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsStreamProvider);
    return bills.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Unable to load bills.\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
          ]),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No bills yet',
            subtitle: 'Tap "Add Bill" to record your first purchase.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _BillCard(
            bill: list[i],
            onEdit: () => onEdit(list[i]),
            onMarkPaid: () => onMarkPaid(list[i]),
          ),
        );
      },
    );
  }
}

class _BillCard extends StatelessWidget {
  final BillModel bill;
  final VoidCallback onEdit;
  final VoidCallback onMarkPaid;

  const _BillCard({
    required this.bill,
    required this.onEdit,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final pending = bill.isPaymentPending;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pending ? Colors.orange.shade300 : Colors.grey.shade200,
          width: pending ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text('Bill #${bill.billNumber}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            Text(_money(bill.totalAmount),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1A3C6E))),
          ]),
          const SizedBox(height: 8),
          _infoRow(Icons.storefront_outlined, 'Store: ${bill.storeName}'),
          _infoRow(Icons.event_outlined,
              'Bill Date: ${_fmtDate(bill.billDate)}'),
          if (bill.paid && bill.paymentDate != null)
            _infoRow(
                Icons.check_circle_outline,
                'Paid on ${_fmtDate(bill.paymentDate!)}'
                    '${bill.paymentBy.isNotEmpty ? ' by ${bill.paymentBy}' : ''}',
                color: const Color(0xFF2E7D32)),
          if (pending)
            _infoRow(Icons.pending_actions,
                'Payment Pending',
                color: Colors.orange.shade800),
          const SizedBox(height: 8),
          if (bill.photoUrl != null && bill.photoUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                bill.photoUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (bill.items.isNotEmpty) ...[
            for (final item in bill.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${item.quantity} × ${item.name} '
                  '(${item.unit}) — ${_money(item.total)}',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade800),
                ),
              ),
            const SizedBox(height: 6),
            Text('Total: ${_money(bill.totalAmount)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            if (pending)
              OutlinedButton.icon(
                onPressed: onMarkPaid,
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: const Text('Mark as Paid'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('PAID',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700)),
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 15, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color: color ?? Colors.grey.shade800)),
        ),
      ]),
    );
  }
}

// ── Logs tab ──────────────────────────────────────────────────────────────────

class _BillLogsTab extends ConsumerWidget {
  const _BillLogsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(billLogsStreamProvider);
    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Unable to load logs.\n$e',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState(
            icon: Icons.history,
            title: 'No activity yet',
            subtitle: 'Bill creation, updates and payments will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _BillLogTile(log: list[i]),
        );
      },
    );
  }
}

class _BillLogTile extends StatelessWidget {
  final BillLog log;
  const _BillLogTile({required this.log});

  (IconData, Color, String) get _meta {
    switch (log.action) {
      case 'create':
        return (Icons.add_circle_outline, Colors.green.shade700, 'Created');
      case 'pay':
        return (Icons.payments_outlined, Colors.teal.shade700, 'Marked Paid');
      default:
        return (Icons.edit_outlined, Colors.blue.shade700, 'Updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _meta;
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    'Bill #${log.billNumber.isEmpty ? '—' : log.billNumber}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
              ]),
              const SizedBox(height: 3),
              if (log.detail.isNotEmpty)
                Text(log.detail,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87)),
              if (log.changedBy.isNotEmpty)
                Text(log.changedBy,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 1),
              Text(_fmtDateTime(log.timestamp),
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ]),
      ),
    );
  }
}

String _money(double v) => '₹ ${v.toStringAsFixed(2)}';

String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _fmtDateTime(DateTime d) {
  final date = '${d.day}/${d.month}/${d.year}';
  final time =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '$date  $time';
}
