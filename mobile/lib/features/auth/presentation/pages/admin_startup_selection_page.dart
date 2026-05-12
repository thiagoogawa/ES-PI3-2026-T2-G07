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
      backgroundColor: const Color(0xFF09111F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          : Stack(
              children: [
                const _SelectionBackground(),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AdminWelcomeCard(user: user),
                          const SizedBox(height: 18),
                          _StartupListCard(user: user, startups: startups),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AdminWelcomeCard extends StatelessWidget {
  final AuthenticatedUser user;

  const _AdminWelcomeCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user.name?.trim().isNotEmpty == true
        ? user.name!.trim()
        : 'Administrador';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102746), Color(0xFF25579D), Color(0xFF2E7DDE)],
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
            'Ola, $displayName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupListCard extends StatelessWidget {
  final AuthenticatedUser user;
  final List<ManagedStartup> startups;

  const _StartupListCard({required this.user, required this.startups});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xCC101A2B),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
        border: Border.all(color: const Color(0xFF243145)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Startups administradas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Acesse rapidamente o painel da startup que deseja atualizar agora.',
            style: TextStyle(
              color: Color(0xFF9BA9BF),
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ...startups.map(
            (startup) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminHomePage(user: user, startup: startup),
                    ),
                  );
                },
                child: Ink(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1321),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF243145)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF163458), Color(0xFF27589C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
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
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _StartupMetaPill(label: startup.stage),
                                if (startup.sector?.isNotEmpty == true)
                                  _StartupMetaPill(label: startup.sector!),
                              ],
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

class _SelectionBackground extends StatelessWidget {
  const _SelectionBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x332E7DDE), Color(0x0009111F)],
                ),
              ),
            ),
          ),
          Positioned(
            left: -60,
            top: 260,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x2216B6C7), Color(0x0009111F)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupMetaPill extends StatelessWidget {
  final String label;

  const _StartupMetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF132238),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF294061)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFD7E6FF),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
