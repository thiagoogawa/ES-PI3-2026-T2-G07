part of 'home_page.dart';

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
        ? 'Toque em uma fatia para ver quanto foi investido ou toque no centro para ver o total.'
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
