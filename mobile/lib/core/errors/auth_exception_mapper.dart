/// Thiago Ryuji Ogawa - RA:24024450
///
/// Componente compartilhado de tratamento de erros no mobile.
/// Agrupa excecoes de dominio e mapeadores que convertem falhas
/// tecnicas em mensagens adequadas para a interface.

import 'package:firebase_auth/firebase_auth.dart';
import 'app_exception.dart';

String mapAuthException(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'requires-recent-login':
        return 'Confirme sua senha novamente para concluir esta operacao.';

      case 'invalid-verification-code':
        return 'O codigo SMS informado e invalido.';

      case 'invalid-verification-id':
      case 'session-expired':
        return 'A verificacao expirou. Solicite um novo codigo.';

      case 'missing-verification-code':
        return 'Digite o codigo enviado por SMS.';

      case 'multi-factor-auth-required':
      case 'second-factor-required':
        return 'Confirme o segundo fator para entrar.';

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

      case 'quota-exceeded':
        return 'O limite de SMS foi atingido. Tente novamente mais tarde.';

      case 'network-request-failed':
        return 'Falha de conexao. Verifique sua internet.';

      default:
        return 'Nao foi possivel concluir a autenticacao. Tente novamente.';
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
