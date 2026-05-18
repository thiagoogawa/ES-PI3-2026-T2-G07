import '../../domain/entities/startup_detail.dart';

class StartupDetailModel extends StartupDetail {
  const StartupDetailModel({
    required super.id,
    required super.name,
    required super.photoUrl,
    required super.description,
    required super.stage,
    required super.sector,
    required super.currentPrice,
    required super.capitalRaised,
    required super.dailyVariation,
    required super.totalTokens,
    required super.executiveSummary,
    required super.businessPlanUrl,
    required super.pitchDeckUrl,
    required super.videos,
    required super.mentors,
    required super.boardMembers,
    required super.marketCap,
    required super.partners,
    required super.questions,
    required super.updates,
    required super.priceHistory,
  });

  factory StartupDetailModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final variation = data['variation'] as Map<String, dynamic>? ?? {};
    final documents = data['documents'] as Map<String, dynamic>? ?? {};
    final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
    final socios = data['socios'] as List<dynamic>? ?? [];
    final perguntas = data['perguntas'] as List<dynamic>? ?? [];
    final updates = data['updates'] as List<dynamic>? ?? [];
    final priceHistory = data['priceHistory'] as List<dynamic>? ?? [];

    return StartupDetailModel(
      id: data['id'] as String,
      name: data['name'] as String? ?? 'Startup',
      photoUrl: data['photoUrl'] as String?,
      description: data['description'] as String? ?? '',
      stage: data['stage'] as String? ?? 'Nao informado',
      sector: data['sector'] as String?,
      currentPrice: (data['currentPrice'] as num?)?.toDouble() ?? 0,
      capitalRaised: (data['capitalRaised'] as num?)?.toDouble() ?? 0,
      dailyVariation: (variation['diaria'] as num?)?.toDouble() ?? 0,
      totalTokens:
          (data['totalTokens'] as num?)?.toDouble() ??
          (metrics['totalTokens'] as num?)?.toDouble() ??
          0,
      executiveSummary:
          documents['executiveSummary'] as String? ??
          data['executiveSummary'] as String? ??
          '',
      businessPlanUrl: documents['businessPlanUrl'] as String?,
      pitchDeckUrl: documents['pitchDeckUrl'] as String?,
      videos: _readStringList(data['videos']),
      mentors: _readStringList(data['mentors']),
      boardMembers: _readStringList(data['boardMembers']),
      marketCap: (metrics['marketCap'] as num?)?.toDouble() ?? 0,
      partners: socios.map((item) {
        final map = item as Map<String, dynamic>;
        return StartupPartner(
          id: map['id'] as String? ?? '',
          name: map['nome'] as String? ?? 'Socio',
          participation: (map['participacao'] as num?)?.toDouble() ?? 0,
        );
      }).toList(),
      questions: perguntas.map((item) {
        final map = item as Map<String, dynamic>;
        return StartupQuestion(
          id: map['id'] as String? ?? '',
          question: map['pergunta'] as String? ?? '',
          answer: map['resposta'] as String?,
        );
      }).toList(),
      updates: updates.map((item) {
        final map = item as Map<String, dynamic>;
        return StartupUpdate(
          id: map['id'] as String? ?? '',
          title: map['title'] as String? ?? 'Atualizacao',
          content: map['content'] as String? ?? '',
          date: map['date'] as String?,
        );
      }).toList(),
      priceHistory: priceHistory.map((item) {
        final map = item as Map<String, dynamic>;
        return StartupPricePoint(
          id: map['id'] as String? ?? '',
          price: (map['price'] as num?)?.toDouble() ?? 0,
          timestamp: map['timestamp'] as String?,
        );
      }).toList(),
    );
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List<dynamic>) {
      return const [];
    }

    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
