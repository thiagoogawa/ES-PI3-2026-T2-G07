import 'package:flutter/foundation.dart';
import '../../../../core/errors/auth_exception_mapper.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthController(this._authRepository);

  bool isLoading = false;
  String? errorMessage;
  AuthenticatedUser? currentUser;

  Future<void> restoreSession() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentUser = await _authRepository.getCurrentUser();
    } catch (error) {
      errorMessage = mapAuthException(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String? validateCredentials({
    required String email,
    required String password,
  }) {
    if (email.isEmpty || password.isEmpty) {
      return 'Preencha e-mail e senha.';
    }

    if (!email.contains('@')) {
      return 'Digite um e-mail valido.';
    }

    if (password.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }

    return null;
  }

  Future<void> signIn({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentUser = await _authRepository.signIn(
        email: email,
        password: password,
      );
    } catch (error) {
      errorMessage = mapAuthException(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentUser = await _authRepository.signUp(
        email: email,
        password: password,
      );
    } catch (error) {
      errorMessage = mapAuthException(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    currentUser = null;
    notifyListeners();
  }

  Future<bool> sendPasswordResetEmail({required String email}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.sendPasswordResetEmail(email: email);
      return true;
    } catch (error) {
      errorMessage = mapAuthException(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
