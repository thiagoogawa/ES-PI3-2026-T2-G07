import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/startups_api_datasource.dart';
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
  late Future<StartupDetail> _faqFuture;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();

  bool _isSubmittingQuestion = false;

  @override
  void initState() {
    super.initState();
    _startupsApiDataSource = StartupsApiDataSource(ApiClient());
    _faqFuture = _loadFaq();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<StartupDetail> _loadFaq() {
    return _startupsApiDataSource.fetchStartupDetail(widget.startup.id);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

    setState(() {
      _isSubmittingQuestion = true;
    });

    try {
      await _startupsApiDataSource.submitQuestion(
        widget.startup.id,
        question: question,
      );

      _questionController.clear();

      if (!mounted) {
        return;
      }

      _showMessage('Pergunta enviada e publicada no FAQ.');
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('$error');
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

  Widget _buildComposer() {
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
          const Text(
            'Digite sua pergunta para publicar no FAQ desta startup.',
            style: TextStyle(
              color: Color(0xFFB7BCC8),
              fontSize: 12,
              height: 1.4,
            ),
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
                  : const Text('Publicar pergunta'),
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
      body: FutureBuilder<StartupDetail>(
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

          final detail = snapshot.data!;
          final searchTerm = _searchController.text.trim().toLowerCase();
          final filteredQuestions = detail.questions
              .where((question) {
                if (searchTerm.isEmpty) {
                  return true;
                }

                return question.question.toLowerCase().contains(searchTerm) ||
                    (question.answer?.toLowerCase().contains(searchTerm) ??
                        false);
              })
              .take(5)
              .toList();

          return RefreshIndicator(
            onRefresh: _reload,
            color: const Color(0xFF4E91F3),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildSearchBar(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Perguntas mais frequentes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (filteredQuestions.isEmpty)
                  const Text(
                    'Nenhuma pergunta encontrada.',
                    style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 14),
                  )
                else
                  ...filteredQuestions.map(_buildQuestionCard),
                _buildComposer(),
              ],
            ),
          );
        },
      ),
    );
  }
}
