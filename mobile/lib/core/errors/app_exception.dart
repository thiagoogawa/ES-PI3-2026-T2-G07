/// Thiago Ryuji Ogawa - RA:24024450
///
/// Componente compartilhado de tratamento de erros no mobile.
/// Agrupa excecoes de dominio e mapeadores que convertem falhas
/// tecnicas em mensagens adequadas para a interface.

class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() => message;
}
