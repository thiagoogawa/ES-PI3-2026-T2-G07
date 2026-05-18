import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/startup_offer_model.dart';
import '../models/startup_portfolio_snapshot_model.dart';
import '../models/startup_trade_result_model.dart';

class StartupTradingApiDataSource {
  final ApiClient _apiClient;

  StartupTradingApiDataSource(this._apiClient);

  Future<List<StartupOfferModel>> fetchOffers(String startupId) async {
    final response = await _apiClient.get(
      '${ApiConstants.offers}?startupId=$startupId',
    );
    final data = response['data'] as List<dynamic>? ?? const [];

    return data
        .map((item) => StartupOfferModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StartupPortfolioSnapshotModel> fetchPortfolio(String idToken) async {
    final response = await _apiClient.get(
      ApiConstants.portfolio,
      headers: _authHeaders(idToken),
    );

    return StartupPortfolioSnapshotModel.fromJson(response);
  }

  Future<StartupPortfolioSnapshotModel> depositBalance(
    String idToken, {
    required double amount,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.portfolioDeposit,
      headers: _authHeaders(idToken),
      body: {'amount': amount},
    );

    return StartupPortfolioSnapshotModel.fromJson(response);
  }

  Future<StartupTradeResultModel> submitTrade(
    String idToken, {
    required String startupId,
    required String type,
    required double quantity,
    required double pricePerToken,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.startupTrade(startupId),
      headers: _authHeaders(idToken),
      body: {
        'type': type,
        'quantity': quantity,
        'pricePerToken': pricePerToken,
      },
    );

    return StartupTradeResultModel.fromJson(response);
  }

  Future<void> cancelOffer(String idToken, {required String offerId}) async {
    await _apiClient.post(
      ApiConstants.offerCancel(offerId),
      headers: _authHeaders(idToken),
    );
  }

  Future<StartupTradeMatchModel> acceptOffer(
    String idToken, {
    required String offerId,
    required double quantity,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.offerAccept(offerId),
      headers: _authHeaders(idToken),
      body: {'quantity': quantity},
    );

    return StartupTradeMatchModel.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Map<String, String> _authHeaders(String idToken) {
    return {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    };
  }
}
