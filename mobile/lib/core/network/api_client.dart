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

    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.post(
      Uri.parse(url),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );

    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final response = await _client.patch(
      Uri.parse(url),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );

    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final request = http.Request('DELETE', Uri.parse(url));
    request.headers.addAll(headers ?? const {});

    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    return _parseResponse(response);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw AppException(
      body['error']?['message']?.toString() ?? 'Request failed',
    );
  }
}
