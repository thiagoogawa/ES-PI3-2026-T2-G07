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
}
