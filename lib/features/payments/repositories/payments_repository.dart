// lib/features/payments/repositories/payments_repository.dart

import '../../../core/api/api_service.dart';
import '../../../models/credit_package.dart';
import '../../../models/payment.dart';

class PaymentsRepository {
  final ApiService _api = ApiService.instance;

  // ── Public / student ─────────────────────────────────────────────────────
  Future<List<CreditPackageModel>> getPackages() async {
    final data = await _api.get('/credit-packages');
    return (data as List)
        .map((e) => CreditPackageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PaymentModel>> getMyPayments() async {
    final data = await _api.get('/credits/payments/mine');
    return (data as List)
        .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Student — request a purchase ────────────────────────────────────────
  // No payment gateway yet (Phase 2) — this creates a `pending` payment row.
  // The student is shown manual payment instructions (e.g. send to GCash),
  // and an admin confirms/rejects it from the Payments tab once the transfer
  // is verified — that's when credits actually get added to the account.
  // ⚠️ BACKEND TODO: needs a POST /credits/payments route that inserts a
  // `pending` row (amount/currency/package looked up server-side from
  // creditPackageId, NOT trusted from the client) and returns it.
  Future<PaymentModel> requestPayment({
    required String creditPackageId,
    required String paymentMethod,
  }) async {
    final data = await _api.post('/credits/payments', data: {
      'creditPackageId': creditPackageId,
      'paymentMethod': paymentMethod,
    });
    return PaymentModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Admin — confirm / reject a payment ──────────────────────────────────
  // On 'succeeded', the backend must credit `creditsAmount` from the linked
  // package onto the student's account (same column bookings deduct from).
  // ⚠️ BACKEND TODO: needs a PATCH /admin/payments/:id/status route —
  // requireRole("admin"), sets status + paid_at, and on 'succeeded' runs the
  // credit top-up in the same transaction (idempotent — guard against
  // double-confirming an already-succeeded row).
  Future<void> updatePaymentStatus({
    required String id,
    required String status, // 'succeeded' | 'failed' | 'refunded'
  }) {
    return _api.patch('/admin/payments/$id/status', data: {'status': status});
  }

  // ── Admin — packages ─────────────────────────────────────────────────────
  Future<List<CreditPackageModel>> getPackagesAdmin() async {
    final data = await _api.get('/admin/credit-packages');
    return (data as List)
        .map((e) => CreditPackageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createPackage({
    required String name,
    required int creditsAmount,
    required int priceCents,
    String currency = 'PHP',
    int displayOrder = 0,
  }) {
    return _api.post('/admin/credit-packages', data: {
      'name': name,
      'creditsAmount': creditsAmount,
      'priceCents': priceCents,
      'currency': currency,
      'displayOrder': displayOrder,
    });
  }

  Future<void> updatePackage({
    required String id,
    String? name,
    int? creditsAmount,
    int? priceCents,
    String? currency,
    int? displayOrder,
    bool? isActive,
  }) {
    return _api.patch('/admin/credit-packages/$id', data: {
      if (name != null) 'name': name,
      if (creditsAmount != null) 'creditsAmount': creditsAmount,
      if (priceCents != null) 'priceCents': priceCents,
      if (currency != null) 'currency': currency,
      if (displayOrder != null) 'displayOrder': displayOrder,
      if (isActive != null) 'isActive': isActive,
    });
  }

  Future<void> deletePackage(String id) {
    return _api.delete('/admin/credit-packages/$id');
  }

  // ── Admin — payments ─────────────────────────────────────────────────────
  /// Returns { payments: List<PaymentModel>, totalRevenueCents: int }.
  Future<({List<PaymentModel> payments, int totalRevenueCents})>
      getPaymentsAdmin({String? status, String? method}) async {
    final query = <String, String>{
      if (status != null) 'status': status,
      if (method != null) 'method': method,
    };
    final data =
        await _api.get('/admin/payments', query: query.isEmpty ? null : query);
    final map = data as Map<String, dynamic>;
    final payments = (map['payments'] as List)
        .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final totalRevenueCents = (map['totalRevenueCents'] as num).toInt();
    return (payments: payments, totalRevenueCents: totalRevenueCents);
  }
}
