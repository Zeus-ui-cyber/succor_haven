// lib/features/payments/screens/student/buy_credits_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/payments_controller.dart';
import '../../../../models/credit_package.dart';
import '../../../../models/payment.dart';
import 'payment_receipt_screen.dart';

class _C {
  static const magenta = Color(0xFFD64577);
  static const burgundy = Color(0xFF7D002B);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
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

// Payment methods the backend accepts (payments.payment_method CHECK
// constraint). No gateway integration yet — picking one just tags the
// request; the student still sends payment manually and an admin confirms
// it from the Payments tab.
const kPaymentMethods = [
  ('gcash', 'GCash', Icons.phone_iphone_rounded),
  ('maya', 'Maya', Icons.account_balance_wallet_rounded),
  ('card', 'Card', Icons.credit_card_rounded),
  ('alipay', 'Alipay', Icons.payment_rounded),
  ('wechat', 'WeChat Pay', Icons.chat_bubble_rounded),
];

String paymentMethodLabel(String? method) => kPaymentMethods
    .firstWhere((m) => m.$1 == method, orElse: () => ('', method ?? '—', Icons.payment_rounded))
    .$2;

// ══════════════════════════════════════════════════════════════════════════
// STEP 1 — Buy Credits home: pick a package, see purchase history
// ══════════════════════════════════════════════════════════════════════════
class BuyCreditsScreen extends ConsumerStatefulWidget {
  const BuyCreditsScreen({super.key});

  @override
  ConsumerState<BuyCreditsScreen> createState() => _BuyCreditsScreenState();
}

class _BuyCreditsScreenState extends ConsumerState<BuyCreditsScreen> {
  CreditPackageModel? _selected;

  Future<void> _continue() async {
    final selected = _selected;
    if (selected == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectPaymentMethodScreen(package: selected),
      ),
    );
    if (!mounted) return;
    ref.invalidate(myPaymentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(creditPackagesProvider);
    final paymentsAsync = ref.watch(myPaymentsProvider);

    return Scaffold(
      backgroundColor: _C.cream,
      appBar: AppBar(
        backgroundColor: _C.cream,
        elevation: 0,
        foregroundColor: _C.ink,
        title: const Text('Buy Credits · 购买积分',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: _C.magenta,
        onRefresh: () async {
          ref.invalidate(creditPackagesProvider);
          ref.invalidate(myPaymentsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text('Choose a package',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
            const SizedBox(height: 2),
            const Text('· 选择套餐',
                style: TextStyle(fontSize: 12, color: _C.magenta)),
            const SizedBox(height: 14),
            packagesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child:
                    Center(child: CircularProgressIndicator(color: _C.magenta)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Could not load packages: $e',
                    style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
              ),
              data: (packages) {
                final active = packages.where((p) => p.isActive).toList()
                  ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
                if (active.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No packages available right now.',
                        style: TextStyle(fontSize: 12, color: _C.inkSoft)),
                  );
                }
                return Column(
                  children: active
                      .map((p) => _SelectablePackageCard(
                            package: p,
                            selected: _selected?.id == p.id,
                            onTap: () => setState(() => _selected = p),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 28),
            const Text('Payment history',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
            const SizedBox(height: 2),
            const Text('· 付款记录',
                style: TextStyle(fontSize: 12, color: _C.magenta)),
            const SizedBox(height: 14),
            paymentsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child:
                    Center(child: CircularProgressIndicator(color: _C.magenta)),
              ),
              error: (e, _) => Text('$e',
                  style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
              data: (payments) {
                if (payments.isEmpty) {
                  return const Text('No payments yet.',
                      style: TextStyle(fontSize: 12, color: _C.inkSoft));
                }
                return Column(
                  children: payments
                      .map((p) => _PaymentTile(
                            payment: p,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PaymentReceiptScreen(payment: p),
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _selected == null ? null : _continue,
            style: FilledButton.styleFrom(
              backgroundColor: _C.magenta,
              disabledBackgroundColor: _C.line,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _selected == null
                  ? 'Select a package'
                  : 'Continue · ₱${_selected!.priceDisplay.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectablePackageCard extends StatelessWidget {
  final CreditPackageModel package;
  final bool selected;
  final VoidCallback onTap;
  const _SelectablePackageCard(
      {required this.package, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _C.softPink : _C.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? _C.magenta : _C.line,
              width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: _C.blushPink, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.diamond_outlined, color: _C.magenta),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(package.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _C.ink)),
                const SizedBox(height: 2),
                Text('${package.creditsAmount} credits',
                    style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
              ],
            ),
          ),
          Text('₱${package.priceDisplay.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: _C.burgundy)),
          const SizedBox(width: 12),
          _RadioDot(selected: selected),
        ]),
      ),
    );
  }
}

/// Shared selectable-option radio indicator — an outlined circle, filled
/// with a check when selected. Used for both package and payment-method
/// selection so the two steps read as one consistent picker pattern.
class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _C.magenta : Colors.transparent,
        border: Border.all(color: selected ? _C.magenta : _C.line, width: 1.6),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentModel payment;
  final VoidCallback onTap;
  const _PaymentTile({required this.payment, required this.onTap});

  (Color, Color, String) _statusStyle(PaymentStatus s) => switch (s) {
        PaymentStatus.succeeded => (_C.green, _C.greenPale, 'Succeeded'),
        PaymentStatus.failed => (_C.red, _C.redPale, 'Failed'),
        PaymentStatus.refunded => (_C.inkSoft, _C.softPink, 'Refunded'),
        PaymentStatus.cancelled => (_C.inkSoft, _C.line, 'Cancelled'),
        PaymentStatus.pending => (_C.amber, _C.amberPale, 'Pending'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, pale, label) = _statusStyle(payment.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _C.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.line)),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.packageName ?? 'Credit top-up',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.ink)),
                const SizedBox(height: 2),
                Text(
                    '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year}'
                    '${payment.creditsAmount != null ? ' · ${payment.creditsAmount} credits' : ''}',
                    style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
              ],
            ),
          ),
          Text('₱${payment.amountDisplay.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _C.ink)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: pale, borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 18, color: _C.inkSoft),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// STEP 2 — Select payment method
// ══════════════════════════════════════════════════════════════════════════
class SelectPaymentMethodScreen extends StatefulWidget {
  final CreditPackageModel package;
  const SelectPaymentMethodScreen({super.key, required this.package});

  @override
  State<SelectPaymentMethodScreen> createState() =>
      _SelectPaymentMethodScreenState();
}

class _SelectPaymentMethodScreenState
    extends State<SelectPaymentMethodScreen> {
  String? _method;

  Future<void> _continue() async {
    final method = _method;
    if (method == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewOrderScreen(
          package: widget.package,
          paymentMethod: method,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    return Scaffold(
      backgroundColor: _C.cream,
      appBar: AppBar(
        backgroundColor: _C.cream,
        elevation: 0,
        foregroundColor: _C.ink,
        title: const Text('Payment Method',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: _C.softPink, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.diamond_outlined, color: _C.magenta),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select how you\'ll pay ₱${package.priceDisplay.toStringAsFixed(0)} '
                  'for ${package.name} (${package.creditsAmount} credits)',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _C.ink),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          ...kPaymentMethods.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _method = m.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _method == m.$1 ? _C.softPink : _C.paper,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _method == m.$1 ? _C.magenta : _C.line,
                          width: _method == m.$1 ? 1.6 : 1),
                    ),
                    child: Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: _C.blushPink,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(m.$3, color: _C.magenta, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(m.$2,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _C.ink)),
                      ),
                      _RadioDot(selected: _method == m.$1),
                    ]),
                  ),
                ),
              )),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _method == null ? null : _continue,
            style: FilledButton.styleFrom(
              backgroundColor: _C.magenta,
              disabledBackgroundColor: _C.line,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Continue',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// STEP 3 — Review your order
// ══════════════════════════════════════════════════════════════════════════
class ReviewOrderScreen extends ConsumerStatefulWidget {
  final CreditPackageModel package;
  final String paymentMethod;
  const ReviewOrderScreen(
      {super.key, required this.package, required this.paymentMethod});

  @override
  ConsumerState<ReviewOrderScreen> createState() => _ReviewOrderScreenState();
}

class _ReviewOrderScreenState extends ConsumerState<ReviewOrderScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final payment = await ref.read(paymentsRepositoryProvider).requestPayment(
            creditPackageId: widget.package.id,
            paymentMethod: widget.paymentMethod,
          );
      ref.invalidate(myPaymentsProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              PaymentReceiptScreen(
                  payment: payment, package: widget.package, justSubmitted: true),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not submit request: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    final methodLabel = paymentMethodLabel(widget.paymentMethod);

    return Scaffold(
      backgroundColor: _C.cream,
      appBar: AppBar(
        backgroundColor: _C.cream,
        elevation: 0,
        foregroundColor: _C.ink,
        title: const Text('Review your order',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: _C.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _C.line)),
            child: Column(children: [
              _SummaryRow('Package', package.name),
              const SizedBox(height: 10),
              _SummaryRow('Credits', '${package.creditsAmount}'),
              const SizedBox(height: 10),
              Divider(color: _C.line, height: 1),
              const SizedBox(height: 10),
              _SummaryRow('Total', '₱${package.priceDisplay.toStringAsFixed(2)}',
                  bold: true),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: _C.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.line)),
            child: Row(children: [
              const Text('Payment Method',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink)),
              const Spacer(),
              Text(methodLabel,
                  style: const TextStyle(fontSize: 13, color: _C.inkSoft)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text('Change',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.magenta)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _C.amberPale, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: _C.amber, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "You'll send ₱${package.priceDisplay.toStringAsFixed(0)} via "
                  '$methodLabel yourself. Your ${package.creditsAmount} credits '
                  "are added once our team verifies the payment — you can "
                  'track status in Purchase History.',
                  style: const TextStyle(fontSize: 11.5, color: _C.ink, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _C.magenta,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Confirm & Submit',
                    style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SummaryRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold ? _C.ink : _C.inkSoft)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: FontWeight.w800,
              color: bold ? _C.burgundy : _C.ink)),
    ]);
  }
}
