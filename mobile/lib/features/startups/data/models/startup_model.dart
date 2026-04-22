import '../../domain/entities/startup.dart';

class StartupModel extends Startup {
  const StartupModel({
    required super.id,
    required super.name,
    required super.description,
    required super.stage,
    required super.sector,
    required super.currentPrice,
    required super.capitalRaised,
    required super.dailyVariation,
  });

  factory StartupModel.fromJson(Map<String, dynamic> json) {
    final variation = json['variation'] as Map<String, dynamic>?;

    return StartupModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Startup',
      description: json['description'] as String? ?? '',
      stage: json['stage'] as String? ?? 'Nao informado',
      sector: json['sector'] as String?,
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0,
      capitalRaised: (json['capitalRaised'] as num?)?.toDouble() ?? 0,
      dailyVariation: (variation?['diaria'] as num?)?.toDouble() ?? 0,
    );
  }
}
