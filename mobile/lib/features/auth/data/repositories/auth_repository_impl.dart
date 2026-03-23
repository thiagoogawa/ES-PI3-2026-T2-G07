import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _authRemoteDataSource;
  final AuthApiDataSource _authApiDataSource;

  AuthRepositoryImpl(this._authRemoteDataSource, this._authApiDataSource);

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async {
    await _authRemoteDataSource.signIn(email: email, password: password);

    final idToken = await _authRemoteDataSource.getIdToken();
    return _authApiDataSource.fetchMe(idToken);
  }

  @override
  Future<AuthenticatedUser> signUp({
    required String email,
    required String password,
  }) async {
    await _authRemoteDataSource.signUp(email: email, password: password);

    final idToken = await _authRemoteDataSource.getIdToken();
    return _authApiDataSource.fetchMe(idToken);
  }

  @override
  Future<void> signOut() {
    return _authRemoteDataSource.signOut();
  }
}
