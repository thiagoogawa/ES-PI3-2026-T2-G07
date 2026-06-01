/// Thiago Ryuji Ogawa - RA:24024450
///
/// Modelo de dados do modulo de autenticacao.
/// Responsavel por serializar e desserializar payloads trocados
/// entre as entidades de dominio e as fontes externas.

import '../../domain/entities/authenticated_user.dart';

class AuthenticatedUserModel extends AuthenticatedUser {
  const AuthenticatedUserModel({
    required super.uid,
    required super.email,
    required super.emailVerified,
    required super.mfaEnabled,
    required super.name,
    required super.cpf,
    required super.phone,
    required super.picture,
    required super.provider,
    required super.roles,
    required super.managedStartups,
  });

  factory AuthenticatedUserModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final account = data['account'] as Map<String, dynamic>? ?? const {};
    final roles = data['roles'] as List<dynamic>? ?? const [];
    final managedStartups =
        data['managedStartups'] as List<dynamic>? ?? const [];

    return AuthenticatedUserModel(
      uid: data['uid'] as String,
      email: data['email'] as String?,
      emailVerified: data['emailVerified'] as bool? ?? false,
      mfaEnabled: account['mfaEnabled'] as bool? ?? false,
      name: data['name'] as String?,
      cpf: data['cpf'] as String?,
      phone: data['phone'] as String?,
      picture: data['picture'] as String?,
      provider: data['provider'] as String?,
      roles: roles.whereType<String>().toList(),
      managedStartups: managedStartups
          .map((item) {
            final map = item as Map<String, dynamic>;
            return ManagedStartup(
              id: map['id'] as String? ?? '',
              name: map['name'] as String? ?? 'Startup',
              stage: map['stage'] as String? ?? 'Nao informado',
              sector: map['sector'] as String?,
            );
          })
          .where((startup) => startup.id.isNotEmpty)
          .toList(),
    );
  }
}
