import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/pagination_controller.dart';
import '../repositories/student_repository.dart';

class PaginationBar extends StatefulWidget {
  final PaginationController controller;

  const PaginationBar({super.key, required this.controller});

  @override
  State<PaginationBar> createState() => _PaginationBarState();
}

class _PaginationBarState extends State<PaginationBar> {
  final TextEditingController _input = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final page = int.tryParse(_input.text);
    if (page != null) widget.controller.jumpTo(page);
    setState(() => _editing = false);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final isNarrow = MediaQuery.of(context).size.width < 480;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Record range â€” hide on narrow screens
          if (!isNarrow) ...[
            Text(
              _rangeLabel(ctrl),
              style:
              TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(width: 16),
          ],

          // First
          _NavBtn(
            icon: Icons.first_page,
            tooltip: 'First page',
            enabled: ctrl.hasPrev && !ctrl.isLoading,
            onTap: ctrl.first,
          ),
          // Prev
          _NavBtn(
            icon: Icons.chevron_left,
            tooltip: 'Previous',
            enabled: ctrl.hasPrev && !ctrl.isLoading,
            onTap: ctrl.prev,
          ),

          const SizedBox(width: 6),

          // Current page â€” tap to type a page number
          _editing
              ? SizedBox(
            width: 60,
            height: 32,
            child: TextField(
              controller: _input,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly
              ],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                      color: Color(0xFF1A3C6E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                      color: Color(0xFF1A3C6E), width: 2),
                ),
              ),
              onSubmitted: (_) => _submit(),
              onTapOutside: (_) =>
                  setState(() => _editing = false),
            ),
          )
              : Tooltip(
            message: 'Tap to jump to a page',
            child: GestureDetector(
              onTap: () => setState(() {
                _editing = true;
                _input.text = ctrl.currentPage.toString();
                _input.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _input.text.length,
                );
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3C6E),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${ctrl.currentPage}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),
          Text('of ${ctrl.totalPages}',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(width: 6),

          // Next
          _NavBtn(
            icon: Icons.chevron_right,
            tooltip: 'Next',
            enabled: ctrl.hasNext && !ctrl.isLoading,
            onTap: ctrl.next,
          ),
          // Last
          _NavBtn(
            icon: Icons.last_page,
            tooltip: 'Last page',
            enabled: ctrl.hasNext && !ctrl.isLoading,
            onTap: ctrl.last,
          ),

          // Inline spinner
          if (ctrl.isLoading) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                AlwaysStoppedAnimation(Color(0xFF1A3C6E)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _rangeLabel(PaginationController ctrl) {
    if (ctrl.totalCount == 0) return 'No records';
    final start =
        (ctrl.currentPage - 1) * StudentRepository.pageSize + 1;
    final end = (start + ctrl.students.length - 1)
        .clamp(start, ctrl.totalCount);
    final label = ctrl.isSearchMode ? 'results' : 'students';
    return '$startâ€“$end of ${ctrl.totalCount} $label';
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _NavBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? const Color(0xFF1A3C6E)
                : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
