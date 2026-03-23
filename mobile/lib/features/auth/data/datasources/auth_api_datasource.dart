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
}
