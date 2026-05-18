import 'app_exception.dart';
import 'auth_exception_mapper.dart';

String mapUserFriendlyError(
  Object error, {
  String fallbackMessage = 'Ocorreu um problema. Tente novamente.',
}) {
  final normalized = error.toString().toLowerCase();

  if (normalized.contains('firebaseauthexception')) {
    return mapAuthException(error);
  }

  if (error is AppException) {
    return _mapAppExceptionMessage(error.message, fallbackMessage);
  }

  if (normalized.contains('network') ||
      normalized.contains('connection') ||
      normalized.contains('socket') ||
      normalized.contains('timed out') ||
      normalized.contains('timeout') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('xmlhttprequest')) {
    return 'Erro de conexao. Verifique sua internet e tente novamente.';
  }

  if (normalized.contains('permission') ||
      normalized.contains('unauthorized')) {
    return 'Voce nao tem permissao para concluir esta acao.';
  }

  if (normalized.contains('invalid image') ||
      normalized.contains('imagem de perfil invalida')) {
    return 'A imagem selecionada nao e valida. Tente outra foto.';
  }

  return fallbackMessage;
}

String _mapAppExceptionMessage(String message, String fallbackMessage) {
  final normalized = message.toLowerCase();

  if (normalized.contains('network') ||
      normalized.contains('connection') ||
      normalized.contains('timeout')) {
    return 'Erro de conexao. Verifique sua internet e tente novamente.';
  }

  if (normalized.contains('unable to get firebase id token')) {
    return 'Sua sessao expirou. Entre novamente para continuar.';
  }

  if (normalized.contains('not found')) {
    return 'Nao encontramos os dados solicitados.';
  }

  if (normalized.contains('permission') ||
      normalized.contains('unauthorized')) {
    return 'Voce nao tem permissao para concluir esta acao.';
  }

  if (normalized.contains('already exists') ||
      normalized.contains('already in use')) {
    return 'Esses dados ja estao em uso. Revise e tente novamente.';
  }

  return fallbackMessage;
}
