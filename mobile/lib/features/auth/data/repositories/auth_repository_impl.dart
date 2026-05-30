/// Thiago Ryuji Ogawa - RA:24024450
///
/// Implementacao concreta do repositorio de autenticacao.
/// Orquestra datasources, mapeia modelos para entidades e expoe
/// uma API de alto nivel consumida pela camada de apresentacao.

import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  /// Implementa o repositório de autenticação combinando Firebase Auth e API.
  final AuthRemoteDataSource _authRemoteDataSource;
  final AuthApiDataSource _authApiDataSource;

  AuthRepositoryImpl(this._authRemoteDataSource, this._authApiDataSource);

  Future<AuthenticatedUser> _fetchAuthenticatedUser({
    /// Busca o perfil autenticado usando o token atual, com opção de refresh.
    bool forceRefresh = false,
  }) async {
    final idToken = await _authRemoteDataSource.getIdToken(
      forceRefresh: forceRefresh,
    );
    return _authApiDataSource.fetchMe(idToken);
  }

  @override
  Future<AuthenticatedUser?> getCurrentUser() async {
    /// Recupera o usuário corrente quando existe sessão válida no dispositivo.
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
    /// Autentica o usuário no Firebase e depois sincroniza seu perfil da API.
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
    /// Cria a conta, persiste os dados cadastrais no backend e desfaz o fluxo em
    /// caso a sincronização final falhe.
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
    /// Encaminha o pedido de redefinição de senha para o provedor remoto.
    return _authRemoteDataSource.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() {
    return _authRemoteDataSource.signOut();
  }
}
