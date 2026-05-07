import 'package:flutter/material.dart';

import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/authenticated_user.dart';
import 'admin_home_page.dart';
import 'login_page.dart';

class AdminStartupSelectionPage extends StatelessWidget {
  final AuthenticatedUser user;

  const AdminStartupSelectionPage({super.key, required this.user});

  Future<void> _signOut(BuildContext context) async {
    await AuthRemoteDataSource().signOut();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final startups = user.managedStartups;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1115),
        foregroundColor: Colors.white,
        title: const Text('Selecionar startup'),
        actions: [
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: startups.isEmpty
          ? const _AdminSelectionEmptyState()
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _StartupSelectionCard(user: user, startups: startups),
                ),
              ),
            ),
    );
  }
}

class _StartupSelectionCard extends StatelessWidget {
  final AuthenticatedUser user;
  final List<ManagedStartup> startups;

  const _StartupSelectionCard({required this.user, required this.startups});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12335D), Color(0xFF1D6DC8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 32,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ola, ${user.name ?? 'Admin'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Escolha qual startup voce quer administrar.',
            style: TextStyle(
              color: Color(0xFFDCEAFF),
              height: 1.6,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          ...startups.map(
            (startup) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminHomePage(user: user, startup: startup),
                    ),
                  );
                },
                child: Ink(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0x2210161C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x55DCEAFF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: const Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              startup.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              startup.sector?.isNotEmpty == true
                                  ? '${startup.stage} • ${startup.sector}'
                                  : startup.stage,
                              style: const TextStyle(
                                color: Color(0xFFDCEAFF),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSelectionEmptyState extends StatelessWidget {
  const _AdminSelectionEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.storefront_outlined, color: Color(0xFF84B5FF), size: 42),
            SizedBox(height: 16),
            Text(
              'Nenhuma startup vinculada a este admin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Associe o usuario a uma startup com o campo adminUid ou admin.uid no backend.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB7BCC8), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
