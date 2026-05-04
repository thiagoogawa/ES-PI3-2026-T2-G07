class AuthenticatedUser {
  final String uid;
  final String? email;
  final bool emailVerified;
  final String? name;
  final String? cpf;
  final String? phone;
  final String? picture;
  final String? provider;

  const AuthenticatedUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.name,
    required this.cpf,
    required this.phone,
    required this.picture,
    required this.provider,
  });
}
