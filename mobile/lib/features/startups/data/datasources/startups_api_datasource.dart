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

  Future<StartupDetailModel> fetchStartupDetailAuthenticated(
    String idToken,
    String startupId,
  ) async {
    final response = await _apiClient.get(
      ApiConstants.startupDetail(startupId),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    return StartupDetailModel.fromJson(response);
  }

  Future<void> submitQuestion(
    String startupId, {
    required String question,
    required bool isPublic,
    String? idToken,
  }) async {
    await _apiClient.post(
      ApiConstants.startupQuestions(startupId),
      headers: {
        if (idToken != null && idToken.isNotEmpty)
          'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: {'question': question, 'public': isPublic},
    );
  }

  Future<StartupDetailModel> updateStartup(
    String idToken, {
    required String startupId,
    required String name,
    required String description,
    required String stage,
    String? sector,
    required String executiveSummary,
    String? businessPlanUrl,
    String? pitchDeckUrl,
    required List<String> mentors,
    required List<String> boardMembers,
    required List<String> videos,
  }) async {
    final response = await _apiClient.patch(
      ApiConstants.startupAdminUpdate(startupId),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: {
        'name': name,
        'description': description,
        'stage': stage,
        'sector': sector,
        'executiveSummary': executiveSummary,
        'businessPlanUrl': businessPlanUrl,
        'pitchDeckUrl': pitchDeckUrl,
        'mentors': mentors,
        'boardMembers': boardMembers,
        'videos': videos,
      },
    );

    return StartupDetailModel.fromJson(response);
  }

  Future<StartupDetailModel> answerQuestion(
    String idToken, {
    required String startupId,
    required String questionId,
    required String answer,
  }) async {
    final response = await _apiClient.patch(
      ApiConstants.startupAnswerQuestion(startupId, questionId),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: {'answer': answer},
    );

    return StartupDetailModel.fromJson(response);
  }
}
