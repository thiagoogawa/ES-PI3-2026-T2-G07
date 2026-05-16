import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../startups/data/datasources/startup_trading_api_datasource.dart';
import '../../../startups/data/models/startup_portfolio_snapshot_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PortfolioPage — widget público usado como body de uma tab no HomePage.
//
// Integração no home_page.dart:
//   case 3:
//     return PortfolioPage(portfolioFuture: _portfolioFuture);
//
// O parâmetro `portfolioFuture` é opcional: se omitido, a página busca
// sozinha via Firebase + API. Se fornecido (vindo do HomePage), reutiliza
// o mesmo Future para evitar requisição duplicada.
// ─────────────────────────────────────────────────────────────────────────────
class PortfolioPage extends StatefulWidget {
  final Future<StartupPortfolioSnapshotModel>? portfolioFuture;

  const PortfolioPage({super.key, this.portfolioFuture});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  late final AuthRemoteDataSource _authRemote;
  late final StartupTradingApiDataSource _tradingApi;
  late Future<StartupPortfolioSnapshotModel> _portfolioFuture;

  @override
  void initState() {
    super.initState();
    _authRemote = AuthRemoteDataSource();
    _tradingApi = StartupTradingApiDataSource(ApiClient());
    _portfolioFuture = widget.portfolioFuture ?? _fetchPortfolio();
  }

  Future<StartupPortfolioSnapshotModel> _fetchPortfolio() async {
    final idToken = await _authRemote.getIdToken();
    return _tradingApi.fetchPortfolio(idToken);
  }

  Future<void> _reload() async {
    final future = _fetchPortfolio();
    if (mounted) {
      setState(() => _portfolioFuture = future);
    }
    await future;
  }

  // ── Slices para o gráfico ─────────────────────────────────────────────────

  List<_PortfolioSlice> _buildSlices(
    StartupPortfolioSnapshotModel portfolio,
  ) {
    const chartColors = [
      Color(0xFF295AA5),
      Color(0xFF1F7668),
      Color(0xFF9A6630),
      Color(0xFF784292),
      Color(0xFF9B4150),
      Color(0xFF3A648D),
    ];

    final positions = [...portfolio.positions]
      ..sort(
        (a, b) => _allocationValue(b).compareTo(_allocationValue(a)),
      );

    final total =
        positions.fold<double>(0, (sum, p) => sum + _allocationValue(p));

    return positions.asMap().entries.map((entry) {
      final value = _allocationValue(entry.value);
      return _PortfolioSlice(
        label: entry.value.startupName,
        value: value,
        investedAmount: entry.value.investedAmount,
        percentage: total > 0 ? (value / total) * 100 : 0,
        color: chartColors[entry.key % chartColors.length],
      );
    }).toList();
  }

  double _allocationValue(StartupPortfolioPositionModel position) {
    if (position.currentValue > 0) return position.currentValue;
    if (position.investedAmount > 0) return position.investedAmount;
    return position.quantity;
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildDistributionSection(
    StartupPortfolioSnapshotModel portfolio,
  ) {
    // FIX: posições já filtradas pelo model (quantity > 0); sem duplicação
    final slices = _buildSlices(portfolio);

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
            'Distribuição das posições',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Participação de cada ativo na carteira atual.',
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
                  _buildLegendItem(slice),
                  if (slice != slices.last) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(_PortfolioSlice slice) {
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

  Widget _buildPositionCard(StartupPortfolioPositionModel position) {
    final profitLossColor =
        FormatUtils.variationColor(position.profitLoss);

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
                FormatUtils.currency(position.currentValue),
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
              _buildMetricChip(
                'Tokens',
                FormatUtils.quantity(position.quantity),
              ),
              _buildMetricChip(
                'Preço médio',
                FormatUtils.currency(position.averagePrice),
              ),
              _buildMetricChip(
                'Preço atual',
                FormatUtils.currency(position.currentPrice),
              ),
              _buildMetricChip(
                'Investido',
                FormatUtils.currency(position.investedAmount),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Resultado: ${FormatUtils.currency(position.profitLoss)}',
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

  Widget _buildMetricChip(String label, String value) {
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

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Não foi possível carregar o portfólio.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Text(
            '$error',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StartupPortfolioSnapshotModel>(
      future: _portfolioFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4E91F3)),
          );
        }

        if (snapshot.hasError) return _buildErrorState(snapshot.error!);

        final portfolio = snapshot.data!;

        // FIX: sem recriação de StartupPortfolioSnapshotModel desnecessária;
        // o model já filtra quantity > 0 no fromJson. Usamos positions direto.
        final validPositions = portfolio.positions;

        return RefreshIndicator(
          onRefresh: _reload,
          color: const Color(0xFF4E91F3),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (validPositions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2A2E36)),
                  ),
                  child: const Text(
                    'Você ainda não possui tokens em carteira. '
                    'Compre uma startup para ver suas posições aqui.',
                    style: TextStyle(
                      color: Color(0xFFB7BCC8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                )
              else ...[
                // FIX: passa portfolio diretamente, sem reconstrução
                _buildDistributionSection(portfolio),
                const SizedBox(height: 22),
                const Text(
                  'Posições',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                for (final position in validPositions) ...[
                  _buildPositionCard(position),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo interno de fatia
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// Gráfico de pizza interativo
// ─────────────────────────────────────────────────────────────────────────────
class _PortfolioPieChart extends StatefulWidget {
  final List<_PortfolioSlice> slices;
  const _PortfolioPieChart({required this.slices});

  @override
  State<_PortfolioPieChart> createState() => _PortfolioPieChartState();
}

class _PortfolioPieChartState extends State<_PortfolioPieChart> {
  int? _selectedIndex;
  bool _isTotalVisible = false;

  void _handlePointer(Offset localPosition, Size size) {
    final idx = _hitTestSlice(localPosition, size);
    if (idx == _selectedIndex) return;
    setState(() {
      _selectedIndex = idx;
      if (idx != null) _isTotalVisible = false;
    });
  }

  void _clearSelection() {
    if (_selectedIndex == null) return;
    setState(() => _selectedIndex = null);
  }

  /// Retorna o índice da fatia tocada, ou null se o toque cair fora
  /// de qualquer fatia (buraco central, área externa, ou imprecisão float).
  int? _hitTestSlice(Offset position, Size size) {
    final total =
        widget.slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return null;

    final center = Offset(size.width / 2, size.height / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final radius = math.min(size.width, size.height) / 2;
    final innerRadius = radius * 0.42;

    if (distance < innerRadius || distance > radius) return null;

    // Normaliza o ângulo para [0, 2π) partindo do topo (−π/2)
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;

    var startAngle = 0.0;
    for (var i = 0; i < widget.slices.length; i++) {
      final sweep = (widget.slices[i].value / total) * math.pi * 2;
      if (angle >= startAngle && angle < startAngle + sweep) return i;
      startAngle += sweep;
    }

    // FIX: imprecisão float pode deixar angle ligeiramente > 2π.
    // Em vez de retornar last (errado), verificamos se está muito próximo
    // do início do círculo e retornamos a primeira fatia, ou null.
    final overflow = angle - startAngle;
    if (overflow.abs() < 1e-10) return 0;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    final selectedSlice =
        _selectedIndex == null ? null : slices[_selectedIndex!];
    const chartSize = 208.0;

    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gráfico ──────────────────────────────────────────────────────
          GestureDetector(
            onTapDown: (d) => _handlePointer(
              d.localPosition,
              const Size.square(chartSize),
            ),
            onTapUp: (_) => _clearSelection(),
            onTapCancel: _clearSelection,
            onPanDown: (d) => _handlePointer(
              d.localPosition,
              const Size.square(chartSize),
            ),
            onPanUpdate: (d) => _handlePointer(
              d.localPosition,
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

                  // ── Centro: toggle total ────────────────────────────────
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isTotalVisible = !_isTotalVisible;
                        if (_isTotalVisible) _selectedIndex = null;
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isTotalVisible) ...[
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
                            const Text(
                              'Toque para ver total',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF5A6070),
                                fontSize: 10,
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Total',
                              style: TextStyle(
                                color: Color(0xFF8F96A3),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              total > 0
                                  ? FormatUtils.compactCurrency(total)
                                  : '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Toque para ocultar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF5A6070),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Card detalhe da fatia pressionada ─────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Container(
              key: ValueKey(selectedSlice?.label ?? 'portfolio-hint'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
                          'Investido ${FormatUtils.currency(selectedSlice.investedAmount)}',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter do gráfico de pizza
// ─────────────────────────────────────────────────────────────────────────────
class _PortfolioPieChartPainter extends CustomPainter {
  final List<_PortfolioSlice> slices;
  final int? selectedIndex;

  const _PortfolioPieChartPainter({
    required this.slices,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final separatorPaint = Paint()
      ..color = const Color(0xFF0F0F10)
      ..strokeWidth = 2;

    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFF1E222A),
      );
      return;
    }

    var startAngle = -math.pi / 2;

    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final sweep = (slice.value / total) * math.pi * 2;
      final isSelected = selectedIndex == i;
      final outerRadius = isSelected ? radius + 6 : radius;

      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(
            Rect.fromCircle(center: center, radius: outerRadius),
            startAngle,
            sweep,
            false,
          )
          ..close(),
        Paint()
          ..style = PaintingStyle.fill
          ..color = isSelected
              ? Color.lerp(slice.color, Colors.white, 0.12) ?? slice.color
              : slice.color,
      );

      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(startAngle) * outerRadius,
          center.dy + math.sin(startAngle) * outerRadius,
        ),
        separatorPaint,
      );

      startAngle += sweep;
    }

    // Buraco central do donut
    canvas.drawCircle(
      center,
      radius * 0.42,
      Paint()..color = const Color(0xFF151618),
    );
  }

  @override
  bool shouldRepaint(covariant _PortfolioPieChartPainter old) =>
      old.slices != slices || old.selectedIndex != selectedIndex;
}
