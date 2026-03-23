class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5001/mesclainvest-dev/us-central1/api',
  );

  static const String authMe = '$baseUrl/v1/auth/me';
}
