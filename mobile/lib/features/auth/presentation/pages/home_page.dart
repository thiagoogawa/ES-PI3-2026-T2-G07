import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../data/datasources/auth_api_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/profile_storage_datasource.dart';
import '../../../startups/data/datasources/startups_api_datasource.dart';
import '../../../startups/data/datasources/startup_trading_api_datasource.dart';
import '../../../startups/data/models/startup_portfolio_snapshot_model.dart';
import '../../../startups/domain/entities/startup.dart';
import '../../../startups/presentation/pages/startup_detail_page.dart';
import '../../../startups/presentation/pages/trading_page.dart';
import 'login_page.dart';
import '../../../startups/presentation/pages/portfolio_page.dart';

class HomePage extends StatefulWidget {
  final AuthenticatedUser user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final StartupsApiDataSource _startupsApiDataSource;
  AuthApiDataSource? _authApiDataSource;
  StartupTradingApiDataSource? _startupTradingApiDataSource;
  AuthRemoteDataSource? _authRemoteDataSource;
  late Future<List<Startup>> _startupsFuture;

  // FIX: inicializado diretamente para evitar null race na aba Portfólio
  late Future<StartupPortfolioSnapshotModel> _portfolioFuture;

  AuthenticatedUser? _currentUser;
  int _selectedIndex = 0;
  bool _isRefreshingProfile = false;
  bool _isPortfolioBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _startupsApiDataSource = StartupsApiDataSource(ApiClient());
    _startupsFuture = _startupsApiDataSource.fetchStartups();
    _portfolioFuture = _fetchPortfolio();
    _refreshProfile();
  }

  // ── Getters lazy ──────────────────────────────────────────────────────────

  AuthApiDataSource get _authApi {
    return _authApiDataSource ??= AuthApiDataSource(ApiClient());
  }

  StartupTradingApiDataSource get _tradingApi {
    return _startupTradingApiDataSource ??=
        StartupTradingApiDataSource(ApiClient());
  }

  AuthRemoteDataSource get _authRemote {
    return _authRemoteDataSource ??= AuthRemoteDataSource();
  }

  AuthenticatedUser get _activeUser => _currentUser ?? widget.user;

  // ── Ações ─────────────────────────────────────────────────────────────────

  Future<void> _refreshProfile({bool showFeedback = false}) async {
    if (_isRefreshingProfile) return;

    if (mounted) {
      setState(() => _isRefreshingProfile = true);
    }

    try {
      final idToken = await _authRemote.getIdToken(forceRefresh: true);
      final user = await _authApi.fetchMe(idToken);

      if (!mounted) return;

      setState(() => _currentUser = user);

      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado.')),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível atualizar o perfil: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshingProfile = false);
      }
    }
  }

  Future<void> _openEditProfilePage() async {
    final updatedUser = await Navigator.of(context).push<AuthenticatedUser>(
      MaterialPageRoute(
        builder: (_) => _EditProfilePage(user: _activeUser),
      ),
    );

    if (updatedUser == null || !mounted) return;

    setState(() => _currentUser = updatedUser);
  }

  Future<StartupPortfolioSnapshotModel> _fetchPortfolio() async {
    final idToken = await _authRemote.getIdToken();
    return _tradingApi.fetchPortfolio(idToken);
  }

  Future<void> _reloadStartups() async {
    final future = _startupsApiDataSource.fetchStartups();

    if (mounted) {
      setState(() => _startupsFuture = future);
    }

    await future;
  }

  Future<void> _reloadHomeData() async {
    final startupsFuture = _startupsApiDataSource.fetchStartups();
    final portfolioFuture = _fetchPortfolio();

    if (mounted) {
      setState(() {
        _startupsFuture = startupsFuture;
        _portfolioFuture = portfolioFuture;
      });
    }

    // FIX: eagerError: false — uma falha não descarta a outra
    final results = await Future.wait(
      [startupsFuture, portfolioFuture],
      eagerError: false,
    ).catchError((_) => <Object?>[null, null]);

    if (!mounted) return;

    // Exibe snackbar apenas se ambas falharam
    if (results.every((r) => r == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível recarregar os dados.'),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ── Helpers de texto ──────────────────────────────────────────────────────

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _displayName() {
    final name = _activeUser.name?.trim();
    if (name != null && name.isNotEmpty) return name.split(' ').first;

    final email = _activeUser.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;

    return 'Investidor';
  }

  String _initials() {
    final source = _activeUser.name?.trim().isNotEmpty == true
        ? _activeUser.name!.trim()
        : _displayName();
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  double _portfolioWealth(StartupPortfolioSnapshotModel portfolio) {
    final holdingsValue = portfolio.positions.fold<double>(
      0,
      (sum, position) =>
          sum +
          (position.currentValue > 0
              ? position.currentValue
              : position.investedAmount),
    );
    return portfolio.balance + portfolio.reservedBalance + holdingsValue;
  }

  // ── Navegação ─────────────────────────────────────────────────────────────

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
      // Atualiza portfólio ao entrar nas abas Home e Portfólio
      if (index == 0 || index == 3) {
        _portfolioFuture = _fetchPortfolio();
      }
    });
  }

  Future<void> _openStartupDetails(Startup startup) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StartupDetailPage(startup: startup)),
    );

    if (!mounted) return;

    setState(() {
      _portfolioFuture = _fetchPortfolio();
      _startupsFuture = _startupsApiDataSource.fetchStartups();
    });
  }

  // ── Widgets de UI ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedIndex = 4),
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4E5A74),
            ),
            child: _ProfileAvatar(
              picture: _activeUser.picture,
              initials: _initials(),
              size: 44,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()},',
                style: const TextStyle(
                  color: Color(0xFFCACDD7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _displayName(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          tooltip: 'Sair',
        ),
      ],
    );
  }

  Widget _buildPortfolioSummary(StartupPortfolioSnapshotModel portfolio) {
    final wealthLabel = _isPortfolioBalanceVisible
        ? FormatUtils.currency(_portfolioWealth(portfolio))
        : 'R\$ ••••••';
    final availableLabel = _isPortfolioBalanceVisible
        ? FormatUtils.currency(portfolio.balance)
        : 'R\$ ••••••';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF111214),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF21242B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Patrimônio',
                style: TextStyle(
                  color: Color(0xFFB7BCC8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() {
                  _isPortfolioBalanceVisible = !_isPortfolioBalanceVisible;
                }),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: _isPortfolioBalanceVisible
                    ? 'Ocultar valores'
                    : 'Mostrar valores',
                icon: Icon(
                  _isPortfolioBalanceVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFFB7BCC8),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            wealthLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Disponível para investir: $availableLabel',
            style: const TextStyle(color: Color(0xFFD2D6DE), fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSummarySection() {
    return FutureBuilder<StartupPortfolioSnapshotModel>(
      future: _portfolioFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111214),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF21242B)),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF4E91F3)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111214),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF21242B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Não foi possível carregar o patrimônio.',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Text(
                  '${snapshot.error}',
                  style: const TextStyle(
                    color: Color(0xFFB7BCC8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _reloadHomeData,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF4A4D56)),
                  ),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        return _buildPortfolioSummary(snapshot.data!);
      },
    );
  }

  Widget _buildStartupCard(Startup startup) {
    final sectorLabel = startup.sector?.trim().isNotEmpty == true
        ? startup.sector!
        : startup.stage;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openStartupDetails(startup),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF32353E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF204D96),
                      border: Border.all(color: const Color(0xFF5E9CFF)),
                    ),
                    child: Center(
                      child: Text(
                        startup.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    startup.dailyVariation >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: FormatUtils.variationColor(startup.dailyVariation),
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                FormatUtils.percent(startup.dailyVariation),
                style: TextStyle(
                  color: FormatUtils.variationColor(startup.dailyVariation),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                startup.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sectorLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB7BCC8),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                FormatUtils.currency(startup.currentPrice),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Capital captado: ${FormatUtils.currency(startup.capitalRaised)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9398A6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExploreTab(List<Startup> startups) {
    return RefreshIndicator(
      onRefresh: _reloadStartups,
      color: const Color(0xFF4E91F3),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: startups.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) return _buildHeader();

          if (index == 1) {
            return const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                'Explorar Startups',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final startup = startups[index - 2];
          final sectorLabel = startup.sector?.trim().isNotEmpty == true
              ? startup.sector!
              : startup.stage;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openStartupDetails(startup),
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF32353E)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF204D96),
                      ),
                      child: Center(
                        child: Text(
                          startup.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            startup.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sectorLabel,
                            style: const TextStyle(
                              color: Color(0xFFB7BCC8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          FormatUtils.currency(startup.currentPrice),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          FormatUtils.percent(startup.dailyVariation),
                          style: TextStyle(
                            color: FormatUtils.variationColor(
                              startup.dailyVariation,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E323A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9398A6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconBackground = const Color(0xFF1A1C20),
    Color iconColor = const Color(0xFF84B5FF),
    Color? borderColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF151618),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor ?? const Color(0xFF2A2E36)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9398A6),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF6E7581),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final emailStatus =
        _activeUser.emailVerified ? 'Verificado' : 'Não verificado';
    final profileName = _activeUser.name?.trim().isNotEmpty == true
        ? _activeUser.name!.trim()
        : _displayName();
    final cpfValue = _activeUser.cpf?.trim().isNotEmpty == true
        ? FormatUtils.cpf(_activeUser.cpf!)
        : 'Cadastro incompleto';
    final phoneValue = _activeUser.phone?.trim().isNotEmpty == true
        ? _activeUser.phone!
        : 'Não informado';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF151618),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2A2E36)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF17191D), Color(0xFF11141A)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4C5B80),
                      border: Border.all(color: const Color(0xFF7586B3)),
                    ),
                    child: _ProfileAvatar(
                      picture: _activeUser.picture,
                      initials: _initials(),
                      size: 72,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _activeUser.email ?? '-',
                          style: const TextStyle(
                            color: Color(0xFFB7BCC8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Seu centro de conta e identidade no Mescla Invest.',
                          style: TextStyle(
                            color: Color(0xFF9398A6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildProfileBadge('Status', emailStatus),
                  _buildProfileBadge('CPF', cpfValue),
                  _buildProfileBadge('Telefone', phoneValue),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openEditProfilePage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF346AC0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar dados'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Conta',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        _buildProfileActionTile(
          icon: Icons.badge_rounded,
          title: 'Dados cadastrais',
          subtitle: '$cpfValue  •  $phoneValue',
          onTap: _openEditProfilePage,
        ),
        const SizedBox(height: 12),
        _buildProfileActionTile(
          icon: Icons.shield_outlined,
          title: 'Acesso e segurança',
          subtitle:
              '${_activeUser.email ?? '-'}  •  $emailStatus',
          onTap: () => _refreshProfile(showFeedback: true),
          iconBackground: const Color(0xFF17212F),
        ),
        const SizedBox(height: 12),
        _buildProfileActionTile(
          icon: Icons.sync_rounded,
          title: 'Sincronizar perfil',
          subtitle: _isRefreshingProfile
              ? 'Atualizando dados do servidor...'
              : 'Recarregue os dados mais recentes da sua conta.',
          onTap: _isRefreshingProfile
              ? () {}
              : () => _refreshProfile(showFeedback: true),
          iconBackground: const Color(0xFF1C2330),
        ),
        const SizedBox(height: 22),
        const Text(
          'Sessão',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        _buildProfileActionTile(
          icon: Icons.logout_rounded,
          title: 'Sair da conta',
          subtitle: 'Encerrar a sessão do dispositivo atual.',
          onTap: _handleLogout,
          iconBackground: const Color(0x33FF7A8B),
          iconColor: const Color(0xFFFFA2AE),
          borderColor: const Color(0xFF3A2830),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCatalog(List<Startup> startups) {
    if (startups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              'Nenhuma startup encontrada.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _reloadHomeData,
      color: const Color(0xFF4E91F3),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
          SliverToBoxAdapter(child: _buildPortfolioSummarySection()),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
          const SliverToBoxAdapter(
            child: Text(
              'Acompanhe as Startups',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildStartupCard(startups[index]),
              childCount: startups.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildSelectedBody(List<Startup> startups) {
    switch (_selectedIndex) {
      case 0:
        return _buildCatalog(startups);
      case 1:
        return _buildExploreTab(startups);
      case 2:
        return TradingPage(startups: startups);
      case 3:
        return PortfolioPage(portfolioFuture: _portfolioFuture);
      case 4:
        return _buildProfileTab();
      default:
        return _buildCatalog(startups);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        height: 68,
        backgroundColor: const Color(0xFF1A1B1E),
        indicatorColor: const Color(0xFF264E90),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.candlestick_chart_outlined),
            selectedIcon: Icon(Icons.candlestick_chart_rounded),
            label: 'Negociar',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Portfólio',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: FutureBuilder<List<Startup>>(
            future: _startupsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4E91F3)),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Não foi possível carregar as startups.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Color(0xFFB7BCC8)),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _reloadStartups,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF346AC0),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                );
              }

              return _buildSelectedBody(snapshot.data ?? const []);
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EditProfilePage
// ─────────────────────────────────────────────────────────────────────────────
class _EditProfilePage extends StatefulWidget {
  final AuthenticatedUser user;

  const _EditProfilePage({required this.user});

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  final AuthApiDataSource _authApi = AuthApiDataSource(ApiClient());
  final AuthRemoteDataSource _authRemote = AuthRemoteDataSource();
  final ProfileStorageDataSource _profileStorage = ProfileStorageDataSource();
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _cpfController;
  late final TextEditingController _phoneController;

  // FIX: controller do e-mail declarado como campo e descartado em dispose()
  late final TextEditingController _emailController;

  String? _picture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.user.name ?? '');
    _cpfController =
        TextEditingController(text: FormatUtils.cpf(widget.user.cpf));
    _phoneController =
        TextEditingController(text: widget.user.phone ?? '');

    // FIX: criado aqui e descartado em dispose — sem memory leak
    _emailController =
        TextEditingController(text: widget.user.email ?? '-');

    _picture = widget.user.picture;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _phoneController.dispose();
    _emailController.dispose(); // FIX: descarte correto
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uint8List? _decodePendingPicture(String? value) {
    if (value == null || value.trim().isEmpty || value.startsWith('http')) {
      return null;
    }
    try {
      return base64Decode(value.trim());
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolvePictureForSave() async {
    final value = _picture?.trim();

    if (value == null) return null;

    if (value.isEmpty) {
      await _profileStorage.deleteUserIcon(uid: widget.user.uid);
      return '';
    }

    if (value.startsWith('http')) return value;

    final bytes = _decodePendingPicture(value);
    if (bytes == null) throw Exception('Imagem de perfil inválida.');

    return _profileStorage.uploadUserIcon(
      uid: widget.user.uid,
      bytes: bytes,
    );
  }

  Future<void> _pickProfilePicture() async {
    try {
      FocusScope.of(context).unfocus();

      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
        requestFullMetadata: false,
      );

      if (pickedFile == null || !mounted) return;

      final bytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      setState(() => _picture = base64Encode(bytes));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível abrir a galeria. '
            'Reinicie o app se acabou de instalar essa função. '
            'Erro: $error',
          ),
        ),
      );
    }
  }

  void _removeProfilePicture() => setState(() => _picture = '');

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final idToken = await _authRemote.getIdToken(forceRefresh: true);
      final picture = await _resolvePictureForSave();
      final updatedUser = await _authApi.updateProfile(
        idToken,
        name: _nameController.text.trim(),
        cpf: FormatUtils.digitsOnly(_cpfController.text),
        phone: _phoneController.text.trim(),
        picture: picture,
      );

      if (!mounted) return;

      Navigator.of(context).pop(updatedUser);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar perfil: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    String? helper,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8F96A3), fontSize: 12),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(
            helper,
            style: const TextStyle(
              color: Color(0xFF646B78),
              fontSize: 11,
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1C20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2E323A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2E323A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4E91F3)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF7A8B)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF7A8B)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.user.name?.trim().isNotEmpty == true
        ? widget.user.name!.trim()
        : widget.user.email?.split('@').first ?? 'Investidor';
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F10),
        foregroundColor: Colors.white,
        title: const Text('Editar perfil'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            // ── Foto de perfil ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF151618),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2A2E36)),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF17191D), Color(0xFF11141A)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF4C5B80),
                          border:
                              Border.all(color: const Color(0xFF7586B3)),
                        ),
                        child: _ProfileAvatar(
                          picture: _picture,
                          initials: initials,
                          size: 72,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.user.email ?? '-',
                              style: const TextStyle(
                                color: Color(0xFFB7BCC8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Atualize seus dados para manter o cadastro '
                              'consistente na plataforma.',
                              style: TextStyle(
                                color: Color(0xFF9398A6),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickProfilePicture,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFF4E91F3),
                            ),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Escolher foto'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed:
                            (_picture == null || _picture!.isEmpty)
                                ? null
                                : _removeProfilePicture,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFA2AE),
                          side: const BorderSide(
                            color: Color(0xFF3A2830),
                          ),
                          minimumSize: const Size(52, 46),
                        ),
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Formulário ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF151618),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2A2E36)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dados pessoais',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Edite apenas as informações que deseja atualizar.',
                      style: TextStyle(
                        color: Color(0xFFB7BCC8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildInput(
                      label: 'Nome completo',
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe seu nome.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildInput(
                      label: 'CPF',
                      controller: _cpfController,
                      keyboardType: TextInputType.number,
                      helper: '11 dígitos.',
                      validator: (value) {
                        // FIX: valida dígitos verificadores do CPF
                        final digits = FormatUtils.digitsOnly(value);
                        if (!FormatUtils.isValidCpf(digits)) {
                          return 'CPF inválido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildInput(
                      label: 'Telefone',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      helper: 'DDD + número.',
                      validator: (value) {
                        if (FormatUtils.digitsOnly(value).length < 10) {
                          return 'Telefone inválido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // FIX: usa _emailController declarado no state
                    _buildInput(
                      label: 'E-mail',
                      controller: _emailController,
                      readOnly: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF346AC0),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label:
                    Text(_isSaving ? 'Salvando...' : 'Salvar alterações'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProfileAvatar
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileAvatar extends StatelessWidget {
  final String? picture;
  final String initials;
  final double size;
  final double fontSize;

  const _ProfileAvatar({
    required this.picture,
    required this.initials,
    required this.size,
    required this.fontSize,
  });

  Uint8List? _decodeProfilePicture(String? value) {
    if (value == null || value.trim().isEmpty || value.startsWith('http')) {
      return null;
    }
    try {
      return base64Decode(value.trim());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeProfilePicture(picture);

    if (bytes != null) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (picture != null && picture!.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          picture!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
