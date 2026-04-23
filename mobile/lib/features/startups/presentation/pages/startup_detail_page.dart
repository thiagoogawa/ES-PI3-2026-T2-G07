import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/startup_trading_api_datasource.dart';
import '../../data/datasources/startups_api_datasource.dart';
import '../../data/models/startup_offer_model.dart';
import '../../data/models/startup_portfolio_snapshot_model.dart';
import '../../domain/entities/startup.dart';
import '../../domain/entities/startup_detail.dart';

class StartupDetailPage extends StatefulWidget {
  final Startup startup;

  const StartupDetailPage({super.key, required this.startup});

  @override
  State<StartupDetailPage> createState() => _StartupDetailPageState();
}

class _StartupDetailPageState extends State<StartupDetailPage> {
  late final StartupsApiDataSource _startupsApiDataSource;
  late final StartupTradingApiDataSource _startupTradingApiDataSource;
  late final AuthRemoteDataSource _authRemoteDataSource;
  late Future<_StartupDetailViewData> _screenFuture;

  bool _isSubmittingTrade = false;
  String? _busyOfferId;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _startupsApiDataSource = StartupsApiDataSource(apiClient);
    _startupTradingApiDataSource = StartupTradingApiDataSource(apiClient);
    _authRemoteDataSource = AuthRemoteDataSource();
    _screenFuture = _loadScreenData();
  }

  Future<_StartupDetailViewData> _loadScreenData() async {
    final idToken = await _authRemoteDataSource.getIdToken();
    final results = await Future.wait<dynamic>([
      _startupsApiDataSource.fetchStartupDetail(widget.startup.id),
      _startupTradingApiDataSource.fetchOffers(widget.startup.id),
      _startupTradingApiDataSource.fetchPortfolio(idToken),
    ]);

    return _StartupDetailViewData(
      detail: results[0] as StartupDetail,
      offers: results[1] as List<StartupOfferModel>,
      portfolio: results[2] as StartupPortfolioSnapshotModel,
    );
  }

  Future<void> _reload() async {
    final future = _loadScreenData();

    if (mounted) {
      setState(() {
        _screenFuture = future;
      });
    }

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

  String _formatPercent(double value) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2).replaceAll('.', ',')}%';
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
    final year = parsed.year.toString();
    return '$day/$month/$year';
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildChipList(List<String> items) {
    if (items.isEmpty) {
      return const Text(
        'Sem informacoes disponiveis.',
        style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF151618),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF2E323A)),
              ),
              child: Text(
                item,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openTradeSheet(
    _StartupDetailViewData viewData,
    String type,
  ) async {
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
          text: viewData.detail.currentPrice.toStringAsFixed(2),
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
                      'A ordem tenta executar no balcao e deixa o saldo restante aberto no book.',
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

    await _submitTrade(draft);
  }

  Future<void> _submitTrade(_TradeDraft draft) async {
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
        startupId: widget.startup.id,
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

  Widget _buildTradingPanel(_StartupDetailViewData viewData) {
    final detail = viewData.detail;
    final portfolio = viewData.portfolio;
    final position = portfolio.positionForStartup(detail.id);
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
        _buildSectionTitle('Balcao de tokens'),
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
              const Text(
                'Negociacao simulada com saldo ficticio, conforme o escopo do MesclaInvest.',
                style: TextStyle(
                  color: Color(0xFFB7BCC8),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Seus tokens',
                      _formatQuantity(position?.quantity ?? 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Preco medio',
                      _formatCurrency(position?.averagePrice ?? 0),
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
        _buildSectionTitle('Ofertas de venda'),
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
        const SizedBox(height: 18),
        _buildSectionTitle('Ofertas de compra'),
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

  Widget _buildDetailView(_StartupDetailViewData viewData) {
    final detail = viewData.detail;

    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFF4E91F3),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF102853), Color(0xFF1C5DC3)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        detail.sector ?? detail.stage,
                        style: const TextStyle(
                          color: Color(0xFFD2E4FF),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatCurrency(detail.currentPrice),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatPercent(detail.dailyVariation),
                        style: TextStyle(
                          color: _variationColor(detail.dailyVariation),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x332C76E0),
                    border: Border.all(color: const Color(0x665E9CFF)),
                  ),
                  child: Center(
                    child: Text(
                      detail.name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.45,
            children: [
              _buildMetricCard(
                'Preco atual',
                _formatCurrency(detail.currentPrice),
              ),
              _buildMetricCard(
                'Capital captado',
                _formatCurrency(detail.capitalRaised),
              ),
              _buildMetricCard('Market cap', _formatCurrency(detail.marketCap)),
              _buildMetricCard(
                'Tokens emitidos',
                _formatQuantity(detail.totalTokens),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTradingPanel(viewData),
          const SizedBox(height: 24),
          _buildSectionTitle('Descricao'),
          Text(
            detail.description.isEmpty
                ? 'Sem descricao disponivel.'
                : detail.description,
            style: const TextStyle(
              color: Color(0xFFE6E8EE),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Sumario executivo'),
          Text(
            detail.executiveSummary.isEmpty
                ? 'Sem sumario executivo disponivel.'
                : detail.executiveSummary,
            style: const TextStyle(
              color: Color(0xFFE6E8EE),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Mentores'),
          _buildChipList(detail.mentors),
          const SizedBox(height: 24),
          _buildSectionTitle('Conselho'),
          _buildChipList(detail.boardMembers),
          const SizedBox(height: 24),
          _buildSectionTitle('Documentos e links'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF151618),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2E323A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plano de negocios: ${detail.businessPlanUrl ?? '-'}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pitch deck: ${detail.pitchDeckUrl ?? '-'}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Text(
                  'Videos: ${detail.videos.isEmpty ? '-' : detail.videos.join(' | ')}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Socios'),
          if (detail.partners.isEmpty)
            const Text(
              'Sem socios cadastrados.',
              style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
            )
          else
            ...detail.partners.map(
              (partner) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  partner.name,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  '${partner.participation.toStringAsFixed(2).replaceAll('.', ',')}%',
                  style: const TextStyle(
                    color: Color(0xFF84B5FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          _buildSectionTitle('Atualizacoes'),
          if (detail.updates.isEmpty)
            const Text(
              'Sem atualizacoes publicadas.',
              style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
            )
          else
            ...detail.updates.map(
              (update) => Container(
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
                    Text(
                      update.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(update.date),
                      style: const TextStyle(
                        color: Color(0xFF8F96A3),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      update.content,
                      style: const TextStyle(
                        color: Color(0xFFE6E8EE),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          _buildSectionTitle('Historico de precos'),
          if (detail.priceHistory.isEmpty)
            const Text(
              'Sem historico de precos.',
              style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
            )
          else
            ...detail.priceHistory
                .take(10)
                .map(
                  (point) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _formatCurrency(point.price),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _formatDate(point.timestamp),
                      style: const TextStyle(color: Color(0xFF8F96A3)),
                    ),
                  ),
                ),
          const SizedBox(height: 18),
          _buildSectionTitle('Perguntas frequentes'),
          if (detail.questions.isEmpty)
            const Text(
              'Sem perguntas cadastradas.',
              style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
            )
          else
            ...detail.questions.map(
              (question) => Container(
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
                    Text(
                      question.question,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.answer?.isNotEmpty == true
                          ? question.answer!
                          : 'Sem resposta publicada ainda.',
                      style: const TextStyle(
                        color: Color(0xFFE6E8EE),
                        fontSize: 13,
                        height: 1.5,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F10),
        foregroundColor: Colors.white,
        title: Text(widget.startup.name),
      ),
      body: FutureBuilder<_StartupDetailViewData>(
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
                      'Nao foi possivel carregar os detalhes da startup.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
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

          return _buildDetailView(snapshot.data!);
        },
      ),
    );
  }
}

class _StartupDetailViewData {
  final StartupDetail detail;
  final List<StartupOfferModel> offers;
  final StartupPortfolioSnapshotModel portfolio;

  const _StartupDetailViewData({
    required this.detail,
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
