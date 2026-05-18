import 'package:flutter/material.dart';

import '../../../../core/errors/user_friendly_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/startup_trading_api_datasource.dart';
import '../../data/models/startup_offer_model.dart';
import '../../data/models/startup_portfolio_snapshot_model.dart';
import '../../domain/entities/startup.dart';

class StartupTradePage extends StatefulWidget {
  final Startup startup;

  const StartupTradePage({super.key, required this.startup});

  @override
  State<StartupTradePage> createState() => _StartupTradePageState();
}

class _StartupTradePageState extends State<StartupTradePage> {
  late final StartupTradingApiDataSource _startupTradingApiDataSource;
  late final AuthRemoteDataSource _authRemoteDataSource;
  late Future<_TradingViewData> _screenFuture;
  bool _isSubmittingTrade = false;
  String? _busyOfferId;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _startupTradingApiDataSource = StartupTradingApiDataSource(apiClient);
    _authRemoteDataSource = AuthRemoteDataSource();
    _screenFuture = _loadScreenData();
  }

  Future<_TradingViewData> _loadScreenData() async {
    final idToken = await _authRemoteDataSource.getIdToken();
    final results = await Future.wait<dynamic>([
      _startupTradingApiDataSource.fetchOffers(widget.startup.id),
      _startupTradingApiDataSource.fetchPortfolio(idToken),
    ]);

    return _TradingViewData(
      startup: widget.startup,
      offers: results[0] as List<StartupOfferModel>,
      portfolio: results[1] as StartupPortfolioSnapshotModel,
    );
  }

  Future<void> _reload() async {
    final future = _loadScreenData();
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

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151618),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E323A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8F96A3), fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTradeSheet(_TradingViewData viewData, String type) async {
    final draft = await showModalBottomSheet<_TradeDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141517),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 18),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type == 'buy' ? 'Comprar tokens' : 'Vender tokens',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
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
                    const SizedBox(height: 16),
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
                          minimumSize: const Size.fromHeight(46),
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

      showAppSnackBar(
        context,
        message: message.toString(),
        type: AppSnackBarType.success,
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel enviar a ordem agora.',
        ),
        type: AppSnackBarType.error,
      );
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

      showAppSnackBar(
        context,
        message:
            'Transacao executada: ${_formatQuantity(result.quantity)} token(s) em ${_formatCurrency(result.pricePerToken)}.',
        type: AppSnackBarType.success,
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel aceitar a oferta agora.',
        ),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyOfferId = null;
        });
      }
    }
  }

  Future<void> _cancelOffer(StartupOfferModel offer) async {
    if (_busyOfferId != null) {
      return;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151618),
          title: const Text(
            'Cancelar oferta',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Cancelar ${_formatQuantity(offer.remainingQuantity)} token(s) em ${_formatCurrency(offer.pricePerToken)}?',
            style: const TextStyle(color: Color(0xFFE6E8EE)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB84B58),
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancelar oferta'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !mounted) {
      return;
    }

    setState(() {
      _busyOfferId = offer.id;
    });

    try {
      final idToken = await _authRemoteDataSource.getIdToken();
      await _startupTradingApiDataSource.cancelOffer(
        idToken,
        offerId: offer.id,
      );

      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: 'Oferta cancelada com sucesso.',
        type: AppSnackBarType.success,
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel cancelar a oferta agora.',
        ),
        type: AppSnackBarType.error,
      );
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
        borderRadius: BorderRadius.circular(14),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(offer.createdAt),
                style: const TextStyle(color: Color(0xFF8F96A3), fontSize: 11),
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
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Valor total: ${_formatCurrency(offer.totalValue)}',
            style: const TextStyle(color: Color(0xFFB7BCC8), fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isBusy
                  ? null
                  : () {
                      if (isOwnOffer) {
                        _cancelOffer(offer);
                        return;
                      }

                      _acceptOffer(offer);
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: isOwnOffer
                      ? const Color(0xFFB84B58)
                      : const Color(0xFF55606F),
                ),
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(isOwnOffer ? 'Cancelar oferta' : actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(_TradingViewData viewData) {
    final portfolio = viewData.portfolio;
    final position = portfolio.positionForStartup(viewData.startup.id);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141517),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2B3038)),
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
                      viewData.startup.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      viewData.startup.sector ?? viewData.startup.stage,
                      style: const TextStyle(
                        color: Color(0xFFB7BCC8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${viewData.startup.dailyVariation >= 0 ? '+' : ''}${viewData.startup.dailyVariation.toStringAsFixed(2).replaceAll('.', ',')}%',
                style: TextStyle(
                  color: _variationColor(viewData.startup.dailyVariation),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Preco atual',
                  _formatCurrency(viewData.startup.currentPrice),
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
        ],
      ),
    );
  }

  Widget _buildContent(_TradingViewData viewData) {
    final openOffers = viewData.offers
        .where((offer) => offer.status == 'open' || offer.status == 'partial')
        .toList();
    final sellOffers = openOffers
        .where((offer) => offer.type == 'sell')
        .toList();
    final buyOffers = openOffers.where((offer) => offer.type == 'buy').toList();

    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFF4E91F3),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildHeader(viewData),
          const SizedBox(height: 18),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.sell_rounded),
                  label: const Text('Vender'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Ofertas de venda',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
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
                currentUserId: viewData.portfolio.userId,
                actionLabel: 'Comprar esta oferta',
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Ofertas de compra',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
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
                currentUserId: viewData.portfolio.userId,
                actionLabel: 'Vender para esta oferta',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F10),
        foregroundColor: Colors.white,
        title: const Text('Negociar startup'),
      ),
      body: FutureBuilder<_TradingViewData>(
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
                      'Nao foi possivel carregar esta negociacao.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      mapUserFriendlyError(
                        snapshot.error!,
                        fallbackMessage:
                            'Nao foi possivel carregar esta negociacao agora.',
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
      ),
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
