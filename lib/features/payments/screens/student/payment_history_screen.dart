// lib/features/payments/screens/student/payment_history_screen.dart

import 'package:flutter/material.dart';
import '../../../../core/api/api_service.dart';
import '../../../../models/payment.dart';
import '../../repositories/payments_repository.dart';

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

  Color _statusColor(PaymentStatus s, ColorScheme cs) => switch (s) {
        PaymentStatus.succeeded => const Color(0xFF00C48C),
        PaymentStatus.pending => const Color(0xFFE0A800),
        PaymentStatus.failed => cs.error,
        PaymentStatus.refunded => cs.onSurfaceVariant,
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
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(color: cs.outlineVariant),
                                borderRadius: BorderRadius.circular(14),
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
                                                fontWeight: FontWeight.w700,
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
                                      borderRadius: BorderRadius.circular(20),
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
