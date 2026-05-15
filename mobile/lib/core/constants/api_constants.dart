/// Centralized API endpoints used throughout the application.
/// Thiago Ryuji Ogawa - RA: 24024450
///
/// This class provides static constants and helper methods to build
/// all backend URLs in a consistent and maintainable way.
class ApiConstants {
  /// Base URL for all API requests.
  ///
  /// Can be overridden at build time using:
  /// `--dart-define=API_BASE_URL=your_url`
  ///
  /// Defaults to a local Firebase Functions endpoint.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5001/mesclainvest-dev/us-central1',
  );

  /// Endpoint to retrieve the currently authenticated user.
  static const String authMe = '$baseUrl/v1/auth/me';

  /// Endpoint to retrieve or update the user profile.
  static const String authProfile = '$baseUrl/v1/auth/profile';

  /// Endpoint to read or disable the current MFA configuration.
  static const String authMfa = '$baseUrl/v1/auth/mfa';

  /// Endpoint to synchronize MFA state stored by the backend.
  static const String authMfaSync = '$baseUrl/v1/auth/mfa/sync';

  /// Endpoint to fetch all startups.
  static const String startups = '$baseUrl/v1/startups';

  /// Endpoint to fetch all offers.
  static const String offers = '$baseUrl/v1/offers';

  /// Endpoint to retrieve the user's portfolio.
  static const String portfolio = '$baseUrl/v1/portfolio';

  /// Endpoint to retrieve portfolio dashboard data (summary, metrics).
  static const String dashboard = '$baseUrl/v1/portfolio/dashboard';

  /// Endpoint to retrieve all user transactions.
  static const String transactions = '$baseUrl/v1/transactions';

  /// Health check endpoint to verify if the API is running.
  static const String health = '$baseUrl/health';

  /// Returns the endpoint for a specific startup's details.
  ///
  /// [startupId] - Unique identifier of the startup.
  static String startupDetail(String startupId) => '$startups/$startupId';

  /// Returns the endpoint for trading a specific startup.
  ///
  /// [startupId] - Unique identifier of the startup.
  static String startupTrade(String startupId) => '$startups/$startupId/trade';

  /// Returns the endpoint to submit a public question for a startup FAQ.
  ///
  /// [startupId] - Unique identifier of the startup.
  static String startupQuestions(String startupId) =>
      '$startups/$startupId/questions';

  /// Returns the endpoint to update a startup managed by an admin.
  static String startupAdminUpdate(String startupId) => '$startups/$startupId';

  /// Returns the endpoint to answer an FAQ question as startup admin.
  static String startupAnswerQuestion(String startupId, String questionId) =>
      '$startups/$startupId/questions/$questionId/answer';

  /// Returns the endpoint to accept an offer.
  ///
  /// [offerId] - Unique identifier of the offer.
  static String offerAccept(String offerId) => '$offers/$offerId/accept';

  /// Returns the endpoint to cancel an offer.
  ///
  /// [offerId] - Unique identifier of the offer.
  static String offerCancel(String offerId) => '$offers/$offerId/cancel';
}
