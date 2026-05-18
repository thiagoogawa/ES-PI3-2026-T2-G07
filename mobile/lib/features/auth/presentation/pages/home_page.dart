import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/user_friendly_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../data/datasources/auth_api_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../widgets/logout_flow.dart';
import '../../data/datasources/profile_storage_datasource.dart';
import '../../../startups/data/datasources/startups_api_datasource.dart';
import '../../../startups/data/datasources/startup_trading_api_datasource.dart';
import '../../../startups/data/models/startup_portfolio_snapshot_model.dart';
import '../../../startups/domain/entities/startup.dart';
import '../../../startups/presentation/pages/startup_detail_page.dart';
import '../../../startups/presentation/pages/trading_page.dart';
import '../../../startups/presentation/widgets/startup_logo.dart';

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
  bool _isRefreshingProfile = false;
  bool _isPortfolioBalanceVisible = true;

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
        showAppSnackBar(
          context,
          message: 'Perfil atualizado.',
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel atualizar o perfil agora.',
        ),
        type: AppSnackBarType.error,
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

  Future<void> _handleLogout() async {
    await performLogoutFlow(context);
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

  Future<void> _openPortfolioActions(
    StartupPortfolioSnapshotModel portfolio,
  ) async {
    final action = await showModalBottomSheet<_PortfolioAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF17191D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3E46),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Gerenciar patrimonio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Saldo disponivel: ${_formatCurrency(portfolio.balance)}',
                  style: const TextStyle(
                    color: Color(0xFFB7BCC8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                _buildProfileActionTile(
                  icon: Icons.add_card_rounded,
                  title: 'Adicionar saldo',
                  subtitle: 'Credita saldo ficticio para novas negociacoes.',
                  onTap: () =>
                      Navigator.of(context).pop(_PortfolioAction.deposit),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _PortfolioAction.deposit:
        await _openDepositAmountPage();
        break;
    }
  }

  Future<void> _openDepositAmountPage() async {
    final amount = await Navigator.of(context).push<double>(
      MaterialPageRoute(builder: (_) => const _DepositAmountPage()),
    );

    if (amount == null || !mounted) {
      return;
    }

    try {
      final idToken = await _authRemote.getIdToken(forceRefresh: true);
      final updatedPortfolio = await _tradingApi.depositBalance(
        idToken,
        amount: amount,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _portfolioFuture = Future.value(updatedPortfolio);
      });

      showAppSnackBar(
        context,
        message: 'Saldo adicionado com sucesso.',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel adicionar saldo agora.',
        ),
        type: AppSnackBarType.error,
      );
    }
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
      if (index == 0 || index == 3) {
        _portfolioFuture = _fetchPortfolio();
      }
    });
  }

  Future<void> _openStartupDetails(Startup startup) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StartupDetailPage(startup: startup)),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _portfolioFuture = _fetchPortfolio();
      _startupsFuture = _startupsApiDataSource.fetchStartups();
    });
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
    final wealthLabel = _isPortfolioBalanceVisible
        ? _formatCurrency(_portfolioWealth(portfolio))
        : 'R\$ ••••••';
    final availableBalanceLabel = _isPortfolioBalanceVisible
        ? _formatCurrency(portfolio.balance)
        : 'R\$ ••••••';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPortfolioActions(portfolio),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
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
                    'Patrimonio',
                    style: TextStyle(
                      color: Color(0xFFB7BCC8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isPortfolioBalanceVisible =
                            !_isPortfolioBalanceVisible;
                      });
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
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
                  const Spacer(),
                  const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF6E7581),
                    size: 20,
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
                'Disponivel para investir: $availableBalanceLabel',
                style: const TextStyle(color: Color(0xFFD2D6DE), fontSize: 15),
              ),
            ],
          ),
        ),
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
                  mapUserFriendlyError(
                    snapshot.error!,
                    fallbackMessage:
                        'Verifique sua conexao e tente carregar novamente.',
                  ),
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
    final validPositions = portfolio.positions
        .where((position) => position.quantity > 0)
        .toList();
    final slices = _buildPortfolioSlices(
      StartupPortfolioSnapshotModel(
        userId: portfolio.userId,
        balance: portfolio.balance,
        reservedBalance: portfolio.reservedBalance,
        totalInvested: portfolio.totalInvested,
        currentValue: portfolio.currentValue,
        profitLoss: portfolio.profitLoss,
        positions: validPositions,
      ),
    );
    return _PortfolioDistributionCard(slices: slices);
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
                  mapUserFriendlyError(
                    snapshot.error!,
                    fallbackMessage:
                        'Nao foi possivel carregar o portfolio agora.',
                  ),
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
        final validPositions = portfolio.positions
            .where((position) => position.quantity > 0)
            .toList();

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeader(),
            const SizedBox(height: 28),
            if (validPositions.isEmpty)
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
            if (validPositions.isNotEmpty) ...[
              _buildPortfolioDistributionSection(
                StartupPortfolioSnapshotModel(
                  userId: portfolio.userId,
                  balance: portfolio.balance,
                  reservedBalance: portfolio.reservedBalance,
                  totalInvested: portfolio.totalInvested,
                  currentValue: portfolio.currentValue,
                  profitLoss: portfolio.profitLoss,
                  positions: validPositions,
                ),
              ),
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
              for (final position in validPositions) ...[
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
                  StartupLogo(
                    name: startup.name,
                    photoUrl: startup.photoUrl,
                    size: 38,
                    fontSize: 17,
                    backgroundColor: const Color(0xFF204D96),
                    borderColor: const Color(0xFF5E9CFF),
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
                    StartupLogo(
                      name: startup.name,
                      photoUrl: startup.photoUrl,
                      size: 46,
                      fontSize: 20,
                      backgroundColor: const Color(0xFF204D96),
                      borderColor: const Color(0xFF204D96),
                      borderWidth: 0,
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
                        mapUserFriendlyError(
                          snapshot.error!,
                          fallbackMessage:
                              'Nao foi possivel carregar as startups agora.',
                        ),
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

  List<Color> get gradientColors {
    return [
      Color.lerp(color, Colors.white, 0.18) ?? color,
      color,
      Color.lerp(color, const Color(0xFF05070B), 0.28) ?? color,
    ];
  }

  Color get glowColor => Color.lerp(color, Colors.white, 0.08) ?? color;
}

class _PortfolioDistributionCard extends StatelessWidget {
  final List<_PortfolioSlice> slices;

  const _PortfolioDistributionCard({required this.slices});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF171A21), Color(0xFF101319)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF2A3140), width: 0.9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6606070A),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Distribuicao das posicoes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Participacao de cada ativo na carteira atual.',
                      style: TextStyle(
                        color: Color(0xFF98A1B2),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF11151C),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF273140)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      size: 15,
                      color: Color(0xFF8FB8FF),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Carteira',
                      style: TextStyle(
                        color: Color(0xFFD6DEEA),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Center(child: _PortfolioPieChart(slices: slices)),
          const SizedBox(height: 20),
          _PortfolioLegendGrid(slices: slices),
        ],
      ),
    );
  }
}

class _PortfolioLegendGrid extends StatelessWidget {
  final List<_PortfolioSlice> slices;

  const _PortfolioLegendGrid({required this.slices});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth > 420
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: slices
              .map(
                (slice) => SizedBox(
                  width: itemWidth,
                  child: _PortfolioLegendCard(slice: slice),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _PortfolioLegendCard extends StatelessWidget {
  final _PortfolioSlice slice;

  const _PortfolioLegendCard({required this.slice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF12161D), Color(0xFF0E1117)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF263041), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: slice.gradientColors),
                  boxShadow: [
                    BoxShadow(
                      color: slice.glowColor.withValues(alpha: 0.38),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${slice.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: slice.glowColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Investido',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _PortfolioPieChartState._formatCurrency(slice.investedAmount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioPieChart extends StatefulWidget {
  final List<_PortfolioSlice> slices;

  const _PortfolioPieChart({required this.slices});

  @override
  State<_PortfolioPieChart> createState() => _PortfolioPieChartState();
}

class _PortfolioPieChartState extends State<_PortfolioPieChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  bool _isCenterSelected = false;
  late final AnimationController _animationController;
  late final Animation<double> _revealAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _revealAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color get _activeAccentColor {
    if (_isCenterSelected) {
      return const Color(0xFF84B5FF);
    }

    if (_selectedIndex == null) {
      return const Color(0xFF5C6472);
    }

    return widget.slices[_selectedIndex!].color;
  }

  void _handlePointer(Offset localPosition, Size size) {
    final hitTarget = _hitTestTarget(localPosition, size);
    final selectedIndex = hitTarget.$1;
    final isCenterSelected = hitTarget.$2;

    if (selectedIndex == _selectedIndex &&
        isCenterSelected == _isCenterSelected) {
      return;
    }

    setState(() {
      _selectedIndex = selectedIndex;
      _isCenterSelected = isCenterSelected;
    });
  }

  (int?, bool) _hitTestTarget(Offset position, Size size) {
    final total = widget.slices.fold<double>(
      0,
      (sum, slice) => sum + slice.value,
    );
    if (total <= 0) {
      return (null, false);
    }

    final center = Offset(size.width / 2, size.height / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final radius = math.min(size.width, size.height) / 2;
    final innerRadius = radius * 0.42;

    if (distance < innerRadius) {
      return (null, true);
    }

    if (distance > radius) {
      return (null, false);
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
        return (index, false);
      }
      startAngle = endAngle;
    }

    return widget.slices.isEmpty
        ? (null, false)
        : (widget.slices.length - 1, false);
  }

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    final selectedSlice = _selectedIndex == null
        ? null
        : slices[_selectedIndex!];
    const minChartSize = 198.0;
    const maxChartSize = 324.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartVisualSize = constraints.maxWidth
            .clamp(minChartSize, maxChartSize)
            .toDouble();
        final glassSize = chartVisualSize * 0.42;

        return AnimatedBuilder(
          animation: _revealAnimation,
          builder: (context, child) {
            final fadeValue = _revealAnimation.value;

            return Opacity(
              opacity: fadeValue,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - fadeValue)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTapDown: (details) => _handlePointer(
                        details.localPosition,
                        Size.square(chartVisualSize),
                      ),
                      child: SizedBox(
                        width: chartVisualSize,
                        height: chartVisualSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _activeAccentColor.withValues(alpha: 0.20),
                                    _activeAccentColor.withValues(alpha: 0.06),
                                    const Color(0x00101319),
                                  ],
                                  stops: const [0.12, 0.48, 1],
                                ),
                              ),
                              child: SizedBox(
                                width: chartVisualSize,
                                height: chartVisualSize,
                              ),
                            ),
                            Container(
                              width: chartVisualSize * 0.90,
                              height: chartVisualSize * 0.90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _activeAccentColor.withValues(
                                      alpha: 0.16,
                                    ),
                                    blurRadius: 34,
                                    spreadRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 36,
                                    offset: const Offset(0, 18),
                                  ),
                                ],
                              ),
                            ),
                            CustomPaint(
                              size: Size.square(chartVisualSize),
                              painter: _PortfolioPieChartPainter(
                                slices: slices,
                                selectedIndex: _selectedIndex,
                                progress: _revealAnimation.value,
                              ),
                            ),
                            ClipOval(
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 18,
                                  sigmaY: 18,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: glassSize,
                                  height: glassSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.14),
                                        const Color(
                                          0xFF161B24,
                                        ).withValues(alpha: 0.82),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: _activeAccentColor.withValues(
                                        alpha: 0.34,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.16,
                                        ),
                                        blurRadius: 22,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Ativos',
                                        style: TextStyle(
                                          color: Color(0xFF9BA5B6),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${slices.length}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          height: 1,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _PortfolioChartInfoCard(
                        key: ValueKey(
                          _isCenterSelected
                              ? 'center'
                              : selectedSlice?.label ?? 'portfolio-hint',
                        ),
                        accentColor: _activeAccentColor,
                        selectedSlice: selectedSlice,
                        isCenterSelected: _isCenterSelected,
                        total: total,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
}

class _PortfolioPieChartPainter extends CustomPainter {
  final List<_PortfolioSlice> slices;
  final int? selectedIndex;
  final double progress;

  const _PortfolioPieChartPainter({
    required this.slices,
    required this.selectedIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final ringWidth = radius * 0.28;
    final baseRadius = radius - (ringWidth / 2);

    if (total <= 0) {
      final fallbackPaint = Paint()..color = const Color(0xFF1E222A);
      canvas.drawCircle(center, radius, fallbackPaint);
      return;
    }

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [Color(0xFF171C24), Color(0xFF11151C), Color(0xFF171C24)],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius));

    canvas.drawCircle(center, baseRadius, trackPaint);

    var startAngle = -math.pi / 2;
    const gapAngle = 0.06;

    for (var index = 0; index < slices.length; index++) {
      final slice = slices[index];
      final sweepAngle = (slice.value / total) * math.pi * 2;
      final isSelected = selectedIndex == index;
      final arcRadius = isSelected ? baseRadius + 3 : baseRadius;
      final arcStroke = isSelected ? ringWidth + 5 : ringWidth;
      final adjustedStart = startAngle + gapAngle / 2;
      final adjustedSweep = math.max(0.0, (sweepAngle - gapAngle) * progress);
      final rect = Rect.fromCircle(center: center, radius: arcRadius);
      final sliceGradient = SweepGradient(
        startAngle: adjustedStart,
        endAngle: adjustedStart + adjustedSweep,
        colors: slice.gradientColors,
      );
      final shadowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcStroke + 8
        ..strokeCap = StrokeCap.round
        ..color = slice.glowColor.withValues(alpha: isSelected ? 0.34 : 0.14);
      final highlightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, arcStroke * 0.18)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: isSelected ? 0.24 : 0.12);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcStroke
        ..strokeCap = StrokeCap.round
        ..shader = sliceGradient.createShader(rect);

      canvas.drawArc(rect, adjustedStart, adjustedSweep, false, shadowPaint);
      canvas.drawArc(rect, adjustedStart, adjustedSweep, false, paint);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcRadius - (arcStroke * 0.12)),
        adjustedStart,
        adjustedSweep * 0.72,
        false,
        highlightPaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PortfolioPieChartPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.progress != progress;
  }
}

class _PortfolioChartInfoCard extends StatelessWidget {
  final _PortfolioSlice? selectedSlice;
  final bool isCenterSelected;
  final double total;
  final Color accentColor;

  const _PortfolioChartInfoCard({
    super.key,
    required this.selectedSlice,
    required this.isCenterSelected,
    required this.total,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final title = isCenterSelected
        ? 'Total da carteira distribuida'
        : selectedSlice?.label ?? 'Toque para explorar';
    final subtitle = isCenterSelected
        ? 'Veja o valor total alocado nas posicoes exibidas.'
        : selectedSlice == null
        ? 'Pressione uma fatia para ver quanto foi investido ou toque no centro para ver o total.'
        : 'Investido ${_PortfolioPieChartState._formatCurrency(selectedSlice!.investedAmount)}';
    final icon = isCenterSelected
        ? Icons.pie_chart_rounded
        : selectedSlice == null
        ? Icons.touch_app_rounded
        : Icons.show_chart_rounded;
    final displayColor = selectedSlice?.color ?? accentColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF121720), Color(0xFF0D1118)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  displayColor.withValues(alpha: 0.24),
                  displayColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: displayColor.withValues(alpha: 0.34)),
            ),
            child: Icon(icon, color: displayColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isCenterSelected) ...[
                  const SizedBox(height: 8),
                  Text(
                    total > 0
                        ? _PortfolioPieChartState._formatCurrency(total)
                        : 'R\$ 0,00',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
  final ProfileStorageDataSource _profileStorage = ProfileStorageDataSource();
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
    if (value == null) {
      return '';
    }

    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _formatCpf(String? value) {
    final digits = _digitsOnly(value);
    if (digits.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (var index = 0; index < digits.length && index < 11; index++) {
      buffer.write(digits[index]);
      if (index == 2 || index == 5) {
        buffer.write('.');
      } else if (index == 8) {
        buffer.write('-');
      }
    }

    return buffer.toString();
  }

  Uint8List? _decodePendingPicture(String? value) {
    if (value == null || value.isEmpty) {
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

    if (value == null) {
      return null;
    }

    if (value.isEmpty) {
      await _profileStorage.deleteUserIcon(uid: widget.user.uid);
      return '';
    }

    if (value.startsWith('http')) {
      return value;
    }

    final bytes = _decodePendingPicture(value);
    if (bytes == null) {
      throw Exception('Imagem de perfil invalida.');
    }

    return _profileStorage.uploadUserIcon(uid: widget.user.uid, bytes: bytes);
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

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel abrir a galeria agora.',
        ),
        type: AppSnackBarType.error,
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
      final picture = await _resolvePictureForSave();
      final updatedUser = await _authApi.updateProfile(
        idToken,
        name: _nameController.text.trim(),
        cpf: _digitsOnly(_cpfController.text),
        phone: _phoneController.text.trim(),
        picture: picture,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedUser);
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel salvar o perfil agora.',
        ),
        type: AppSnackBarType.error,
      );
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

enum _PortfolioAction { deposit }

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
                    hintStyle: const TextStyle(color: Color(0xFF8B909C)),
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
