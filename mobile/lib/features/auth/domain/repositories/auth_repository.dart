/// Thiago Ryuji Ogawa - RA:24024450
///
/// Contrato de repositorio do modulo de autenticacao.
/// Define as operacoes esperadas pela camada de dominio sem acoplar
/// o restante do app aos detalhes de Firebase ou HTTP.

import '../entities/authenticated_user.dart';

abstract class AuthRepository {
  Future<AuthenticatedUser?> getCurrentUser();

  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  });

  Future<AuthenticatedUser> signUp({
    required String fullName,
    required String cpf,
    required String phone,
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}
