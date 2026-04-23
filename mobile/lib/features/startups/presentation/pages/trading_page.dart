import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/startup_trading_api_datasource.dart';
import '../../data/models/startup_offer_model.dart';
import '../../data/models/startup_portfolio_snapshot_model.dart';
import '../../domain/entities/startup.dart';

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
  Startup? _selectedStartup;
  Future<_TradingViewData>? _screenFuture;
  bool _isSubmittingTrade = false;
  String? _busyOfferId;
  String _searchQuery = '';
  String _selectedStage = 'all';
  bool _showMarket = true;
  bool _showGrid = true;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _startupTradingApiDataSource = StartupTradingApiDataSource(apiClient);
    _authRemoteDataSource = AuthRemoteDataSource();
    _searchController = TextEditingController();
    if (widget.startups.isNotEmpty) {
      _selectedStartup = widget.startups.first;
      _screenFuture = _loadScreenData(widget.startups.first);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_TradingViewData> _loadScreenData(Startup startup) async {
    final idToken = await _authRemoteDataSource.getIdToken();
    final results = await Future.wait<dynamic>([
      _startupTradingApiDataSource.fetchOffers(startup.id),
      _startupTradingApiDataSource.fetchPortfolio(idToken),
    ]);

    return _TradingViewData(
      startup: startup,
      offers: results[0] as List<StartupOfferModel>,
      portfolio: results[1] as StartupPortfolioSnapshotModel,
    );
  }

  Future<void> _selectStartup(Startup startup) async {
    if (_selectedStartup?.id == startup.id && _screenFuture != null) {
      return;
    }

    final future = _loadScreenData(startup);

    setState(() {
      _selectedStartup = startup;
      _screenFuture = future;
    });

    await future;
  }

  Future<void> _reload() async {
    final startup = _selectedStartup;
    if (startup == null) {
      return;
    }

    final future = _loadScreenData(startup);
    setState(() {
      _screenFuture = future;
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

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month';
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

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151618),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E323A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8F96A3), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopInsightCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B3038)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 28),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final chosenStage = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF141517),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final stages = _availableStages();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrar startups',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
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

    final filtered = _filteredStartups();
    if (filtered.isEmpty) {
      return;
    }

    if (_selectedStartup == null ||
        !filtered.any((startup) => startup.id == _selectedStartup!.id)) {
      await _selectStartup(filtered.first);
    }
  }

  Future<void> _openTradeSheet(_TradingViewData viewData, String type) async {
    final draft = await showModalBottomSheet<_TradeDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141517),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final quantityController = TextEditingController(text: '1');
        final priceController = TextEditingController(
          text: viewData.startup.currentPrice.toStringAsFixed(2),
        );
        String? errorText;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type == 'buy' ? 'Comprar tokens' : 'Vender tokens',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A ordem tenta executar no balcao e deixa o restante aberto quando nao houver contraparte suficiente.',
                      style: const TextStyle(
                        color: Color(0xFFB7BCC8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de tokens',
                        labelStyle: TextStyle(color: Color(0xFFB7BCC8)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Preco limite por token',
                        labelStyle: TextStyle(color: Color(0xFFB7BCC8)),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Color(0xFFFF7A8B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final quantity = double.tryParse(
                            quantityController.text.replaceAll(',', '.'),
                          );
                          final pricePerToken = double.tryParse(
                            priceController.text.replaceAll(',', '.'),
                          );

                          if (quantity == null ||
                              pricePerToken == null ||
                              quantity <= 0 ||
                              pricePerToken <= 0) {
                            setModalState(() {
                              errorText = 'Informe quantidade e preco validos.';
                            });
                            return;
                          }

                          Navigator.of(context).pop(
                            _TradeDraft(
                              type: type,
                              quantity: quantity,
                              pricePerToken: pricePerToken,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: type == 'buy'
                              ? const Color(0xFF2E7DFF)
                              : const Color(0xFFFF7A8B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(
                          type == 'buy' ? 'Enviar compra' : 'Enviar venda',
                        ),
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

    if (draft == null || !mounted) {
      return;
    }

    await _submitTrade(viewData.startup, draft);
  }

  Future<void> _submitTrade(Startup startup, _TradeDraft draft) async {
    if (_isSubmittingTrade) {
      return;
    }

    setState(() {
      _isSubmittingTrade = true;
    });

    try {
      final idToken = await _authRemoteDataSource.getIdToken();
      final result = await _startupTradingApiDataSource.submitTrade(
        idToken,
        startupId: startup.id,
        type: draft.type,
        quantity: draft.quantity,
        pricePerToken: draft.pricePerToken,
      );

      if (!mounted) {
        return;
      }

      final message = StringBuffer();
      message.write(
        draft.type == 'buy'
            ? 'Ordem de compra enviada.'
            : 'Ordem de venda enviada.',
      );
      message.write(
        ' Executado: ${_formatQuantity(result.matchedQuantity)} token(s).',
      );
      if (result.remainingQuantity > 0) {
        message.write(
          ' Restante no book: ${_formatQuantity(result.remainingQuantity)}.',
        );
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message.toString())));
      await _reload();
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
          _isSubmittingTrade = false;
        });
      }
    }
  }

  Future<void> _acceptOffer(StartupOfferModel offer) async {
    if (_busyOfferId != null) {
      return;
    }

    final shouldAccept = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151618),
          title: Text(
            offer.type == 'sell'
                ? 'Comprar oferta aberta'
                : 'Vender para oferta',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            'Executar ${_formatQuantity(offer.remainingQuantity)} token(s) por ${_formatCurrency(offer.pricePerToken)} cada?',
            style: const TextStyle(color: Color(0xFFE6E8EE)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (shouldAccept != true || !mounted) {
      return;
    }

    setState(() {
      _busyOfferId = offer.id;
    });

    try {
      final idToken = await _authRemoteDataSource.getIdToken();
      final result = await _startupTradingApiDataSource.acceptOffer(
        idToken,
        offerId: offer.id,
        quantity: offer.remainingQuantity,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transacao executada: ${_formatQuantity(result.quantity)} token(s) em ${_formatCurrency(result.pricePerToken)}.',
          ),
        ),
      );
      await _reload();
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
          _busyOfferId = null;
        });
      }
    }
  }

  Widget _buildOfferCard(
    StartupOfferModel offer, {
    required String currentUserId,
    required String actionLabel,
  }) {
    final isOwnOffer = offer.userId == currentUserId;
    final isBusy = _busyOfferId == offer.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151618),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E323A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: offer.type == 'buy'
                      ? const Color(0x332E7DFF)
                      : const Color(0x33FF7A8B),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  offer.type == 'buy' ? 'Compra' : 'Venda',
                  style: TextStyle(
                    color: offer.type == 'buy'
                        ? const Color(0xFF84B5FF)
                        : const Color(0xFFFFA7B2),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(offer.createdAt),
                style: const TextStyle(color: Color(0xFF8F96A3), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Preco',
                  _formatCurrency(offer.pricePerToken),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Quantidade',
                  _formatQuantity(offer.remainingQuantity),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Investidor: ${offer.userName ?? 'Nao informado'}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Valor total: ${_formatCurrency(offer.totalValue)}',
            style: const TextStyle(color: Color(0xFFB7BCC8), fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isOwnOffer || isBusy
                  ? null
                  : () => _acceptOffer(offer),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF55606F)),
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(isOwnOffer ? 'Sua oferta aberta' : actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartupMarketCard(Startup startup, _TradingViewData viewData) {
    final isSelected = startup.id == viewData.startup.id;
    final position = viewData.portfolio.positionForStartup(startup.id);

    return InkWell(
      onTap: () => _selectStartup(startup),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF20242D) : const Color(0xFF141517),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : const Color(0xFF2B3038),
          ),
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
                    color: const Color(0xFF2A3340),
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
                const Spacer(),
                Text(
                  '${startup.dailyVariation >= 0 ? '+' : ''}${startup.dailyVariation.toStringAsFixed(2).replaceAll('.', ',')}%',
                  style: TextStyle(
                    color: _variationColor(startup.dailyVariation),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              startup.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              startup.sector ?? startup.stage,
              style: const TextStyle(color: Color(0xFFB7BCC8), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              _formatCurrency(startup.currentPrice),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seus tokens: ${_formatQuantity(position?.quantity ?? 0)}',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartupMarketList(Startup startup, _TradingViewData viewData) {
    final isSelected = startup.id == viewData.startup.id;
    final position = viewData.portfolio.positionForStartup(startup.id);

    return InkWell(
      onTap: () => _selectStartup(startup),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF20242D) : const Color(0xFF141517),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : const Color(0xFF2B3038),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2A3340),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    startup.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${startup.sector ?? startup.stage} • ${_formatCurrency(startup.currentPrice)}',
                    style: const TextStyle(
                      color: Color(0xFFB7BCC8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${startup.dailyVariation >= 0 ? '+' : ''}${startup.dailyVariation.toStringAsFixed(2).replaceAll('.', ',')}%',
                  style: TextStyle(
                    color: _variationColor(startup.dailyVariation),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tokens: ${_formatQuantity(position?.quantity ?? 0)}',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketSection(_TradingViewData viewData) {
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

    if (_showGrid) {
      return GridView.builder(
        itemCount: filteredStartups.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.86,
        ),
        itemBuilder: (context, index) {
          return _buildStartupMarketCard(filteredStartups[index], viewData);
        },
      );
    }

    return Column(
      children: filteredStartups
          .map((startup) => _buildStartupMarketList(startup, viewData))
          .toList(),
    );
  }

  Widget _buildTradingDesk(_TradingViewData viewData) {
    final startup = viewData.startup;
    final portfolio = viewData.portfolio;
    final position = portfolio.positionForStartup(startup.id);
    final openOffers = viewData.offers
        .where((offer) => offer.status == 'open' || offer.status == 'partial')
        .toList();
    final sellOffers = openOffers
        .where((offer) => offer.type == 'sell')
        .toList();
    final buyOffers = openOffers.where((offer) => offer.type == 'buy').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF151618),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF2E323A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          startup.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          startup.sector ?? startup.stage,
                          style: const TextStyle(
                            color: Color(0xFFD2E4FF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${startup.dailyVariation >= 0 ? '+' : ''}${startup.dailyVariation.toStringAsFixed(2).replaceAll('.', ',')}%',
                    style: TextStyle(
                      color: _variationColor(startup.dailyVariation),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Preco atual',
                      _formatCurrency(startup.currentPrice),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Seus tokens',
                      _formatQuantity(position?.quantity ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Saldo disponivel',
                      _formatCurrency(portfolio.balance),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Saldo reservado',
                      _formatCurrency(portfolio.reservedBalance),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmittingTrade
                          ? null
                          : () => _openTradeSheet(viewData, 'buy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7DFF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded),
                      label: const Text('Comprar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmittingTrade
                          ? null
                          : () => _openTradeSheet(viewData, 'sell'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB84B58),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.sell_rounded),
                      label: const Text('Vender'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Ofertas de venda',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (sellOffers.isEmpty)
          const Text(
            'Nenhuma oferta de venda aberta para esta startup.',
            style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
          )
        else
          ...sellOffers.map(
            (offer) => _buildOfferCard(
              offer,
              currentUserId: portfolio.userId,
              actionLabel: 'Comprar esta oferta',
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Ofertas de compra',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (buyOffers.isEmpty)
          const Text(
            'Nenhuma oferta de compra aberta para esta startup.',
            style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
          )
        else
          ...buyOffers.map(
            (offer) => _buildOfferCard(
              offer,
              currentUserId: portfolio.userId,
              actionLabel: 'Vender para esta oferta',
            ),
          ),
      ],
    );
  }

  Widget _buildContent(_TradingViewData viewData) {
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
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Busque startups, filtre o mercado e monte suas carteiras recomendadas.',
                      style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1D22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2B3038)),
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 176,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTopInsightCard(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Carteiras recomendadas',
                  subtitle: 'Monte combinacoes de startups por tese e estagio.',
                  accentColor: const Color(0xFF8AB4FF),
                ),
                const SizedBox(width: 14),
                _buildTopInsightCard(
                  icon: Icons.trending_up_rounded,
                  title: 'Startups em destaque',
                  subtitle:
                      'Acompanhe as maiores variacoes para encontrar entradas.',
                  accentColor: const Color(0xFFB7C9FF),
                ),
                const SizedBox(width: 14),
                _buildTopInsightCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Book e execucao',
                  subtitle:
                      'Veja ordens abertas e execute compra ou venda na hora.',
                  accentColor: const Color(0xFFF8F8F8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF121316),
                    borderRadius: BorderRadius.circular(18),
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
                      contentPadding: EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _openFilterSheet,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121316),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2B3038)),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showMarket = true;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _showMarket
                        ? const Color(0xFF3A3A3D)
                        : const Color(0xFF151618),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF4A4D56)),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.show_chart_rounded),
                  label: const Text('Mercado'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showMarket = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: !_showMarket
                        ? const Color(0xFF3A3A3D)
                        : const Color(0xFF151618),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF4A4D56)),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('Carteiras recomendadas'),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF151618),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2B3038)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showGrid = true;
                        });
                      },
                      icon: Icon(
                        Icons.grid_view_rounded,
                        color: _showGrid
                            ? Colors.white
                            : const Color(0xFF7D8594),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showGrid = false;
                        });
                      },
                      icon: Icon(
                        Icons.view_agenda_outlined,
                        color: !_showGrid
                            ? Colors.white
                            : const Color(0xFF7D8594),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _showMarket ? 'Mercado' : 'Carteiras recomendadas',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showMarket
                ? 'Selecione a startup para abrir o book e executar operacoes.'
                : 'Use os filtros para montar uma combinacao de startups por setor e estagio.',
            style: const TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
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
          _buildMarketSection(viewData),
          const SizedBox(height: 24),
          _buildTradingDesk(viewData),
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

    return FutureBuilder<_TradingViewData>(
      future: _screenFuture,
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
                    'Nao foi possivel carregar a aba de negociacao.',
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

class _TradingViewData {
  final Startup startup;
  final List<StartupOfferModel> offers;
  final StartupPortfolioSnapshotModel portfolio;

  const _TradingViewData({
    required this.startup,
    required this.offers,
    required this.portfolio,
  });
}

class _TradeDraft {
  final String type;
  final double quantity;
  final double pricePerToken;

  const _TradeDraft({
    required this.type,
    required this.quantity,
    required this.pricePerToken,
  });
}
