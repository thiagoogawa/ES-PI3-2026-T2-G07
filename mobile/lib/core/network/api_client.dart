/// Thiago Ryuji Ogawa - RA:24024450
///
/// Cliente HTTP enxuto usado pelas fontes de dados do app para conversar com a
/// API REST. Ele centraliza serializacao JSON, envio de headers e traducao de
/// falhas HTTP para [AppException], evitando repetir a mesma rotina em cada
/// datasource.

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';

/// Encapsula operacoes HTTP JSON usadas pelo mobile.
class ApiClient {
  final http.Client _client;

  /// Permite injetar um [http.Client] customizado em testes.
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Executa uma requisicao GET e devolve o corpo decodificado como mapa.
  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.get(Uri.parse(url), headers: headers);

    return _parseResponse(response);
  }

  /// Executa uma requisicao POST serializando [body] para JSON quando presente.
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

  /// Executa uma requisicao PATCH serializando [body] para JSON quando presente.
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

  /// Normaliza respostas HTTP da API.
  ///
  /// Status de sucesso devolvem o JSON bruto. Qualquer erro vira uma
  /// [AppException] com a mensagem retornada pelo backend, quando disponivel.
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
