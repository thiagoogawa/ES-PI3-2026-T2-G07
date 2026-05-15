import '../entities/authenticated_user.dart';

typedef SmsCodeResolver = Future<String?> Function(String phoneHint);

abstract class AuthRepository {
  Future<AuthenticatedUser?> getCurrentUser();

  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
    SmsCodeResolver? requestSecondFactorCode,
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
