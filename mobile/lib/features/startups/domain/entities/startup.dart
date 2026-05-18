class Startup {
  final String id;
  final String name;
  final String? photoUrl;
  final String description;
  final String stage;
  final String? sector;
  final double currentPrice;
  final double capitalRaised;
  final double dailyVariation;

  const Startup({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.description,
    required this.stage,
    required this.sector,
    required this.currentPrice,
    required this.capitalRaised,
    required this.dailyVariation,
  });
}
