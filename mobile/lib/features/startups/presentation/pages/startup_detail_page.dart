import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/startups_api_datasource.dart';
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
  late Future<StartupDetail> _startupDetailFuture;

  @override
  void initState() {
    super.initState();
    _startupsApiDataSource = StartupsApiDataSource(ApiClient());
    _startupDetailFuture = _startupsApiDataSource.fetchStartupDetail(
      widget.startup.id,
    );
  }

  Future<void> _reload() async {
    final future = _startupsApiDataSource.fetchStartupDetail(widget.startup.id);

    if (mounted) {
      setState(() {
        _startupDetailFuture = future;
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

  Widget _buildDetailView(StartupDetail detail) {
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
              _buildMetricCard('Estagio', detail.stage),
            ],
          ),
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
      body: FutureBuilder<StartupDetail>(
        future: _startupDetailFuture,
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
