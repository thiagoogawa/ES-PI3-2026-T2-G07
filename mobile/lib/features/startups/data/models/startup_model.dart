/// Thiago Ryuji Ogawa - RA:24024450
///
/// Modelo de dados do modulo de startups.
/// Converte payloads da API em estruturas adequadas para consumo
/// pela camada de dominio e pelas telas do app.

import '../../domain/entities/startup.dart';

class StartupModel extends Startup {
  /// Modelo serializável que adapta o payload resumido de startup para a entidade
  /// de domínio usada pelo app.
  const StartupModel({
    required super.id,
    required super.name,
    required super.photoUrl,
    required super.description,
    required super.stage,
    required super.sector,
    required super.currentPrice,
    required super.capitalRaised,
    required super.dailyVariation,
  });

  factory StartupModel.fromJson(Map<String, dynamic> json) {
    /// Constrói o modelo a partir do JSON devolvido pela API de listagem.
    final variation = json['variation'] as Map<String, dynamic>?;

    return StartupModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Startup',
      photoUrl: json['photoUrl'] as String?,
      description: json['description'] as String? ?? '',
      stage: json['stage'] as String? ?? 'Nao informado',
      sector: json['sector'] as String?,
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0,
      capitalRaised: (json['capitalRaised'] as num?)?.toDouble() ?? 0,
      dailyVariation: (variation?['diaria'] as num?)?.toDouble() ?? 0,
    );
  }
}
