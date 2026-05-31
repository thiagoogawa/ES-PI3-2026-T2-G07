/// Thiago Ryuji Ogawa - RA:24024450
///
/// Tela de selecao de startup administrada.
/// Permite escolher qual startup sera gerenciada quando o usuario
/// possui responsabilidade sobre mais de uma empresa.

import 'package:flutter/material.dart';

import '../../domain/entities/authenticated_user.dart';
import '../widgets/logout_flow.dart';
import 'admin_home_page.dart';

class AdminStartupSelectionPage extends StatelessWidget {
  final AuthenticatedUser user;

  const AdminStartupSelectionPage({super.key, required this.user});

  Future<void> _signOut(BuildContext context) async {
    await performLogoutFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final startups = user.managedStartups;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AdminWelcomeCard(user: user),
                          const SizedBox(height: 24),
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
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163153), Color(0xFF2E6CBC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 12),
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
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Escolha qual startup deseja gerenciar neste momento.',
            style: TextStyle(
              color: Color(0xFFE2ECFF),
              fontSize: 14,
              height: 1.6,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121720),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Startups administradas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Acesse rapidamente o painel da startup que deseja atualizar agora.',
            style: TextStyle(
              color: Color(0xFF9FA8B7),
              height: 1.6,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          ...startups.map(
            (startup) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
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
                    color: const Color(0xFF0F141C),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF18375A), Color(0xFF2D64AE)],
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
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF151C25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFFDCE6F8),
                          size: 18,
                        ),
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
        color: const Color(0xFF151C25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFD7E1F2),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
