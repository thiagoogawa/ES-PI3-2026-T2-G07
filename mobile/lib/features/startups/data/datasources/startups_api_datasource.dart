/// Thiago Ryuji Ogawa - RA:24024450
///
/// Fonte de dados do modulo de startups.
/// Centraliza chamadas ao backend para listagem, detalhe, FAQ e
/// operacoes de negociacao ligadas ao marketplace.

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/startup_detail_model.dart';
import '../models/startup_model.dart';

class StartupsApiDataSource {
  /// Encapsula as operações HTTP ligadas à consulta e gestão de startups.
  final ApiClient _apiClient;

  StartupsApiDataSource(this._apiClient);

  Future<List<StartupModel>> fetchStartups() async {
    /// Carrega a lista pública de startups exibida no marketplace.
    final response = await _apiClient.get(ApiConstants.startups);
    final data = response['data'] as List<dynamic>? ?? [];

    return data
        .map((item) => StartupModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StartupDetailModel> fetchStartupDetail(String startupId) async {
    /// Busca o detalhamento público de uma startup específica.
    final response = await _apiClient.get(
      ApiConstants.startupDetail(startupId),
    );
    return StartupDetailModel.fromJson(response);
  }

  Future<StartupDetailModel> fetchStartupDetailAuthenticated(
    /// Busca o detalhamento autenticado incluindo campos liberados ao investidor.
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
    /// Envia uma pergunta para a FAQ pública ou privada da startup.
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
    /// Atualiza os dados editáveis de uma startup gerenciada por administrador.
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
    /// Registra a resposta administrativa para uma pergunta da FAQ.
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
