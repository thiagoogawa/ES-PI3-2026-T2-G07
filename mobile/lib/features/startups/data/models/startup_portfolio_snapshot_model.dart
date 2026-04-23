class StartupPortfolioPositionModel {
  final String startupId;
  final String startupName;
  final double quantity;
  final double averagePrice;
  final double investedAmount;
  final double currentPrice;
  final double currentValue;
  final double profitLoss;

  const StartupPortfolioPositionModel({
    required this.startupId,
    required this.startupName,
    required this.quantity,
    required this.averagePrice,
    required this.investedAmount,
    required this.currentPrice,
    required this.currentValue,
    required this.profitLoss,
  });

  factory StartupPortfolioPositionModel.fromJson(Map<String, dynamic> json) {
    return StartupPortfolioPositionModel(
      startupId: json['startupId'] as String? ?? '',
      startupName: json['startupName'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      averagePrice: (json['averagePrice'] as num?)?.toDouble() ?? 0,
      investedAmount: (json['investedAmount'] as num?)?.toDouble() ?? 0,
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
      profitLoss: (json['profitLoss'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StartupPortfolioSnapshotModel {
  final String userId;
  final double balance;
  final double reservedBalance;
  final double totalInvested;
  final double currentValue;
  final double profitLoss;
  final List<StartupPortfolioPositionModel> positions;

  const StartupPortfolioSnapshotModel({
    required this.userId,
    required this.balance,
    required this.reservedBalance,
    required this.totalInvested,
    required this.currentValue,
    required this.profitLoss,
    required this.positions,
  });

  factory StartupPortfolioSnapshotModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>? ?? const {};
    final positions = data['positions'] as List<dynamic>? ?? const [];

    return StartupPortfolioSnapshotModel(
      userId: user['uid'] as String? ?? '',
      balance: (data['balance'] as num?)?.toDouble() ?? 0,
      reservedBalance: (data['reservedBalance'] as num?)?.toDouble() ?? 0,
      totalInvested: (data['totalInvested'] as num?)?.toDouble() ?? 0,
      currentValue: (data['currentValue'] as num?)?.toDouble() ?? 0,
      profitLoss: (data['profitLoss'] as num?)?.toDouble() ?? 0,
      positions: positions
          .map(
            (item) => StartupPortfolioPositionModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  StartupPortfolioPositionModel? positionForStartup(String startupId) {
    for (final position in positions) {
      if (position.startupId == startupId) {
        return position;
      }
    }

    return null;
  }
}
