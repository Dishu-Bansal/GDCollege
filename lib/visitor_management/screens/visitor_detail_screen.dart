import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../widgets/stock_widgets.dart';
import '../models/visitor_models.dart';
import '../repositories/visitor_repository.dart';

/// Detail screen for a unique visitor: their profile summary plus every one
/// of their visits.
class VisitorDetailScreen extends StatelessWidget {
  final VisitorModel visitor;
  final VisitorRepository service;

  const VisitorDetailScreen({
    super.key,
    required this.visitor,
    required this.service,
  });

  String _initial(String name) =>
      name.isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(visitor.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Profile header
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: avatarColor(visitor.name),
              child: Text(
                _initial(visitor.name),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visitor.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 3),
                    Text(
                      '${visitor.visitCount} '
                      'visit${visitor.visitCount == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                    if (visitor.firstVisitAt != null)
                      Text(
                        'First visit: ${_fmtDateTime(visitor.firstVisitAt!)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    if (visitor.lastVisitAt != null)
                      Text(
                        'Last visit: ${_fmtDateTime(visitor.lastVisitAt!)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                  ]),
            ),
          ]),
        ),
        const Divider(height: 1),

        // Visit history
        Expanded(
          child: StreamBuilder<List<VisitorVisitModel>>(
            stream: service.watchVisitorVisits(visitor.id!),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: Text('Failed to load visits: ${snap.error}'));
              }
              final visits = snap.data ?? [];
              if (snap.connectionState == ConnectionState.waiting &&
                  visits.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (visits.isEmpty) {
                return const StockEmptyState(
                    message: 'No visits recorded for this visitor yet.');
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: visits.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _VisitCard(visit: visits[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// A single visit record for the visitor detail screen.
class _VisitCard extends StatelessWidget {
  final VisitorVisitModel visit;

  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            visit.isInside ? Icons.login : Icons.logout,
            size: 16,
            color: visit.isInside ? Colors.green.shade700 : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            visit.isInside ? 'Inside' : 'Checked out',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: visit.isInside
                    ? Colors.green.shade700
                    : Colors.grey.shade600),
          ),
          const Spacer(),
          Text(
            _fmt(visit.checkInAt),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('In:  ${_fmtFull(visit.checkInAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ]),
        if (visit.checkOutAt != null)
          Text('Out: ${_fmtFull(visit.checkOutAt!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        if (visit.purpose.isNotEmpty ||
            visit.vehicleNumber.isNotEmpty ||
            visit.fromPlace.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (visit.purpose.isNotEmpty)
              _InfoItem(Icons.info_outline, visit.purpose),
            if (visit.vehicleNumber.isNotEmpty)
              _InfoItem(Icons.directions_car_outlined, visit.vehicleNumber),
            if (visit.fromPlace.isNotEmpty)
              _InfoItem(Icons.place_outlined, visit.fromPlace),
          ]),
        ],
        if (visit.accompanyingPeople.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('With: ${visit.accompanyingPeople.join(', ')}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtFull(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      Text(text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
    ]);
  }
}
