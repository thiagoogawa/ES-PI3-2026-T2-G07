import '../entities/authenticated_user.dart';

abstract class AuthRepository {
  Future<AuthenticatedUser?> getCurrentUser();

  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  });

  Future<AuthenticatedUser> signUp({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}
