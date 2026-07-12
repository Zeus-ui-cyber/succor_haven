// lib/features/payments/controllers/payments_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/payments_repository.dart';
import '../../../models/credit_package.dart';
import '../../../models/payment.dart';

final paymentsRepositoryProvider = Provider((_) => PaymentsRepository());

// ── Student ──────────────────────────────────────────────────────────────
final creditPackagesProvider = FutureProvider<List<CreditPackageModel>>(
  (ref) => ref.read(paymentsRepositoryProvider).getPackages(),
);

final myPaymentsProvider = FutureProvider<List<PaymentModel>>(
  (ref) => ref.read(paymentsRepositoryProvider).getMyPayments(),
);

// ── Admin ────────────────────────────────────────────────────────────────
final adminPackagesProvider = FutureProvider<List<CreditPackageModel>>(
  (ref) => ref.read(paymentsRepositoryProvider).getPackagesAdmin(),
);

// Filters the admin payments list is currently scoped to.
final adminPaymentStatusFilterProvider = StateProvider<String?>((_) => null);
final adminPaymentMethodFilterProvider = StateProvider<String?>((_) => null);

final adminPaymentsProvider = FutureProvider.autoDispose<
    ({List<PaymentModel> payments, int totalRevenueCents})>((ref) {
  final status = ref.watch(adminPaymentStatusFilterProvider);
  final method = ref.watch(adminPaymentMethodFilterProvider);
  return ref.read(paymentsRepositoryProvider).getPaymentsAdmin(
        status: status,
        method: method,
      );
});
