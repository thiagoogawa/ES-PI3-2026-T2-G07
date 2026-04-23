import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../../startups/data/datasources/startups_api_datasource.dart';
import '../../../startups/data/datasources/startup_trading_api_datasource.dart';
import '../../../startups/data/models/startup_portfolio_snapshot_model.dart';
import '../../../startups/domain/entities/startup.dart';
import '../../../startups/presentation/pages/startup_detail_page.dart';
import '../../../startups/presentation/pages/trading_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  final AuthenticatedUser user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final StartupsApiDataSource _startupsApiDataSource;
  StartupTradingApiDataSource? _startupTradingApiDataSource;
  AuthRemoteDataSource? _authRemoteDataSource;
  late Future<List<Startup>> _startupsFuture;
  Future<StartupPortfolioSnapshotModel>? _portfolioFuture;
  int _selectedIndex = 0;
  bool _isDepositing = false;

  @override
  void initState() {
    super.initState();
    _startupsApiDataSource = StartupsApiDataSource(ApiClient());
    _startupsFuture = _startupsApiDataSource.fetchStartups();
    _portfolioFuture = _fetchPortfolio();
  }

  StartupTradingApiDataSource get _tradingApi {
    return _startupTradingApiDataSource ??= StartupTradingApiDataSource(
      ApiClient(),
    );
  }

  AuthRemoteDataSource get _authRemote {
    return _authRemoteDataSource ??= AuthRemoteDataSource();
  }

  Future<StartupPortfolioSnapshotModel> _fetchPortfolio() async {
    final idToken = await _authRemote.getIdToken();
    return _tradingApi.fetchPortfolio(idToken);
  }

  Future<StartupPortfolioSnapshotModel> _portfolioRequest() {
    return _portfolioFuture ??= _fetchPortfolio();
  }

  Future<void> _reloadStartups() async {
    final future = _startupsApiDataSource.fetchStartups();

    if (mounted) {
      setState(() {
        _startupsFuture = future;
      });
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

    await Future.wait([startupsFuture, portfolioFuture]);
  }

  Future<double?> _openDepositSheet() async {
    return Navigator.of(context).push<double>(
      MaterialPageRoute(builder: (_) => const _DepositAmountPage()),
    );
  }

  Future<void> _simulateDeposit() async {
    if (_isDepositing) {
      return;
    }

    final amount = await _openDepositSheet();
    if (amount == null) {
      return;
    }

    setState(() {
      _isDepositing = true;
    });

    try {
      final idToken = await _authRemote.getIdToken();
      final portfolio = await _tradingApi.simulateDeposit(
        idToken,
        amount: amount,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _portfolioFuture = Future.value(portfolio);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saldo ficticio adicionado: ${_formatCurrency(amount)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isDepositing = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Bom dia';
    }

    if (hour < 18) {
      return 'Boa tarde';
    }

    return 'Boa noite';
  }

  String _displayName() {
    final name = widget.user.name?.trim();

    if (name != null && name.isNotEmpty) {
      return name.split(' ').first;
    }

    final email = widget.user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Investidor';
  }

  String _initials() {
    final source = widget.user.name?.trim().isNotEmpty == true
        ? widget.user.name!.trim()
        : _displayName();
    final parts = source.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);

    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  String _formatCurrency(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts[0];
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      final reverseIndex = digits.length - index;
      buffer.write(digits[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},${parts[1]}';
  }

  String _formatPercent(double value) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2).replaceAll('.', ',')}%';
  }

  Color _variationColor(double value) {
    if (value < 0) {
      return const Color(0xFFFF7A8B);
    }

    return const Color(0xFF84B5FF);
  }

  double _portfolioWealth(StartupPortfolioSnapshotModel portfolio) {
    return portfolio.balance +
        portfolio.reservedBalance +
        portfolio.currentValue;
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _openStartupDetails(Startup startup) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StartupDetailPage(startup: startup)),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF4E5A74),
          child: Text(
            _initials(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
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
                style: const TextStyle(color: Color(0xFFCACDD7), fontSize: 13),
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
          const Text(
            'Patrimonio',
            style: TextStyle(
              color: Color(0xFFB7BCC8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrency(_portfolioWealth(portfolio)),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Disponivel para investir: ${_formatCurrency(portfolio.balance)}',
            style: const TextStyle(color: Color(0xFFD2D6DE), fontSize: 15),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isDepositing ? null : _simulateDeposit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B1D22),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF1B1D22),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isDepositing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_downward_rounded),
              label: Text(
                _isDepositing ? 'Depositando...' : 'Depositar',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSummarySection() {
    return FutureBuilder<StartupPortfolioSnapshotModel>(
      future: _portfolioRequest(),
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
                  'Nao foi possivel carregar o patrimonio.',
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
                    color: _variationColor(startup.dailyVariation),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatPercent(startup.dailyVariation),
                style: TextStyle(
                  color: _variationColor(startup.dailyVariation),
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
                style: const TextStyle(color: Color(0xFFB7BCC8), fontSize: 12),
              ),
              const Spacer(),
              Text(
                _formatCurrency(startup.currentPrice),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Capital captado: ${_formatCurrency(startup.capitalRaised)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF9398A6), fontSize: 10),
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
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader();
          }

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
                          _formatCurrency(startup.currentPrice),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatPercent(startup.dailyVariation),
                          style: TextStyle(
                            color: _variationColor(startup.dailyVariation),
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

  Widget _buildPlaceholderTab({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildHeader(),
        const SizedBox(height: 48),
        Icon(icon, size: 54, color: const Color(0xFF5D95F0)),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB7BCC8),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildHeader(),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF151618),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2A2E36)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _buildProfileRow('Nome', widget.user.name ?? _displayName()),
              _buildProfileRow('E-mail', widget.user.email ?? '-'),
              _buildProfileRow(
                'Status do e-mail',
                widget.user.emailVerified ? 'Verificado' : 'Nao verificado',
              ),
              _buildProfileRow('Provider', widget.user.provider ?? '-'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF346AC0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sair da conta'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8F96A3), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
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
        return _buildPlaceholderTab(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Portfolio',
          description:
              'Seu portfolio de tokens e o desempenho consolidado aparecerao nesta aba.',
        );
      case 4:
        return _buildProfileTab();
      default:
        return _buildCatalog(startups);
    }
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
            label: 'Portfolio',
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
                        'Nao foi possivel carregar as startups.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB7BCC8)),
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

class _DepositAmountPage extends StatefulWidget {
  const _DepositAmountPage();

  @override
  State<_DepositAmountPage> createState() => _DepositAmountPageState();
}

class _DepositAmountPageState extends State<_DepositAmountPage> {
  late final TextEditingController _amountController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = _amountController.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final amount = double.tryParse(normalized);

    if (amount == null || amount <= 0) {
      setState(() {
        _errorText = 'Informe um valor valido.';
      });
      return;
    }

    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F10),
        foregroundColor: Colors.white,
        title: const Text('Depositar saldo'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF17191D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF292D34)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Depositar saldo ficticio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Informe o valor que deseja adicionar ao saldo.',
                  style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Valor do deposito',
                    hintText: 'Ex.: 10000',
                    errorText: _errorText,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Confirmar deposito'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
