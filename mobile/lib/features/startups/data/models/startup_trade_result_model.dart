/// Thiago Ryuji Ogawa - RA:24024450
///
/// Modelo de dados do modulo de startups.
/// Converte payloads da API em estruturas adequadas para consumo
/// pela camada de dominio e pelas telas do app.

class StartupTradeMatchModel {
  final String offerId;
  final String startupId;
  final String startupName;
  final double quantity;
  final double pricePerToken;
  final double totalValue;
  final String status;
  final double remainingQuantity;

  const StartupTradeMatchModel({
    required this.offerId,
    required this.startupId,
    required this.startupName,
    required this.quantity,
    required this.pricePerToken,
    required this.totalValue,
    required this.status,
    required this.remainingQuantity,
  });

  factory StartupTradeMatchModel.fromJson(Map<String, dynamic> json) {
    return StartupTradeMatchModel(
      offerId: json['offerId'] as String? ?? '',
      startupId: json['startupId'] as String? ?? '',
      startupName: json['startupName'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      pricePerToken: (json['pricePerToken'] as num?)?.toDouble() ?? 0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'open',
      remainingQuantity: (json['remainingQuantity'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StartupTradeResultModel {
  final String startupId;
  final String type;
  final double quantity;
  final double pricePerToken;
  final double matchedQuantity;
  final double remainingQuantity;
  final String status;
  final List<StartupTradeMatchModel> matches;

  const StartupTradeResultModel({
    required this.startupId,
    required this.type,
    required this.quantity,
    required this.pricePerToken,
    required this.matchedQuantity,
    required this.remainingQuantity,
    required this.status,
    required this.matches,
  });

  factory StartupTradeResultModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final matches = data['matches'] as List<dynamic>? ?? const [];

    return StartupTradeResultModel(
      startupId: data['startupId'] as String? ?? '',
      type: data['type'] as String? ?? 'buy',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      pricePerToken: (data['pricePerToken'] as num?)?.toDouble() ?? 0,
      matchedQuantity: (data['matchedQuantity'] as num?)?.toDouble() ?? 0,
      remainingQuantity: (data['remainingQuantity'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? 'open',
      matches: matches
          .map(
            (item) =>
                StartupTradeMatchModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
