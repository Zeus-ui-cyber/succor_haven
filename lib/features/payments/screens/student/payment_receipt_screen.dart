// lib/features/payments/screens/student/payment_receipt_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../models/payment.dart';
import '../../../../models/credit_package.dart';
import 'buy_credits_screen.dart' show paymentMethodLabel;

class _C {
  static const magenta = Color(0xFFD64577);
  static const burgundy = Color(0xFF7D002B);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const green = Color(0xFF00C48C);
  static const greenPale = Color(0xFFDCF7EE);
  static const amber = Color(0xFFB8860B);
  static const amberPale = Color(0xFFFFF3CD);
  static const red = Color(0xFFD64545);
  static const redPale = Color(0xFFFBDCDC);
}

/// Shown right after a student submits a top-up request, and reopenable
/// from Purchase History for any past payment. `package` is only passed
/// on the just-submitted path as a fallback for credits/name in case the
/// server response's join fields are ever sparse — payments coming from
/// history already carry packageName/creditsAmount directly.
class PaymentReceiptScreen extends StatelessWidget {
  final PaymentModel payment;
  final CreditPackageModel? package;
  // True only right after ReviewOrderScreen submits — swaps the back arrow
  // for a "Done" button that returns to the Buy Credits root. False when
  // reopened from Purchase History, where a normal back arrow applies
  // regardless of the payment's status.
  final bool justSubmitted;
  const PaymentReceiptScreen({
    super.key,
    required this.payment,
    this.package,
    this.justSubmitted = false,
  });

  (Color, Color, String) _statusStyle(PaymentStatus s) => switch (s) {
        PaymentStatus.succeeded => (_C.green, _C.greenPale, 'Succeeded'),
        PaymentStatus.failed => (_C.red, _C.redPale, 'Failed'),
        PaymentStatus.refunded => (_C.inkSoft, _C.paper, 'Refunded'),
        PaymentStatus.cancelled => (_C.inkSoft, _C.line, 'Cancelled'),
        PaymentStatus.pending => (_C.amber, _C.amberPale, 'Pending'),
      };

  Future<Uint8List> _buildPdfBytes(
      String packageName, int? creditsAmount, String statusLabel) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Succor Haven',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('Credit Top-Up Receipt',
                  style: pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 8),
              _pdfRow(
                  'Reference', '#${payment.id.substring(0, 8).toUpperCase()}'),
              _pdfRow('Date',
                  '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year}'),
              _pdfRow('Package', packageName),
              if (creditsAmount != null) _pdfRow('Credits', '$creditsAmount'),
              _pdfRow(
                  'Payment Method', paymentMethodLabel(payment.paymentMethod)),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              _pdfRow('Amount', '₱${payment.amountDisplay.toStringAsFixed(2)}',
                  bold: true),
              _pdfRow('Status', statusLabel, bold: true),
              if (payment.status == PaymentStatus.cancelled &&
                  payment.cancelReason != null)
                _pdfRow('Cancelled Reason', payment.cancelReason!),
              pw.SizedBox(height: 32),
              pw.Text('Thank you for your purchase.',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: bold ? 12 : 11,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: bold ? 13 : 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context, String packageName,
      int? creditsAmount, String statusLabel) async {
    try {
      final bytes =
          await _buildPdfBytes(packageName, creditsAmount, statusLabel);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'receipt_${payment.id.substring(0, 8)}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not generate PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, pale, label) = _statusStyle(payment.status);
    final packageName = payment.packageName ?? package?.name ?? 'Credit top-up';
    final creditsAmount = payment.creditsAmount ?? package?.creditsAmount;

    return Scaffold(
      backgroundColor: _C.cream,
      appBar: AppBar(
        backgroundColor: _C.cream,
        elevation: 0,
        foregroundColor: _C.ink,
        automaticallyImplyLeading: !justSubmitted,
        title: const Text('Receipt · 收据',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            if (justSubmitted) ...[
              Center(
                child: Column(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                        color: _C.greenPale, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        color: _C.green, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text('Request Submitted',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.ink)),
                  const SizedBox(height: 6),
                  const Text(
                    "We'll notify you once your payment is verified.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: _C.inkSoft),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
            ],
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: _C.paper,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _C.line)),
              child: Column(children: [
                _ReceiptRow('Reference',
                    '#${payment.id.substring(0, 8).toUpperCase()}'),
                const SizedBox(height: 10),
                _ReceiptRow('Date',
                    '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year}'),
                const SizedBox(height: 10),
                _ReceiptRow('Package', packageName),
                if (creditsAmount != null) ...[
                  const SizedBox(height: 10),
                  _ReceiptRow('Credits', '$creditsAmount'),
                ],
                const SizedBox(height: 10),
                _ReceiptRow('Payment Method',
                    paymentMethodLabel(payment.paymentMethod)),
                const SizedBox(height: 12),
                const Divider(color: _C.line, height: 1),
                const SizedBox(height: 12),
                _ReceiptRow(
                    'Amount', '₱${payment.amountDisplay.toStringAsFixed(2)}',
                    bold: true),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: pale, borderRadius: BorderRadius.circular(20)),
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                if (payment.refundRequestedAt != null) ...[
                  const SizedBox(height: 10),
                  const Text('Refund requested — awaiting admin review',
                      style: TextStyle(
                          fontSize: 11,
                          color: _C.amber,
                          fontWeight: FontWeight.w700)),
                ],
                if (payment.status == PaymentStatus.cancelled &&
                    payment.cancelReason != null) ...[
                  const SizedBox(height: 10),
                  Text('Cancelled: ${payment.cancelReason}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _downloadPdf(context, packageName, creditsAmount, label),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download PDF Receipt'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.burgundy,
                  side: const BorderSide(color: _C.line, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (justSubmitted)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).popUntil(
                      (route) => route.settings.name == '/buy-credits'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _C.magenta,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _ReceiptRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              fontSize: bold ? 14 : 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold ? _C.ink : _C.inkSoft)),
      const Spacer(),
      Text(value,
          textAlign: TextAlign.right,
          style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: FontWeight.w800,
              color: bold ? _C.burgundy : _C.ink)),
    ]);
  }
}
