// lib/features/payments/screens/admin/manage_payments_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/payments_controller.dart';
import '../../../../models/credit_package.dart';
import '../../../../models/payment.dart';

class _C {
  static const burgundy = Color(0xFF7D002B);
  static const magenta = Color(0xFFD64577);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const slateBlue = Color(0xFF3E678A);
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

const _kPaymentMethods = [
  ('gcash', 'GCash'),
  ('maya', 'Maya'),
  ('card', 'Card'),
  ('alipay', 'Alipay'),
  ('wechat', 'WeChat Pay'),
];
const _kPaymentStatuses = [
  'pending',
  'succeeded',
  'failed',
  'refunded',
  'cancelled',
];

class ManagePaymentsScreen extends StatefulWidget {
  const ManagePaymentsScreen({super.key});
  @override
  State<ManagePaymentsScreen> createState() => _ManagePaymentsScreenState();
}

class _ManagePaymentsScreenState extends State<ManagePaymentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        decoration: BoxDecoration(
            color: _C.softPink, borderRadius: BorderRadius.circular(14)),
        child: TabBar(
          controller: _tabs,
          indicator: BoxDecoration(
              color: _C.burgundy, borderRadius: BorderRadius.circular(12)),
          labelColor: Colors.white,
          unselectedLabelColor: _C.inkSoft,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'Payments'), Tab(text: 'Packages')],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: const [_PaymentsSubTab(), _PackagesSubTab()],
        ),
      ),
    ]);
  }
}

// ── Payments sub-tab ─────────────────────────────────────────────────────
class _PaymentsSubTab extends ConsumerWidget {
  const _PaymentsSubTab();

  Future<void> _setStatus(
      BuildContext ctx, WidgetRef ref, PaymentModel p, String status) async {
    if (status == 'refunded') {
      final confirm = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Refund this payment?'),
          content: const Text(
              "This reverses the student's credits if their balance still "
              "covers it. If they've already spent below that amount, "
              "credits are left alone and this gets flagged for manual "
              "review instead."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('Refund', style: TextStyle(color: _C.red))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final result = await ref
          .read(paymentsRepositoryProvider)
          .updatePaymentStatus(id: p.id, status: status);
      ref.invalidate(adminPaymentsProvider);
      if (!ctx.mounted) return;

      if (result.flaggedForReview) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text(
              "Marked refunded, but the student's balance was too low to "
              'claw back credits — flagged for manual review.'),
          backgroundColor: _C.amber,
        ));
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(switch (status) {
            'succeeded' => 'Payment confirmed, credits added ✓',
            'refunded' => 'Payment refunded, credits reversed',
            _ => 'Payment marked $status',
          }),
          backgroundColor: status == 'succeeded' ? _C.green : _C.burgundy,
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminPaymentsProvider);
    final statusFilter = ref.watch(adminPaymentStatusFilterProvider);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'All',
                active: statusFilter == null,
                onTap: () => ref
                    .read(adminPaymentStatusFilterProvider.notifier)
                    .state = null,
              ),
              ..._kPaymentStatuses.map((s) => _FilterChip(
                    label: s,
                    active: statusFilter == s,
                    onTap: () => ref
                        .read(adminPaymentStatusFilterProvider.notifier)
                        .state = s,
                  )),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: async.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: _C.burgundy)),
          error: (e, _) => Center(child: Text('$e')),
          data: (result) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_C.burgundy, _C.magenta],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  const Icon(Icons.payments_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  const Text('Total Revenue',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const Spacer(),
                  Text(
                      '₱${(result.totalRevenueCents / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
              if (result.payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                      child: Text('No payments found',
                          style: TextStyle(color: _C.inkSoft))),
                )
              else
                ...result.payments.map((p) => _AdminPaymentTile(
                    payment: p,
                    onSetStatus: (s) => _setStatus(context, ref, p, s))),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _AdminPaymentTile extends StatelessWidget {
  final PaymentModel payment;
  final void Function(String status) onSetStatus;
  const _AdminPaymentTile({required this.payment, required this.onSetStatus});

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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.studentName ?? 'Unknown student',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _C.ink)),
                Text(payment.studentEmail ?? '',
                    style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: pale, borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('₱${payment.amountDisplay.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _C.ink)),
          if (payment.packageName != null) ...[
            const SizedBox(width: 8),
            Text('· ${payment.packageName}',
                style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          ],
          const Spacer(),
          if (payment.paymentMethod != null)
            Text(
                _kPaymentMethods
                    .firstWhere((m) => m.$1 == payment.paymentMethod,
                        orElse: () =>
                            (payment.paymentMethod!, payment.paymentMethod!))
                    .$2,
                style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
        ]),
        Text(
            '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year}',
            style: const TextStyle(fontSize: 10, color: _C.inkSoft)),
        if (payment.refundRequestedAt != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _C.amberPale, borderRadius: BorderRadius.circular(20)),
            child: const Text('Student requested a refund',
                style: TextStyle(
                    fontSize: 10, color: _C.amber, fontWeight: FontWeight.w700)),
          ),
        ],
        if (payment.status == PaymentStatus.cancelled &&
            payment.cancelReason != null) ...[
          const SizedBox(height: 8),
          Text('Cancelled: ${payment.cancelReason}',
              style: const TextStyle(fontSize: 10.5, color: _C.inkSoft)),
        ],
        if (payment.status == PaymentStatus.pending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onSetStatus('failed'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.red,
                  side: const BorderSide(color: _C.redPale, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child:
                    const Text('Mark Failed', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => onSetStatus('succeeded'),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.green,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Confirm', style: TextStyle(fontSize: 12)),
              ),
            ),
          ]),
        ],
        if (payment.status == PaymentStatus.succeeded) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onSetStatus('refunded'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.inkSoft,
                side: const BorderSide(color: _C.line, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Refund', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Packages sub-tab ─────────────────────────────────────────────────────
class _PackagesSubTab extends ConsumerWidget {
  const _PackagesSubTab();

  void _openForm(BuildContext ctx, WidgetRef ref,
      {CreditPackageModel? existing}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: _C.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _PackageFormSheet(existing: existing),
    );
  }

  Future<void> _delete(BuildContext ctx, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete package?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: _C.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(paymentsRepositoryProvider).deletePackage(id);
      ref.invalidate(adminPackagesProvider);
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminPackagesProvider);
    return Stack(children: [
      async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _C.burgundy)),
        error: (e, _) => Center(child: Text('$e')),
        data: (packages) {
          final sorted = [...packages]
            ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
          if (sorted.isEmpty) {
            return const Center(
                child: Text('No packages yet — tap + to add one.',
                    style: TextStyle(color: _C.inkSoft)));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = sorted[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.isActive ? _C.paper : _C.softPink,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.line),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _C.ink)),
                        Text(
                            '${p.creditsAmount} credits · ₱${p.priceDisplay.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 11, color: _C.inkSoft)),
                        if (!p.isActive)
                          const Text('Inactive',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _C.red,
                                  fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: _C.slateBlue, size: 19),
                    onPressed: () => _openForm(context, ref, existing: p),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: _C.red, size: 19),
                    onPressed: () => _delete(context, ref, p.id),
                  ),
                ]),
              );
            },
          );
        },
      ),
      Positioned(
        right: 20,
        bottom: 20,
        child: FloatingActionButton(
          backgroundColor: _C.burgundy,
          onPressed: () => _openForm(context, ref),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    ]);
  }
}

class _PackageFormSheet extends ConsumerStatefulWidget {
  final CreditPackageModel? existing;
  const _PackageFormSheet({this.existing});

  @override
  ConsumerState<_PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends ConsumerState<_PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _creditsCtrl = TextEditingController(
      text: widget.existing?.creditsAmount.toString() ?? '');
  late final _priceCtrl = TextEditingController(
      text: widget.existing?.priceDisplay.toStringAsFixed(0) ?? '');
  late final _orderCtrl = TextEditingController(
      text: widget.existing?.displayOrder.toString() ?? '0');
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _creditsCtrl.dispose();
    _priceCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(paymentsRepositoryProvider);
    final priceCents = (double.parse(_priceCtrl.text) * 100).round();
    try {
      if (widget.existing == null) {
        await repo.createPackage(
          name: _nameCtrl.text.trim(),
          creditsAmount: int.parse(_creditsCtrl.text),
          priceCents: priceCents,
          displayOrder: int.tryParse(_orderCtrl.text) ?? 0,
        );
      } else {
        await repo.updatePackage(
          id: widget.existing!.id,
          name: _nameCtrl.text.trim(),
          creditsAmount: int.parse(_creditsCtrl.text),
          priceCents: priceCents,
          displayOrder: int.tryParse(_orderCtrl.text) ?? 0,
          isActive: _isActive,
        );
      }
      ref.invalidate(adminPackagesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _C.line, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? 'Edit Package' : 'New Package',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _creditsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Credits amount'),
              validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0
                  ? null
                  : 'Enter a positive number',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price (₱)'),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0
                  ? null
                  : 'Enter a positive amount',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _orderCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Display order'),
            ),
            if (isEdit) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _isActive,
                activeThumbColor: _C.magenta,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _C.burgundy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Save Changes' : 'Create Package'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active ? _C.burgundy : _C.paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? _C.burgundy : _C.line),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : _C.inkSoft)),
          ),
        ),
      );
}
