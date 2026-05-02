import '../../domain/entities/authenticated_user.dart';

class AuthenticatedUserModel extends AuthenticatedUser {
  const AuthenticatedUserModel({
    required super.uid,
    required super.email,
    required super.emailVerified,
    required super.name,
    required super.cpf,
    required super.phone,
    required super.picture,
    required super.provider,
  });

  factory AuthenticatedUserModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    return AuthenticatedUserModel(
      uid: data['uid'] as String,
      email: data['email'] as String?,
      emailVerified: data['emailVerified'] as bool? ?? false,
      name: data['name'] as String?,
      cpf: data['cpf'] as String?,
      phone: data['phone'] as String?,
      picture: data['picture'] as String?,
      provider: data['provider'] as String?,
    );
  }
}
