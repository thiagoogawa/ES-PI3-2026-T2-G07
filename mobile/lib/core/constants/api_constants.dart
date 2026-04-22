class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5001/mesclainvest-dev/us-central1',
  );

  static const String health = '$baseUrl/health';
  static const String authMe = '$baseUrl/getUserProfile';
  static const String authProfile = '$baseUrl/updateUserProfile';
  static const String startups = '$baseUrl/getStartups';
  static const String offers = '$baseUrl/getOffers';
  static const String createOffer = '$baseUrl/createOffer';
  static const String portfolio = '$baseUrl/getPortfolio';
  static const String dashboard = '$baseUrl/getPortfolioDashboard';
  static const String transactions = '$baseUrl/getTransactions';
  static const String seedDemo = '$baseUrl/seedDemo';

  static String startupDetail(String startupId) =>
      '$baseUrl/getStartupById/$startupId';

  static String acceptOffer(String offerId) =>
      '$baseUrl/acceptOffer/$offerId/accept';
}
