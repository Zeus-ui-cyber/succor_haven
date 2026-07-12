// lib/features/payments/screens/student/buy_credits_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/payments_controller.dart';
import '../../../../models/credit_package.dart';
import '../../../../models/payment.dart';

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
const _kPaymentMethods = [
  ('gcash', 'GCash', Icons.phone_iphone_rounded),
  ('maya', 'Maya', Icons.account_balance_wallet_rounded),
  ('card', 'Card', Icons.credit_card_rounded),
  ('alipay', 'Alipay', Icons.payment_rounded),
  ('wechat', 'WeChat Pay', Icons.chat_bubble_rounded),
];

class BuyCreditsScreen extends ConsumerWidget {
  const BuyCreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  children:
                      active.map((p) => _PackageCard(package: p)).toList(),
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
                  children:
                      payments.map((p) => _PaymentTile(payment: p)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends ConsumerWidget {
  final CreditPackageModel package;
  const _PackageCard({required this.package});

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _C.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _PaymentMethodSheet(package: package),
    );
    if (method == null || !context.mounted) return;

    try {
      await ref
          .read(paymentsRepositoryProvider)
          .requestPayment(creditPackageId: package.id, paymentMethod: method);
      ref.invalidate(myPaymentsProvider);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (_) => _RequestSubmittedDialog(
          package: package,
          methodLabel: _kPaymentMethods.firstWhere((m) => m.$1 == method).$2,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not submit request: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₱${package.priceDisplay.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _C.burgundy)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _buy(context, ref),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: _C.magenta, borderRadius: BorderRadius.circular(20)),
                child: const Text('Buy',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

class _PaymentMethodSheet extends StatelessWidget {
  final CreditPackageModel package;
  const _PaymentMethodSheet({required this.package});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: _C.line, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
              'Pay ₱${package.priceDisplay.toStringAsFixed(0)} for ${package.name}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink)),
          const SizedBox(height: 4),
          const Text("Choose how you'll send payment",
              style: TextStyle(fontSize: 12, color: _C.inkSoft)),
          const SizedBox(height: 12),
          ..._kPaymentMethods.map((m) => ListTile(
                onTap: () => Navigator.pop(context, m.$1),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: _C.softPink,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(m.$3, color: _C.magenta, size: 18),
                ),
                title: Text(m.$2,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.ink)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 13, color: _C.inkSoft),
              )),
        ]),
      ),
    );
  }
}

class _RequestSubmittedDialog extends StatelessWidget {
  final CreditPackageModel package;
  final String methodLabel;
  const _RequestSubmittedDialog(
      {required this.package, required this.methodLabel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _C.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(children: [
        Icon(Icons.check_circle_rounded, color: _C.green),
        SizedBox(width: 8),
        Text('Request submitted', style: TextStyle(fontSize: 15)),
      ]),
      content: Text(
        'Send ₱${package.priceDisplay.toStringAsFixed(0)} via $methodLabel, '
        "then wait for our team to confirm your payment. Your ${package.creditsAmount} "
        "credits will be added once it's verified — check Payment History for status.",
        style: const TextStyle(fontSize: 13, color: _C.inkSoft, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it',
              style: TextStyle(color: _C.magenta, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentModel payment;
  const _PaymentTile({required this.payment});

  (Color, Color, String) _statusStyle(PaymentStatus s) => switch (s) {
        PaymentStatus.succeeded => (_C.green, _C.greenPale, 'Succeeded'),
        PaymentStatus.failed => (_C.red, _C.redPale, 'Failed'),
        PaymentStatus.refunded => (_C.inkSoft, _C.softPink, 'Refunded'),
        PaymentStatus.pending => (_C.amber, _C.amberPale, 'Pending'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, pale, label) = _statusStyle(payment.status);
    return Container(
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
      ]),
    );
  }
}
