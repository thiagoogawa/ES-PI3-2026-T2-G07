class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5001/mesclainvest-dev/us-central1/api',
  );

  static const String authMe = '$baseUrl/v1/auth/me';
  static const String authProfile = '$baseUrl/v1/auth/profile';
  static const String startups = '$baseUrl/v1/startups';
  static const String offers = '$baseUrl/v1/offers';
  static const String portfolio = '$baseUrl/v1/portfolio';
  static const String dashboard = '$baseUrl/v1/portfolio/dashboard';
  static const String transactions = '$baseUrl/v1/transactions';

  static String startupTrade(String startupId) => '$startups/$startupId/trade';

  static String offerAccept(String offerId) => '$offers/$offerId/accept';
}
