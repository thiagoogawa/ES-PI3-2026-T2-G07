/// Thiago Ryuji Ogawa - RA:24024450
///
/// Tela de perguntas e respostas da startup.
/// Exibe a FAQ publica e permite acompanhar o historico de
/// questoes enviadas pelos investidores.

import 'package:flutter/material.dart';

import '../../../../core/errors/user_friendly_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/startup_trading_api_datasource.dart';
import '../../data/datasources/startups_api_datasource.dart';
import '../../data/models/startup_portfolio_snapshot_model.dart';
import '../../domain/entities/startup.dart';
import '../../domain/entities/startup_detail.dart';

class StartupFaqPage extends StatefulWidget {
  final Startup startup;

  const StartupFaqPage({super.key, required this.startup});

  @override
  State<StartupFaqPage> createState() => _StartupFaqPageState();
}

class _StartupFaqPageState extends State<StartupFaqPage> {
  late final StartupsApiDataSource _startupsApiDataSource;
  late final StartupTradingApiDataSource _startupTradingApiDataSource;
  late final AuthRemoteDataSource _authRemoteDataSource;
  late Future<_FaqViewData> _faqFuture;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();

  bool _isSubmittingQuestion = false;
  bool _submitAsPublic = true;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _startupsApiDataSource = StartupsApiDataSource(apiClient);
    _startupTradingApiDataSource = StartupTradingApiDataSource(apiClient);
    _authRemoteDataSource = AuthRemoteDataSource();
    _faqFuture = _loadFaq();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<_FaqViewData> _loadFaq() async {
    final idToken = await _authRemoteDataSource.getIdToken();
    final results = await Future.wait<dynamic>([
      _startupsApiDataSource.fetchStartupDetailAuthenticated(
        idToken,
        widget.startup.id,
      ),
      _startupTradingApiDataSource.fetchPortfolio(idToken),
    ]);

    final detail = results[0] as StartupDetail;
    final portfolio = results[1] as StartupPortfolioSnapshotModel;
    final canAskPrivateQuestion =
        (portfolio.positionForStartup(widget.startup.id)?.quantity ?? 0) > 0;

    return _FaqViewData(
      detail: detail,
      canAskPrivateQuestion: canAskPrivateQuestion,
    );
  }

  Future<void> _reload() async {
    final future = _loadFaq();

    if (mounted) {
      setState(() {
        _faqFuture = future;
      });
    }

    await future;
  }

  void _showMessage(String message) {
    showAppSnackBar(context, message: message, type: AppSnackBarType.info);
  }

  Future<void> _submitQuestion() async {
    if (_isSubmittingQuestion) {
      return;
    }

    final question = _questionController.text.trim();
    if (question.isEmpty) {
      _showMessage('Digite uma pergunta para publicar no FAQ.');
      return;
    }

    if (!_submitAsPublic) {
      final viewData = await _faqFuture;
      if (!viewData.canAskPrivateQuestion) {
        if (!mounted) {
          return;
        }

        showAppSnackBar(
          context,
          message:
              'Perguntas privadas estao disponiveis apenas para investidores desta startup.',
          type: AppSnackBarType.error,
        );
        return;
      }
    }

    setState(() {
      _isSubmittingQuestion = true;
    });

    try {
      final submittedAsPublic = _submitAsPublic;
      final idToken = await _authRemoteDataSource.getIdToken();
      await _startupsApiDataSource.submitQuestion(
        widget.startup.id,
        question: question,
        isPublic: submittedAsPublic,
        idToken: idToken,
      );

      _questionController.clear();
      _submitAsPublic = true;

      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: submittedAsPublic
            ? 'Pergunta enviada para a area publica do FAQ.'
            : 'Pergunta privada enviada para a startup.',
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
          fallbackMessage: 'Nao foi possivel enviar sua pergunta agora.',
        ),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingQuestion = false;
        });
      }
    }
  }

  Widget _buildQuestionCard(StartupQuestion question) {
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
          if (!question.isPublic) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x338B5CF6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Privada',
                style: TextStyle(
                  color: Color(0xFFD3B4FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            question.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
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
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSection(
    String title,
    String emptyMessage,
    List<StartupQuestion> questions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (questions.isEmpty)
          Text(
            emptyMessage,
            style: const TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
          )
        else
          ...questions.map(_buildQuestionCard),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: _searchController,
        onChanged: (_) {
          setState(() {});
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar nas perguntas frequentes',
          hintStyle: const TextStyle(color: Color(0xFF7A808B)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF8F96A3)),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close, color: Color(0xFF8F96A3)),
                ),
          filled: true,
          fillColor: const Color(0xFF151618),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
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
        ),
      ),
    );
  }

  Widget _buildComposer(bool canAskPrivateQuestion) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151618),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E323A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fazer uma pergunta',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canAskPrivateQuestion
                ? 'Escolha se a pergunta deve ficar publica no FAQ ou privada entre voce e a startup.'
                : 'Digite sua pergunta para publicar no FAQ desta startup. Perguntas privadas ficam disponiveis apenas para investidores.',
            style: const TextStyle(
              color: Color(0xFFB7BCC8),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                selected: _submitAsPublic,
                label: const Text('Publica'),
                labelStyle: TextStyle(
                  color: _submitAsPublic
                      ? Colors.white
                      : const Color(0xFFB7BCC8),
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: const Color(0xFF346AC0),
                backgroundColor: const Color(0xFF101214),
                side: const BorderSide(color: Color(0xFF2E323A)),
                onSelected: (_) {
                  setState(() {
                    _submitAsPublic = true;
                  });
                },
              ),
              ChoiceChip(
                selected: !_submitAsPublic,
                label: const Text('Privada'),
                labelStyle: TextStyle(
                  color: !_submitAsPublic
                      ? Colors.white
                      : canAskPrivateQuestion
                      ? const Color(0xFFD8C8F8)
                      : const Color(0xFF6E7380),
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: const Color(0xFF6B46C1),
                backgroundColor: const Color(0xFF101214),
                disabledColor: const Color(0xFF101214),
                side: BorderSide(
                  color: canAskPrivateQuestion
                      ? const Color(0xFF4B4160)
                      : const Color(0xFF2E323A),
                ),
                onSelected: canAskPrivateQuestion
                    ? (_) {
                        setState(() {
                          _submitAsPublic = false;
                        });
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _questionController,
            minLines: 2,
            maxLines: 4,
            maxLength: 280,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ex.: Como a startup pretende usar a captacao atual?',
              hintStyle: const TextStyle(color: Color(0xFF7A808B)),
              filled: true,
              fillColor: const Color(0xFF0F0F10),
              counterStyle: const TextStyle(color: Color(0xFF8F96A3)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2E323A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2E323A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4E91F3)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingQuestion ? null : _submitQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF346AC0),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF273042),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmittingQuestion
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _submitAsPublic
                          ? 'Enviar pergunta publica'
                          : 'Enviar pergunta privada',
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
        title: Text('FAQ • ${widget.startup.name}'),
      ),
      body: FutureBuilder<_FaqViewData>(
        future: _faqFuture,
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
                      'Nao foi possivel carregar o FAQ desta startup.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      mapUserFriendlyError(
                        snapshot.error!,
                        fallbackMessage:
                            'Nao foi possivel carregar o FAQ desta startup.',
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

          final viewData = snapshot.data!;
          final detail = viewData.detail;
          final searchTerm = _searchController.text.trim().toLowerCase();
          final filteredQuestions = detail.questions.where((question) {
            if (searchTerm.isEmpty) {
              return true;
            }

            return question.question.toLowerCase().contains(searchTerm) ||
                (question.answer?.toLowerCase().contains(searchTerm) ?? false);
          }).toList();
          final publicQuestions = filteredQuestions
              .where((question) => question.isPublic)
              .toList();
          final privateQuestions = filteredQuestions
              .where((question) => !question.isPublic)
              .toList();

          return RefreshIndicator(
            onRefresh: _reload,
            color: const Color(0xFF4E91F3),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildSearchBar(),
                _buildQuestionSection(
                  'Perguntas publicas',
                  'Nenhuma pergunta publica encontrada.',
                  publicQuestions,
                ),
                if (viewData.canAskPrivateQuestion ||
                    privateQuestions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildQuestionSection(
                    'Perguntas privadas',
                    'Voce ainda nao enviou perguntas privadas para esta startup.',
                    privateQuestions,
                  ),
                ],
                _buildComposer(viewData.canAskPrivateQuestion),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FaqViewData {
  final StartupDetail detail;
  final bool canAskPrivateQuestion;

  const _FaqViewData({
    required this.detail,
    required this.canAskPrivateQuestion,
  });
}
