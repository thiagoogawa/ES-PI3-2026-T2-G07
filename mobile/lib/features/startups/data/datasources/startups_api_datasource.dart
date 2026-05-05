import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/startup_detail_model.dart';
import '../models/startup_model.dart';

class StartupsApiDataSource {
  final ApiClient _apiClient;

  StartupsApiDataSource(this._apiClient);

  Future<List<StartupModel>> fetchStartups() async {
    final response = await _apiClient.get(ApiConstants.startups);
    final data = response['data'] as List<dynamic>? ?? [];

    return data
        .map((item) => StartupModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StartupDetailModel> fetchStartupDetail(String startupId) async {
    final response = await _apiClient.get(
      ApiConstants.startupDetail(startupId),
    );
    return StartupDetailModel.fromJson(response);
  }

  Future<void> submitQuestion(
    String startupId, {
    required String question,
  }) async {
    await _apiClient.post(
      ApiConstants.startupQuestions(startupId),
      headers: const {'Content-Type': 'application/json'},
      body: {'question': question},
    );
  }
}
