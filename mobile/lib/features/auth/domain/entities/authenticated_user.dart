class ManagedStartup {
  final String id;
  final String name;
  final String stage;
  final String? sector;

  const ManagedStartup({
    required this.id,
    required this.name,
    required this.stage,
    required this.sector,
  });
}

class AuthenticatedUser {
  final String uid;
  final String? email;
  final bool emailVerified;
  final String? name;
  final String? cpf;
  final String? phone;
  final String? picture;
  final String? provider;
  final bool mfaEnabled;
  final List<String> roles;
  final List<ManagedStartup> managedStartups;

  const AuthenticatedUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.name,
    required this.cpf,
    required this.phone,
    required this.picture,
    required this.provider,
    required this.mfaEnabled,
    required this.roles,
    required this.managedStartups,
  });

  bool get isStartupAdmin =>
      roles.contains('startupAdmin') || managedStartups.isNotEmpty;
}
