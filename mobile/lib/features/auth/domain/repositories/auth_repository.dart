import '../entities/authenticated_user.dart';

abstract class AuthRepository {
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  });

  Future<AuthenticatedUser> signUp({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
