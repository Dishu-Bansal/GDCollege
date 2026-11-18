import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

import '../models/receipt_model.dart';
import '../models/receipt_print_text.dart';

/// Printable fee receipt: letterhead, serial + verification code, student
/// block, fee-head breakup, total with amount in words, payment mode, a QR
/// encoding the public verify URL, and a received-by stamp.
Future<List<int>> buildReceiptPdf(ReceiptModel r) async {
  final doc = pw.Document();
  final verifyUrl = verifyUrlFor(r.code);
  const navy = PdfColors.blue900;
  const green = PdfColors.green800;

  String fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Letterhead ──
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('LALA KUNDAN LAL MEMORIAL SOCIETY',
                    style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: navy)),
                pw.SizedBox(height: 2),
                pw.Text('FEE RECEIPT — ${r.college.toUpperCase()}',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: green)),
              ],
            ),
          ),
          pw.Divider(thickness: 2, color: navy),
          pw.SizedBox(height: 6),

          // ── Serial row ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Receipt No: ${r.receiptNumber}',
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text('Verification Code: ${r.code}',
                      style: pw.TextStyle(fontSize: 11)),
                ],
              ),
              pw.Text('Date: ${fmtDate(r.createdAt)}',
                  style: pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.SizedBox(height: 10),

          // ── Student block ──
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Received from', r.studentName),
                _kv('Roll No.',
                    r.rollNo.isEmpty ? '—' : r.rollNo),
                _kv('Session (admission year)',
                    r.admissionYear > 0 ? '${r.admissionYear}' : '—'),
                _kv('Father Name',
                    r.fatherName.isEmpty ? '—' : r.fatherName),
                _kv('Aadhaar No.',
                    r.aadharNumber.isEmpty ? '—' : r.aadharNumber),
                _kv('Course', r.course.isEmpty ? '—' : r.course),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // ── Breakup ──
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Fee Head', bold: true),
                  _cell('Amount (Rs.)', bold: true, right: true),
                ],
              ),
              for (final a in r.allocations)
                pw.TableRow(
                  children: [
                    _cell(a.type),
                    _cell(a.amount.toStringAsFixed(0), right: true),
                  ],
                ),
              pw.TableRow(
                children: [
                  _cell('TOTAL', bold: true),
                  _cell('Rs. ${r.amount.toStringAsFixed(0)}',
                      bold: true, right: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text('In words: ${amountInWords(r.amount)}',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontStyle: pw.FontStyle.italic,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Payment Mode: ${r.mode.isEmpty ? '—' : r.mode}',
              style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 14),

          // ── QR + stamp ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 110,
                    height: 110,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: verifyUrl,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Scan to verify this receipt',
                      style: pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600)),
                  pw.Text(verifyUrl,
                      style: pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (r.createdBy.isNotEmpty)
                    pw.Text('Received by: ${r.createdBy}',
                        style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 28),
                  pw.Text('Authorised Signatory',
                      style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.Center(
            child: pw.Text(
              'Computer-generated receipt. Verify authenticity at the link above. '
              'Cancelled receipts are not valid proof of payment.',
              textAlign: pw.TextAlign.center,
              style:
                  pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _kv(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 170,
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 11, color: PdfColors.grey700)),
        ),
        pw.Expanded(
          child: pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    ),
  );
}

pw.Widget _cell(String text, {bool bold = false, bool right = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

/// Sends the receipt straight to the print dialog.
Future<void> printReceipt(ReceiptModel receipt) async {
  final bytes = await buildReceiptPdf(receipt);
  await Printing.layoutPdf(
    onLayout: (_) async => Uint8List.fromList(bytes),
    name: 'Receipt-${receipt.receiptNumber.replaceAll('/', '-')}',
  );
}
