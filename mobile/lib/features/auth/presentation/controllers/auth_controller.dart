/// Thiago Ryuji Ogawa - RA:24024450
///
/// Controlador da camada de apresentacao do fluxo de autenticacao.
/// Coordena estado, chamadas assicronas e notificacoes para as
/// telas que dependem do usuario autenticado.

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/auth_exception_mapper.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  /// Gerencia o estado observável das ações de autenticação no aplicativo.
  final AuthRepository _authRepository;

  AuthController(this._authRepository);

  bool isLoading = false;
  String? errorMessage;
  AuthenticatedUser? currentUser;
  MultiFactorResolver? pendingSecondFactorResolver;

  Future<void> restoreSession() async {
    /// Restaura a sessão persistida, quando houver, e atualiza os observadores.
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
    /// Valida credenciais básicas antes de enviar o formulário ao backend.
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
    /// Executa login remoto e publica o usuário autenticado no estado local.
    isLoading = true;
    errorMessage = null;
    pendingSecondFactorResolver = null;
    notifyListeners();

    try {
      currentUser = await _authRepository.signIn(
        email: email,
        password: password,
      );
    } on FirebaseAuthMultiFactorException catch (error) {
      pendingSecondFactorResolver = error.resolver;
    } catch (error) {
      errorMessage = mapAuthException(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearPendingSecondFactorChallenge() {
    pendingSecondFactorResolver = null;
    notifyListeners();
  }

  void clearPendingSecondFactorResolver() {
    clearPendingSecondFactorChallenge();
  }

  Future<void> signUp({
    /// Cria uma conta nova e armazena o usuário resultante no estado do app.
    required String fullName,
    required String cpf,
    required String phone,
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentUser = await _authRepository.signUp(
        fullName: fullName,
        cpf: cpf,
        phone: phone,
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
    /// Encerra a sessão atual e limpa o usuário mantido em memória.
    await _authRepository.signOut();
    currentUser = null;
    notifyListeners();
  }

  Future<bool> sendPasswordResetEmail({required String email}) async {
    /// Solicita o envio do e-mail de recuperação e informa se a operação concluiu.
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
