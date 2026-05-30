/// Thiago Ryuji Ogawa - RA:24024450
///
/// Modelo de dados do modulo de startups.
/// Converte payloads da API em estruturas adequadas para consumo
/// pela camada de dominio e pelas telas do app.

class StartupOfferModel {
  final String id;
  final String startupId;
  final String userId;
  final String? userName;
  final String type;
  final String status;
  final double quantity;
  final double remainingQuantity;
  final double pricePerToken;
  final double totalValue;
  final String? createdAt;

  const StartupOfferModel({
    required this.id,
    required this.startupId,
    required this.userId,
    required this.userName,
    required this.type,
    required this.status,
    required this.quantity,
    required this.remainingQuantity,
    required this.pricePerToken,
    required this.totalValue,
    required this.createdAt,
  });

  factory StartupOfferModel.fromJson(Map<String, dynamic> json) {
    return StartupOfferModel(
      id: json['id'] as String? ?? '',
      startupId: json['startupId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String?,
      type: json['type'] as String? ?? 'buy',
      status: json['status'] as String? ?? 'open',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      remainingQuantity: (json['remainingQuantity'] as num?)?.toDouble() ?? 0,
      pricePerToken: (json['pricePerToken'] as num?)?.toDouble() ?? 0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] as String?,
    );
  }
}
