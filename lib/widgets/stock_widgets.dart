import 'package:flutter/material.dart';
import '../stock_management/models/stock_models.dart';

// ── Quick name dialog (add / rename) ─────────────────────────────────────────

Future<String?> showNameDialog(
    BuildContext context, {
      required String title,
      String? initial,
      String hint = 'Enter name',
    }) async {
  final ctrl = TextEditingController(text: initial ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xFF1A3C6E))),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: hint,
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: Color(0xFF1A3C6E), width: 2),
          ),
        ),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
        },
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              Navigator.pop(context, ctrl.text.trim());
            }
          },
          child: Text(initial != null ? 'Save' : 'Add'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}

// ── Confirm delete dialog ─────────────────────────────────────────────────────

Future<bool> confirmDelete(
    BuildContext context, {
      required String label,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
        SizedBox(width: 8),
        Text('Delete'),
      ]),
      content: Text(
          'Delete "$label"? This will remove all data inside it and cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ── Section header ────────────────────────────────────────────────────────────

class StockSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StockSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3C6E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF1A3C6E)),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF1A3C6E))),
      const Spacer(),
      if (onAction != null)
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add, size: 16),
          label: Text(actionLabel ?? 'Add',
              style: const TextStyle(fontSize: 13)),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1A3C6E),
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
        ),
    ]);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class StockEmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StockEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style:
              TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          if (onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel ?? 'Add'),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Inspection Due Badge ───────────────────────────────────────────────────────
// Feature: Inspection Tracking — shown on room/floor/building cards when a room
// has not been inspected in the last 14 days (or never).

class InspectionDueBadge extends StatelessWidget {
  const InspectionDueBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Icon(Icons.warning_amber_rounded,
          color: Colors.white, size: 11),
    );
  }
}

// ── Inspection status line ─────────────────────────────────────────────────────
// Feature: Inspection Tracking - shows a room's last inspection date. The text
// is normal when the room was inspected within 14 days and red when the
// inspection is due or the room was never inspected.

class InspectionStatusLine extends StatelessWidget {
  final RoomModel room;
  final bool includeRoomName;
  final String? floorName;

  const InspectionStatusLine({
    super.key,
    required this.room,
    this.includeRoomName = false,
    this.floorName,
  });

  @override
  Widget build(BuildContext context) {
    final d = room.lastInspectedAt;
    final dateText = d == null
        ? 'Never inspected'
        : 'Last inspected ${d.day}/${d.month}/${d.year}';
    final parts = [
      if (floorName != null && floorName!.isNotEmpty) floorName!,
      if (includeRoomName) room.name,
      dateText,
    ];
    return Text(
      parts.join('  ·  '),
      style: TextStyle(
        fontSize: 11,
        color: room.isInspectionDue ? Colors.red : Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ── Expandable inspection-due list ─────────────────────────────────────────────
// Feature: Inspection Tracking - compact list of rooms whose inspection is due
// or that were never inspected. Shows a count header that expands to reveal the
// full room-wise list (room name + last inspection date). Short lists (<3
// rooms) start expanded; longer lists start collapsed so cards stay compact.

class InspectionDueList extends StatefulWidget {
  /// Rooms paired with their floor name (empty string when on a single floor).
  final List<(RoomModel, String)> dueRooms;

  const InspectionDueList({super.key, required this.dueRooms});

  @override
  State<InspectionDueList> createState() => _InspectionDueListState();
}

class _InspectionDueListState extends State<InspectionDueList> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.dueRooms.length <= 2;
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.dueRooms;
    if (rooms.isEmpty) return const SizedBox.shrink();

    final count = rooms.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Inspection due for $count room${count == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 2),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final (room, floorName) in rooms)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: InspectionStatusLine(
                  room: room,
                  includeRoomName: true,
                  floorName: floorName),
            ),
      ],
    );
  }
}