import 'package:flutter/material.dart';

import '../../../../core/errors/user_friendly_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/startup_trading_api_datasource.dart';
import '../../data/models/startup_portfolio_snapshot_model.dart';
import '../../domain/entities/startup.dart';
import 'startup_trade_page.dart';

class TradingPage extends StatefulWidget {
  final List<Startup> startups;

  const TradingPage({super.key, required this.startups});

  @override
  State<TradingPage> createState() => _TradingPageState();
}

class _TradingPageState extends State<TradingPage> {
  late final StartupTradingApiDataSource _startupTradingApiDataSource;
  late final AuthRemoteDataSource _authRemoteDataSource;
  late final TextEditingController _searchController;
  Future<StartupPortfolioSnapshotModel>? _portfolioFuture;
  String _searchQuery = '';
  String _selectedStage = 'all';

  @override
  void initState() {
    super.initState();
    _startupTradingApiDataSource = StartupTradingApiDataSource(ApiClient());
    _authRemoteDataSource = AuthRemoteDataSource();
    _searchController = TextEditingController();
    _portfolioFuture = _loadPortfolio();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<StartupPortfolioSnapshotModel> _loadPortfolio() async {
    final idToken = await _authRemoteDataSource.getIdToken();
    return _startupTradingApiDataSource.fetchPortfolio(idToken);
  }

  Future<void> _reload() async {
    final future = _loadPortfolio();
    setState(() {
      _portfolioFuture = future;
    });

    await future;
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

  List<Startup> _filteredStartups() {
    return widget.startups.where((startup) {
      final matchesQuery =
          _searchQuery.isEmpty ||
          startup.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          startup.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (startup.sector?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
      final matchesStage =
          _selectedStage == 'all' ||
          startup.stage.toLowerCase() == _selectedStage.toLowerCase();
      return matchesQuery && matchesStage;
    }).toList();
  }

  List<String> _availableStages() {
    final stages =
        widget.startups
            .map((startup) => startup.stage.trim())
            .where((stage) => stage.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['all', ...stages];
  }

  Future<void> _openFilterSheet() async {
    final stages = _availableStages();
    final chosenStage = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrar startups',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stages.map((stage) {
                  final isSelected = stage == _selectedStage;
                  final label = stage == 'all' ? 'Todos' : stage;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => Navigator.of(context).pop(stage),
                    selectedColor: const Color(0xFF264E90),
                    backgroundColor: const Color(0xFF1B1D22),
                    side: const BorderSide(color: Color(0xFF2B3038)),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFB7BCC8),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );

    if (chosenStage == null || !mounted) {
      return;
    }

    setState(() {
      _selectedStage = chosenStage;
    });
  }

  Future<void> _openTradingStartup(Startup startup) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StartupTradePage(startup: startup)),
    );

    if (!mounted) {
      return;
    }

    await _reload();
  }

  Widget _buildStartupMarketCard(
    Startup startup,
    StartupPortfolioSnapshotModel portfolio,
  ) {
    final position = portfolio.positionForStartup(startup.id);

    return InkWell(
      onTap: () => _openTradingStartup(startup),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141517),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2B3038)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E2837),
                    border: Border.all(color: const Color(0xFF32435D)),
                  ),
                  child: Center(
                    child: Text(
                      startup.name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_outward_rounded,
                  color: const Color(0xFF8F96A3),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              startup.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              startup.sector ?? startup.stage,
              style: const TextStyle(color: Color(0xFFB7BCC8), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              '${startup.dailyVariation >= 0 ? '+' : ''}${startup.dailyVariation.toStringAsFixed(2).replaceAll('.', ',')}%',
              style: TextStyle(
                color: _variationColor(startup.dailyVariation),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              _formatCurrency(startup.currentPrice),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Seus tokens: ${_formatQuantity(position?.quantity ?? 0)}',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketSection(StartupPortfolioSnapshotModel portfolio) {
    final filteredStartups = _filteredStartups();

    if (filteredStartups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(
          child: Text(
            'Nenhuma startup encontrada para esse filtro.',
            style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
          ),
        ),
      );
    }

    return GridView.builder(
      itemCount: filteredStartups.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) {
        return _buildStartupMarketCard(filteredStartups[index], portfolio);
      },
    );
  }

  Widget _buildContent(StartupPortfolioSnapshotModel portfolio) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFF4E91F3),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Negociar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Busque startups e filtre o mercado.',
                      style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF121316),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2B3038)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Buscar startups',
                      hintStyle: TextStyle(color: Color(0xFF7D8594)),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _openFilterSheet,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121316),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2B3038)),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Mercado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Escolha uma startup para abrir uma mesa de negociacao dedicada.',
            style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
          ),
          const SizedBox(height: 18),
          if (_selectedStage != 'all')
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text('Filtro: $_selectedStage'),
                    labelStyle: const TextStyle(color: Colors.white),
                    backgroundColor: const Color(0xFF264E90),
                    side: BorderSide.none,
                    deleteIconColor: Colors.white,
                    onDeleted: () {
                      setState(() {
                        _selectedStage = 'all';
                      });
                    },
                  ),
                ],
              ),
            ),
          _buildMarketSection(portfolio),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              'Cadastre ou carregue startups para negociar.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      );
    }

    return FutureBuilder<StartupPortfolioSnapshotModel>(
      future: _portfolioFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4E91F3)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nao foi possivel carregar o mercado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mapUserFriendlyError(
                      snapshot.error!,
                      fallbackMessage:
                          'Nao foi possivel carregar o mercado agora.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB7BCC8)),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _reload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF346AC0),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildContent(snapshot.data!);
      },
    );
  }
}
