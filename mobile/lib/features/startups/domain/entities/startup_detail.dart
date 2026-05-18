import 'startup.dart';

class StartupPartner {
  final String id;
  final String name;
  final double participation;

  const StartupPartner({
    required this.id,
    required this.name,
    required this.participation,
  });
}

class StartupQuestion {
  final String id;
  final String question;
  final String? answer;

  const StartupQuestion({
    required this.id,
    required this.question,
    required this.answer,
  });
}

class StartupUpdate {
  final String id;
  final String title;
  final String content;
  final String? date;

  const StartupUpdate({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });
}

class StartupPricePoint {
  final String id;
  final double price;
  final String? timestamp;

  const StartupPricePoint({
    required this.id,
    required this.price,
    required this.timestamp,
  });
}

class StartupDetail extends Startup {
  final double totalTokens;
  final String executiveSummary;
  final String? businessPlanUrl;
  final String? pitchDeckUrl;
  final List<String> videos;
  final List<String> mentors;
  final List<String> boardMembers;
  final double marketCap;
  final List<StartupPartner> partners;
  final List<StartupQuestion> questions;
  final List<StartupUpdate> updates;
  final List<StartupPricePoint> priceHistory;

  const StartupDetail({
    required super.id,
    required super.name,
    required super.photoUrl,
    required super.description,
    required super.stage,
    required super.sector,
    required super.currentPrice,
    required super.capitalRaised,
    required super.dailyVariation,
    required this.totalTokens,
    required this.executiveSummary,
    required this.businessPlanUrl,
    required this.pitchDeckUrl,
    required this.videos,
    required this.mentors,
    required this.boardMembers,
    required this.marketCap,
    required this.partners,
    required this.questions,
    required this.updates,
    required this.priceHistory,
  });
}
