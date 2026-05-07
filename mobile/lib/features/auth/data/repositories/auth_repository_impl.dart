import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _authRemoteDataSource;
  final AuthApiDataSource _authApiDataSource;

  AuthRepositoryImpl(this._authRemoteDataSource, this._authApiDataSource);

  Future<AuthenticatedUser> _fetchAuthenticatedUser({
    bool forceRefresh = false,
  }) async {
    final idToken = await _authRemoteDataSource.getIdToken(
      forceRefresh: forceRefresh,
    );
    return _authApiDataSource.fetchMe(idToken);
  }

  @override
  Future<AuthenticatedUser?> getCurrentUser() async {
    if (!_authRemoteDataSource.isSignedIn) {
      return null;
    }

    try {
      return await _fetchAuthenticatedUser();
    } catch (_) {
      return _fetchAuthenticatedUser(forceRefresh: true);
    }
  }

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async {
    await _authRemoteDataSource.signIn(email: email, password: password);

    try {
      return await _fetchAuthenticatedUser();
    } catch (_) {
      try {
        return await _fetchAuthenticatedUser(forceRefresh: true);
      } catch (error) {
        await _authRemoteDataSource.signOut();
        rethrow;
      }
    }
  }

  @override
  Future<AuthenticatedUser> signUp({
    required String fullName,
    required String cpf,
    required String phone,
    required String email,
    required String password,
  }) async {
    await _authRemoteDataSource.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );

    try {
      final idToken = await _authRemoteDataSource.getIdToken(
        forceRefresh: true,
      );
      return await _authApiDataSource.updateProfile(
        idToken,
        name: fullName,
        cpf: cpf,
        phone: phone,
      );
    } catch (_) {
      try {
        final retryIdToken = await _authRemoteDataSource.getIdToken(
          forceRefresh: true,
        );
        return await _authApiDataSource.updateProfile(
          retryIdToken,
          name: fullName,
          cpf: cpf,
          phone: phone,
        );
      } catch (error) {
        try {
          await _authRemoteDataSource.deleteCurrentUser();
        } catch (_) {
          await _authRemoteDataSource.signOut();
        }

        throw Exception(
          'Nao foi possivel finalizar o cadastro no servidor. A conta parcial foi revertida; tente novamente.',
        );
      }
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _authRemoteDataSource.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() {
    return _authRemoteDataSource.signOut();
  }
}
