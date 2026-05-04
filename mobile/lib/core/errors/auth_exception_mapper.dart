import 'package:firebase_auth/firebase_auth.dart';
import 'app_exception.dart';

String mapAuthException(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'E-mail invalido.';

      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'E-mail ou senha incorretos.';

      case 'email-already-in-use':
        return 'Ja existe uma conta cadastrada com este e-mail.';

      case 'weak-password':
        return 'A senha informada e muito fraca.';

      case 'user-disabled':
        return 'Usuario desativado.';

      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em alguns minutos.';

      case 'network-request-failed':
        return 'Falha de conexao. Verifique sua internet.';

      default:
        return error.message ?? 'Falha ao autenticar no Firebase.';
    }
  }

  if (error is AppException) {
    return error.message;
  }

  final message = error.toString();
  if (message.startsWith('Exception: ')) {
    return message.substring('Exception: '.length);
  }

  return 'Ocorreu um erro inesperado ao fazer login.';
}
