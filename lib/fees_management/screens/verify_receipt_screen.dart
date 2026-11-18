import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/receipt_model.dart';
import '../services/firebase_fees_service.dart';

/// Public receipt verification: no login required. Enter (or scan into)
/// the 12-digit code and the live receipt row is shown — or a clear
/// not-found verdict for anything forged.
class VerifyReceiptScreen extends StatefulWidget {
  final String initialCode;

  const VerifyReceiptScreen({super.key, this.initialCode = ''});

  @override
  State<VerifyReceiptScreen> createState() => _VerifyReceiptScreenState();
}

class _VerifyReceiptScreenState extends State<VerifyReceiptScreen> {
  final _service = FirebaseFeesService();
  late final TextEditingController _codeCtrl;
  bool _checking = false;
  bool _checked = false;
  ReceiptModel? _receipt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.initialCode);
    if (widget.initialCode.trim().length == 12) _verify();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  String get _code => _codeCtrl.text.trim();

  bool get _codeValid => RegExp(r'^\d{12}$').hasMatch(_code);

  Future<void> _verify() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final receipt = await _service.fetchReceiptByCode(_code);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _checked = true;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not verify right now: $e';
        _checked = false;
        _checking = false;
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Verify Fee Receipt',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              const Text(
                'Lala Kundan Lal Memorial Society',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1A3C6E)),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter the 12-digit verification code printed on the receipt.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onSubmitted: (_) {
                        if (_codeValid) _verify();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                        prefixIcon: Icon(Icons.qr_code_2_outlined),
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed:
                        (_codeValid && !_checking) ? _verify : null,
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Verify'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ],
              if (_checked && !_checking) ...[
                const SizedBox(height: 16),
                if (_receipt == null)
                  _verdict(
                    color: const Color(0xFFC62828),
                    icon: Icons.cancel_outlined,
                    title: 'No receipt found',
                    body:
                        'No fee receipt exists for code $_code. A receipt with this code was never issued by the college.',
                  )
                else if (_receipt!.status != 'active')
                  _verdict(
                    color: const Color(0xFFEF6C00),
                    icon: Icons.warning_amber_outlined,
                    title: 'Receipt cancelled',
                    body:
                        'This receipt was issued but later CANCELLED. It is not a valid proof of payment.',
                    receipt: _receipt,
                  )
                else
                  _verdict(
                    color: const Color(0xFF2E7D32),
                    icon: Icons.check_circle_outline,
                    title: 'Genuine receipt',
                    body:
                        'This receipt was issued by the college and is valid.',
                    receipt: _receipt,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _verdict({
    required Color color,
    required IconData icon,
    required String title,
    required String body,
    ReceiptModel? receipt,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13)),
          if (receipt != null) ...[
            const SizedBox(height: 14),
            _row('Receipt no.', receipt.receiptNumber),
            _row('Student', receipt.studentName),
            _row('Roll no.', receipt.rollNo.isEmpty ? '—' : receipt.rollNo),
            _row('Session (admission year)',
                receipt.admissionYear > 0 ? '${receipt.admissionYear}' : '—'),
            _row('Father name',
                receipt.fatherName.isEmpty ? '—' : receipt.fatherName),
            _row('Aadhaar no.',
                receipt.aadharNumber.isEmpty ? '—' : receipt.aadharNumber),
            _row('Amount paid', '₹${receipt.amount.toStringAsFixed(0)}'),
            _row('Payment method',
                receipt.mode.isEmpty ? '—' : receipt.mode),
            _row('Paid on', _fmtDate(receipt.createdAt)),
            _row('College',
                receipt.college.isEmpty ? '—' : receipt.college),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
