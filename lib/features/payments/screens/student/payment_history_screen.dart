// lib/features/payments/screens/student/payment_history_screen.dart

import 'package:flutter/material.dart';
import '../../../../core/api/api_service.dart';
import '../../../../models/payment.dart';
import '../../repositories/payments_repository.dart';
import 'payment_receipt_screen.dart';

const _kCancelReasons = [
  'Changed my mind',
  'Selected the wrong package',
  'Payment method issue',
  'Found a better option',
  'Ordered by mistake',
  'Other',
];

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final _repo = PaymentsRepository();
  bool _loading = true;
  String? _error;
  List<PaymentModel> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _payments = await _repo.getMyPayments();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load purchase history.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestRefund(PaymentModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request a refund?'),
        content: Text(
            "We'll flag this ₱${p.amountDisplay.toStringAsFixed(2)} top-up "
            "for our team to review. You'll keep your credits until they "
            "process it."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Request Refund')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final updated = await _repo.requestRefund(p.id);
      if (!mounted) return;
      setState(() {
        final i = _payments.indexWhere((x) => x.id == p.id);
        if (i != -1) _payments[i] = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Refund requested — our team will review it.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _cancelPayment(PaymentModel p) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _CancelReasonSheet(payment: p),
    );
    if (reason == null || reason.trim().isEmpty) return;

    try {
      final updated = await _repo.cancelPayment(id: p.id, reason: reason);
      if (!mounted) return;
      setState(() {
        final i = _payments.indexWhere((x) => x.id == p.id);
        if (i != -1) _payments[i] = updated;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request cancelled.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Color _statusColor(PaymentStatus s, ColorScheme cs) => switch (s) {
        PaymentStatus.succeeded => const Color(0xFF00C48C),
        PaymentStatus.pending => const Color(0xFFE0A800),
        PaymentStatus.failed => cs.error,
        PaymentStatus.refunded => cs.onSurfaceVariant,
        PaymentStatus.cancelled => cs.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase History · 购买记录')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _payments.isEmpty
                    ? Center(
                        child: Text('No purchases yet · 暂无购买记录',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          itemCount: _payments.length,
                          itemBuilder: (_, i) {
                            final p = _payments[i];
                            final canRequestRefund =
                                p.status == PaymentStatus.succeeded &&
                                    p.refundRequestedAt == null;
                            final canCancel = p.status == PaymentStatus.pending;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(color: cs.outlineVariant),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PaymentReceiptScreen(payment: p),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  p.packageName ??
                                                      '${p.creditsAmount ?? '—'} credits',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: cs.onSurface)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${p.currency} ${p.amountDisplay.toStringAsFixed(2)}'
                                                '${p.paymentMethod != null ? ' · ${p.paymentMethod}' : ''}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: cs.onSurfaceVariant),
                                              ),
                                              Text(
                                                '${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: cs.onSurfaceVariant),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(p.status, cs)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            p.status.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _statusColor(p.status, cs),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.chevron_right_rounded,
                                            size: 18,
                                            color: cs.onSurfaceVariant),
                                      ],
                                    ),
                                  ),
                                  if (p.refundRequestedAt != null) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                        'Refund requested — awaiting review',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFE0A800))),
                                  ],
                                  if (p.status == PaymentStatus.cancelled &&
                                      p.cancelReason != null) ...[
                                    const SizedBox(height: 8),
                                    Text('Cancelled: ${p.cancelReason}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurfaceVariant)),
                                  ],
                                  if (canRequestRefund || canCancel) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (canCancel) ...[
                                          OutlinedButton(
                                            onPressed: () => _cancelPayment(p),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: cs.error,
                                              side: BorderSide(
                                                  color: cs.error
                                                      .withValues(alpha: 0.4)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                            ),
                                            child: const Text('Cancel',
                                                style: TextStyle(fontSize: 12)),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (canRequestRefund)
                                          OutlinedButton(
                                            onPressed: () => _requestRefund(p),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                            ),
                                            child: const Text('Request Refund',
                                                style: TextStyle(fontSize: 12)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}

/// Shopee-style cancel flow: pick a preset reason (or "Other" + free text),
/// returned via Navigator.pop(context, reason) for the caller to submit.
class _CancelReasonSheet extends StatefulWidget {
  final PaymentModel payment;
  const _CancelReasonSheet({required this.payment});

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String? _selected;
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_selected == null) return false;
    if (_selected == 'Other') return _otherController.text.trim().isNotEmpty;
    return true;
  }

  void _submit() {
    final reason =
        _selected == 'Other' ? _otherController.text.trim() : _selected!;
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text('Cancel ₱${p.amountDisplay.toStringAsFixed(2)} request?',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text("Let us know why — this helps us improve.",
              style: TextStyle(fontSize: 12.5)),
          const SizedBox(height: 12),
          ..._kCancelReasons.map((reason) => RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: reason,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                title: Text(reason, style: const TextStyle(fontSize: 13.5)),
              )),
          if (_selected == 'Other') ...[
            const SizedBox(height: 4),
            TextField(
              controller: _otherController,
              maxLength: 200,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Tell us more',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep Request'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Cancel Request'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
