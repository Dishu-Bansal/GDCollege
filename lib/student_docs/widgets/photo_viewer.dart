import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Full-size photo viewer opened by tapping any collector/doc thumbnail.
/// Pinch-zoomable; tap outside or the close button to dismiss.
Future<void> showPhotoViewer(
  BuildContext context, {
  Uint8List? bytes,
  String? url,
  required String title,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: InteractiveViewer(
                child: bytes != null
                    ? Image.memory(bytes, fit: BoxFit.contain)
                    : Image.network(url ?? '', fit: BoxFit.contain),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Small labeled thumbnail used for old-vs-new previews in log rows.
/// Tapping opens the full-size viewer.
class MiniThumb extends StatelessWidget {
  final String label;
  final String? url;

  const MiniThumb({super.key, required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final u = url ?? '';
    if (u.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Text(
                '—',
                style:
                    TextStyle(color: Colors.grey.shade400, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      );
    }
    final isPdf = u.toLowerCase().endsWith('.pdf');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => showPhotoViewer(context, url: u, title: label),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: isPdf
                ? const Icon(Icons.picture_as_pdf_outlined,
                    size: 28, color: Colors.redAccent)
                : Image.network(u, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style:
                TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}
