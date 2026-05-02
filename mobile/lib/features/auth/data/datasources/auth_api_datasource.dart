import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/authenticated_user_model.dart';

class AuthApiDataSource {
  final ApiClient _apiClient;

  AuthApiDataSource(this._apiClient);

  Future<AuthenticatedUserModel> fetchMe(String idToken) async {
    final response = await _apiClient.get(
      ApiConstants.authMe,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    return AuthenticatedUserModel.fromJson(response);
  }

  Future<AuthenticatedUserModel> updateProfile(
    String idToken, {
    required String name,
    required String cpf,
    required String phone,
    String? picture,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.authProfile,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: {'name': name, 'cpf': cpf, 'phone': phone, 'picture': picture},
    );

    return AuthenticatedUserModel.fromJson(response);
  }
}
