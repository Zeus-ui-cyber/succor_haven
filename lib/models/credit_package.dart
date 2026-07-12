// lib/models/credit_package.dart

class CreditPackageModel {
  final String id;
  final String name;
  final int creditsAmount;
  final int priceCents;
  final String currency;
  final int displayOrder;
  final bool isActive;

  const CreditPackageModel({
    required this.id,
    required this.name,
    required this.creditsAmount,
    required this.priceCents,
    required this.currency,
    required this.displayOrder,
    this.isActive = true,
  });

  double get priceDisplay => priceCents / 100;

  factory CreditPackageModel.fromJson(Map<String, dynamic> json) {
    return CreditPackageModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      creditsAmount: (json['credits_amount'] as num).toInt(),
      priceCents: (json['price_cents'] as num).toInt(),
      currency: json['currency'] as String? ?? 'PHP',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
