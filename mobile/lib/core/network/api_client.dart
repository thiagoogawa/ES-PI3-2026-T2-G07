import 'dart:convert';
import 'package:http/http.dart' as http;
import '../errors/app_exception.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.get(Uri.parse(url), headers: headers);

    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw AppException(
      body['error']?['message']?.toString() ?? 'Request failed',
    );
  }
}
