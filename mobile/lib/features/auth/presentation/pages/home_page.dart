import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../data/datasources/auth_api_datasource.dart';
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
  AuthApiDataSource? _authApiDataSource;
  StartupTradingApiDataSource? _startupTradingApiDataSource;
  AuthRemoteDataSource? _authRemoteDataSource;
  late Future<List<Startup>> _startupsFuture;
  Future<StartupPortfolioSnapshotModel>? _portfolioFuture;
  AuthenticatedUser? _currentUser;
  int _selectedIndex = 0;
  bool _isDepositing = false;
  bool _isRefreshingProfile = false;

  static const List<Color> _portfolioChartColors = [
    Color(0xFF295AA5),
    Color(0xFF1F7668),
    Color(0xFF9A6630),
    Color(0xFF784292),
    Color(0xFF9B4150),
    Color(0xFF3A648D),
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _startupsApiDataSource = StartupsApiDataSource(ApiClient());
    _startupsFuture = _startupsApiDataSource.fetchStartups();
    _portfolioFuture = _fetchPortfolio();
    _refreshProfile();
  }

  AuthApiDataSource get _authApi {
    return _authApiDataSource ??= AuthApiDataSource(ApiClient());
  }

  StartupTradingApiDataSource get _tradingApi {
    return _startupTradingApiDataSource ??= StartupTradingApiDataSource(
      ApiClient(),
    );
  }

  AuthRemoteDataSource get _authRemote {
    return _authRemoteDataSource ??= AuthRemoteDataSource();
  }

  AuthenticatedUser get _activeUser {
    return _currentUser ?? widget.user;
  }

  Future<void> _refreshProfile({bool showFeedback = false}) async {
    if (_isRefreshingProfile) {
      return;
    }

    if (mounted) {
      setState(() {
        _isRefreshingProfile = true;
      });
    }

    try {
      final idToken = await _authRemote.getIdToken(forceRefresh: true);
      final user = await _authApi.fetchMe(idToken);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = user;
      });

      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel atualizar o perfil: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingProfile = false;
        });
      }
    }
  }

  Future<void> _openEditProfilePage() async {
    final updatedUser = await Navigator.of(context).push<AuthenticatedUser>(
      MaterialPageRoute(builder: (_) => _EditProfilePage(user: _activeUser)),
    );

    if (updatedUser == null || !mounted) {
      return;
    }

    setState(() {
      _currentUser = updatedUser;
    });
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
    final name = _activeUser.name?.trim();

    if (name != null && name.isNotEmpty) {
      return name.split(' ').first;
    }

    final email = _activeUser.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Investidor';
  }

  String _initials() {
    final source = _activeUser.name?.trim().isNotEmpty == true
        ? _activeUser.name!.trim()
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

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  Color _variationColor(double value) {
    if (value < 0) {
      return const Color(0xFFFF7A8B);
    }

    return const Color(0xFF84B5FF);
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _formatCpf(String value) {
    final digits = _digitsOnly(value);
    if (digits.length != 11) {
      return value;
    }

    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
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
            style: const TextStyle(color: Color(0xFF9398A6), fontSize: 11),
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
        Container(
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

  Widget _buildPortfolioPositionCard(StartupPortfolioPositionModel position) {
    final profitLossColor = _variationColor(position.profitLoss);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A2E36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  position.startupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatCurrency(position.currentValue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildPortfolioMetricChip(
                'Tokens',
                _formatQuantity(position.quantity),
              ),
              _buildPortfolioMetricChip(
                'Preco medio',
                _formatCurrency(position.averagePrice),
              ),
              _buildPortfolioMetricChip(
                'Preco atual',
                _formatCurrency(position.currentPrice),
              ),
              _buildPortfolioMetricChip(
                'Investido',
                _formatCurrency(position.investedAmount),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Resultado: ${_formatCurrency(position.profitLoss)}',
            style: TextStyle(
              color: profitLossColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioMetricChip(String label, String value) {
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
            style: const TextStyle(color: Color(0xFF9398A6), fontSize: 11),
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

  double _portfolioAllocationValue(StartupPortfolioPositionModel position) {
    if (position.currentValue > 0) {
      return position.currentValue;
    }

    if (position.investedAmount > 0) {
      return position.investedAmount;
    }

    return position.quantity;
  }

  List<_PortfolioSlice> _buildPortfolioSlices(
    StartupPortfolioSnapshotModel portfolio,
  ) {
    final positions = [...portfolio.positions]
      ..sort((left, right) {
        return _portfolioAllocationValue(
          right,
        ).compareTo(_portfolioAllocationValue(left));
      });

    final total = positions.fold<double>(
      0,
      (sum, position) => sum + _portfolioAllocationValue(position),
    );

    return positions.asMap().entries.map((entry) {
      final index = entry.key;
      final position = entry.value;
      final value = _portfolioAllocationValue(position);

      return _PortfolioSlice(
        label: position.startupName,
        value: value,
        investedAmount: position.investedAmount,
        percentage: total > 0 ? (value / total) * 100 : 0,
        color: _portfolioChartColors[index % _portfolioChartColors.length],
      );
    }).toList();
  }

  Widget _buildPortfolioDistributionSection(
    StartupPortfolioSnapshotModel portfolio,
  ) {
    final slices = _buildPortfolioSlices(portfolio);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151618),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2E36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribuicao das posicoes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Participacao de cada ativo na carteira atual.',
            style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 13),
          ),
          const SizedBox(height: 18),
          Center(child: _PortfolioPieChart(slices: slices)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101216),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF272C35)),
            ),
            child: Column(
              children: [
                for (final slice in slices) ...[
                  _buildPortfolioLegendItem(slice),
                  if (slice != slices.last) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioLegendItem(_PortfolioSlice slice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16191F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2F39)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: slice.color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${slice.percentage.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Color(0xFFB7BCC8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioTab() {
    return FutureBuilder<StartupPortfolioSnapshotModel>(
      future: _portfolioRequest(),
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
                  'Nao foi possivel carregar o portfolio.',
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
                  onPressed: () {
                    setState(() {
                      _portfolioFuture = _fetchPortfolio();
                    });
                  },
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

        final portfolio = snapshot.data!;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeader(),
            const SizedBox(height: 28),
            if (portfolio.positions.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2A2E36)),
                ),
                child: const Text(
                  'Voce ainda nao possui tokens em carteira. Compre uma startup para ver suas posicoes aqui.',
                  style: TextStyle(
                    color: Color(0xFFB7BCC8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            if (portfolio.positions.isNotEmpty) ...[
              _buildPortfolioDistributionSection(portfolio),
              const SizedBox(height: 22),
              const Text(
                'Posicoes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              for (final position in portfolio.positions) ...[
                _buildPortfolioPositionCard(position),
                const SizedBox(height: 12),
              ],
            ],
            const SizedBox(height: 24),
          ],
        );
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
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
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

  Widget _buildProfileTab() {
    final emailStatus = _activeUser.emailVerified
        ? 'Verificado'
        : 'Nao verificado';
    final profileName = _activeUser.name?.trim().isNotEmpty == true
        ? _activeUser.name!.trim()
        : _displayName();
    final cpfValue = _activeUser.cpf?.trim().isNotEmpty == true
        ? _formatCpf(_activeUser.cpf!)
        : 'Cadastro incompleto';
    final phoneValue = _activeUser.phone?.trim().isNotEmpty == true
        ? _activeUser.phone!
        : 'Nao informado';

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
                        Text(
                          'Seu centro de conta e identidade no Mescla Invest.',
                          style: const TextStyle(
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
          title: 'Acesso e seguranca',
          subtitle: '${_activeUser.email ?? '-'}  •  $emailStatus',
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
          'Sessao',
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
          subtitle: 'Encerrar a sessao do dispositivo atual.',
          onTap: _handleLogout,
          iconBackground: const Color(0x33FF7A8B),
          iconColor: const Color(0xFFFFA2AE),
          borderColor: const Color(0xFF3A2830),
        ),
        const SizedBox(height: 24),
      ],
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
        return _buildPortfolioTab();
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

class _PortfolioSlice {
  final String label;
  final double value;
  final double investedAmount;
  final double percentage;
  final Color color;

  const _PortfolioSlice({
    required this.label,
    required this.value,
    required this.investedAmount,
    required this.percentage,
    required this.color,
  });
}

class _PortfolioPieChart extends StatefulWidget {
  final List<_PortfolioSlice> slices;

  const _PortfolioPieChart({required this.slices});

  @override
  State<_PortfolioPieChart> createState() => _PortfolioPieChartState();
}

class _PortfolioPieChartState extends State<_PortfolioPieChart> {
  int? _selectedIndex;

  void _handlePointer(Offset localPosition, Size size) {
    final selectedIndex = _hitTestSlice(localPosition, size);
    if (selectedIndex == _selectedIndex) {
      return;
    }

    setState(() {
      _selectedIndex = selectedIndex;
    });
  }

  void _clearSelection() {
    if (_selectedIndex == null) {
      return;
    }

    setState(() {
      _selectedIndex = null;
    });
  }

  int? _hitTestSlice(Offset position, Size size) {
    final total = widget.slices.fold<double>(
      0,
      (sum, slice) => sum + slice.value,
    );
    if (total <= 0) {
      return null;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final radius = math.min(size.width, size.height) / 2;
    final innerRadius = radius * 0.42;

    if (distance < innerRadius || distance > radius) {
      return null;
    }

    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) {
      angle += math.pi * 2;
    }

    var startAngle = 0.0;
    for (var index = 0; index < widget.slices.length; index++) {
      final sweepAngle = (widget.slices[index].value / total) * math.pi * 2;
      final endAngle = startAngle + sweepAngle;
      if (angle >= startAngle && angle < endAngle) {
        return index;
      }
      startAngle = endAngle;
    }

    return widget.slices.isEmpty ? null : widget.slices.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    final selectedSlice = _selectedIndex == null
        ? null
        : slices[_selectedIndex!];
    const chartSize = 208.0;

    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: (details) => _handlePointer(
              details.localPosition,
              const Size.square(chartSize),
            ),
            onTapUp: (_) => _clearSelection(),
            onTapCancel: _clearSelection,
            onPanDown: (details) => _handlePointer(
              details.localPosition,
              const Size.square(chartSize),
            ),
            onPanUpdate: (details) => _handlePointer(
              details.localPosition,
              const Size.square(chartSize),
            ),
            onPanEnd: (_) => _clearSelection(),
            child: SizedBox(
              width: chartSize,
              height: chartSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(chartSize),
                    painter: _PortfolioPieChartPainter(
                      slices: slices,
                      selectedIndex: _selectedIndex,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Ativos',
                        style: TextStyle(
                          color: Color(0xFF8F96A3),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${slices.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        total > 0
                            ? 'Total ${_formatCompactCurrency(total)}'
                            : '-',
                        style: const TextStyle(
                          color: Color(0xFFB7BCC8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Container(
              key: ValueKey(selectedSlice?.label ?? 'portfolio-hint'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF101216),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2F39)),
              ),
              child: selectedSlice == null
                  ? const Text(
                      'Pressione uma fatia para ver quanto foi investido.',
                      style: TextStyle(
                        color: Color(0xFF97A0AE),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedSlice.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Investido ${_formatCurrency(selectedSlice.investedAmount)}',
                          style: const TextStyle(
                            color: Color(0xFFD2D6DE),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCurrency(double value) {
    final normalized = value.isFinite ? value : 0;
    final fixed = normalized.toStringAsFixed(2);
    final parts = fixed.split('.');
    final chars = parts.first.split('');
    final buffer = StringBuffer();

    for (var index = 0; index < chars.length; index++) {
      final reverseIndex = chars.length - index;
      buffer.write(chars[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},${parts[1]}';
  }

  static String _formatCompactCurrency(double value) {
    final fixed = value.toStringAsFixed(0);
    final chars = fixed.split('');
    final buffer = StringBuffer();

    for (var index = 0; index < chars.length; index++) {
      final reverseIndex = chars.length - index;
      buffer.write(chars[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()}';
  }
}

class _PortfolioPieChartPainter extends CustomPainter {
  final List<_PortfolioSlice> slices;
  final int? selectedIndex;

  const _PortfolioPieChartPainter({
    required this.slices,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final separatorPaint = Paint()
      ..color = const Color(0xFF0F0F10)
      ..strokeWidth = 2;

    if (total <= 0) {
      final fallbackPaint = Paint()..color = const Color(0xFF1E222A);
      canvas.drawCircle(center, radius, fallbackPaint);
      return;
    }

    var startAngle = -math.pi / 2;

    for (var index = 0; index < slices.length; index++) {
      final slice = slices[index];
      final sweepAngle = (slice.value / total) * math.pi * 2;
      final isSelected = selectedIndex == index;
      final outerRadius = isSelected ? radius + 6 : radius;
      final rect = Rect.fromCircle(center: center, radius: outerRadius);
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = isSelected
            ? Color.lerp(slice.color, Colors.white, 0.12) ?? slice.color
            : slice.color;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle, sweepAngle, false)
        ..close();

      canvas.drawPath(path, paint);
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(startAngle) * outerRadius,
          center.dy + math.sin(startAngle) * outerRadius,
        ),
        separatorPaint,
      );

      startAngle += sweepAngle;
    }

    final centerPaint = Paint()..color = const Color(0xFF151618);
    canvas.drawCircle(center, radius * 0.42, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _PortfolioPieChartPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _EditProfilePage extends StatefulWidget {
  final AuthenticatedUser user;

  const _EditProfilePage({required this.user});

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  final AuthApiDataSource _authApi = AuthApiDataSource(ApiClient());
  final AuthRemoteDataSource _authRemote = AuthRemoteDataSource();
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cpfController;
  late final TextEditingController _phoneController;
  String? _picture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name ?? '');
    _cpfController = TextEditingController(text: _formatCpf(widget.user.cpf));
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _picture = widget.user.picture;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _digitsOnly(String? value) {
    return (value ?? '').replaceAll(RegExp(r'\D'), '');
  }

  String _formatCpf(String? value) {
    final digits = _digitsOnly(value);
    if (digits.length != 11) {
      return value ?? '';
    }

    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
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

      if (pickedFile == null || !mounted) {
        return;
      }

      final bytes = await pickedFile.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _picture = base64Encode(bytes);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nao foi possivel abrir a galeria. Reinicie o app se acabou de instalar essa funcao. Erro: $error',
          ),
        ),
      );
    }
  }

  void _removeProfilePicture() {
    setState(() {
      _picture = '';
    });
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate() || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final idToken = await _authRemote.getIdToken(forceRefresh: true);
      final updatedUser = await _authApi.updateProfile(
        idToken,
        name: _nameController.text.trim(),
        cpf: _digitsOnly(_cpfController.text),
        phone: _phoneController.text.trim(),
        picture: _picture,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedUser);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar perfil: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

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
            style: const TextStyle(color: Color(0xFF646B78), fontSize: 11),
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
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
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
                          border: Border.all(color: const Color(0xFF7586B3)),
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
                              'Atualize seus dados para manter o cadastro consistente na plataforma.',
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
                            side: const BorderSide(color: Color(0xFF4E91F3)),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Escolher foto'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: (_picture == null || _picture!.isEmpty)
                            ? null
                            : _removeProfilePicture,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFA2AE),
                          side: const BorderSide(color: Color(0xFF3A2830)),
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
                      'Edite apenas as informacoes que deseja atualizar.',
                      style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 13),
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
                      helper: '11 digitos.',
                      validator: (value) {
                        if (_digitsOnly(value).length != 11) {
                          return 'CPF invalido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildInput(
                      label: 'Telefone',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      helper: 'DDD + numero.',
                      validator: (value) {
                        if (_digitsOnly(value).length < 10) {
                          return 'Telefone invalido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildInput(
                      label: 'E-mail',
                      controller: TextEditingController(
                        text: widget.user.email ?? '-',
                      ),
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
                label: Text(_isSaving ? 'Salvando...' : 'Salvar alteracoes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          errorBuilder: (context, error, stackTrace) => Center(
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
