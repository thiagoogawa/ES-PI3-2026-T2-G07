import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../startups/data/datasources/startups_api_datasource.dart';
import '../../../startups/domain/entities/startup_detail.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/authenticated_user.dart';
import '../widgets/logout_flow.dart';
import 'admin_startup_selection_page.dart';

class AdminHomePage extends StatefulWidget {
  final AuthenticatedUser user;
  final ManagedStartup startup;

  const AdminHomePage({super.key, required this.user, required this.startup});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  late final StartupsApiDataSource _startupsApiDataSource;
  late final AuthRemoteDataSource _authRemoteDataSource;
  late String _selectedStartupId;
  late Future<StartupDetail?> _startupFuture;
  int _selectedIndex = 0;
  bool _isSavingStartup = false;

  @override
  void initState() {
    super.initState();
    _startupsApiDataSource = StartupsApiDataSource(ApiClient());
    _authRemoteDataSource = AuthRemoteDataSource();
    _selectedStartupId = widget.startup.id;
    _startupFuture = _loadSelectedStartup();
  }

  Future<StartupDetail?> _loadSelectedStartup() async {
    if (_selectedStartupId.isEmpty) {
      return null;
    }

    return _startupsApiDataSource.fetchStartupDetail(_selectedStartupId);
  }

  Future<void> _reloadSelectedStartup() async {
    final future = _loadSelectedStartup();
    if (mounted) {
      setState(() {
        _startupFuture = future;
      });
    }
    await future;
  }

  Future<void> _chooseAnotherStartup() async {
    if (!mounted) {
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AdminStartupSelectionPage(user: widget.user),
      ),
    );
  }

  Future<void> _updateStartup(_StartupAdminDraft draft) async {
    if (_isSavingStartup) {
      return;
    }

    setState(() {
      _isSavingStartup = true;
    });

    try {
      final idToken = await _authRemoteDataSource.getIdToken();
      final updatedDetail = await _startupsApiDataSource.updateStartup(
        idToken,
        startupId: _selectedStartupId,
        name: draft.name,
        description: draft.description,
        stage: draft.stage,
        sector: draft.sector,
        executiveSummary: draft.executiveSummary,
        businessPlanUrl: draft.businessPlanUrl,
        pitchDeckUrl: draft.pitchDeckUrl,
        mentors: draft.mentors,
        boardMembers: draft.boardMembers,
        videos: draft.videos,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _startupFuture = Future.value(updatedDetail);
      });
      _showMessage('Dados da startup atualizados com sucesso.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('$error');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingStartup = false;
        });
      }
    }
  }

  Future<void> _answerQuestion(String questionId, String answer) async {
    try {
      final idToken = await _authRemoteDataSource.getIdToken();
      final updatedDetail = await _startupsApiDataSource.answerQuestion(
        idToken,
        startupId: _selectedStartupId,
        questionId: questionId,
        answer: answer,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _startupFuture = Future.value(updatedDetail);
      });
      _showMessage('Resposta enviada para o FAQ.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('$error');
    }
  }

  Future<void> _signOut() async {
    await performLogoutFlow(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1115),
        foregroundColor: Colors.white,
        title: Text(widget.startup.name),
        actions: [
          IconButton(
            onPressed: _chooseAnotherStartup,
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'Escolher startup',
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sair',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          setState(() {
            _selectedIndex = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit_rounded),
            label: 'Editar startup',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: 'Mensagens FAQ',
          ),
        ],
      ),
      body: FutureBuilder<StartupDetail?>(
        future: _startupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7DFF)),
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
                      'Nao foi possivel carregar a startup administrada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB7BCC8)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _reloadSelectedStartup,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data;
          if (detail == null) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _reloadSelectedStartup,
            color: const Color(0xFF2E7DFF),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _AdminStartupHeader(user: widget.user),
                const SizedBox(height: 20),
                if (_selectedIndex == 0)
                  _StartupEditTab(
                    key: ValueKey(
                      '${detail.id}-${detail.name}-${detail.executiveSummary}',
                    ),
                    detail: detail,
                    isSaving: _isSavingStartup,
                    onSubmit: _updateStartup,
                  )
                else
                  _StartupFaqMessagesTab(
                    detail: detail,
                    onAnswer: _answerQuestion,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.storefront_outlined, color: Color(0xFF84B5FF), size: 42),
            SizedBox(height: 16),
            Text(
              'Nenhuma startup vinculada a este admin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Associe o usuario a uma startup com o campo adminUid ou admin.uid no backend.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB7BCC8), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStartupHeader extends StatelessWidget {
  final AuthenticatedUser user;

  const _AdminStartupHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12335D), Color(0xFF1D6DC8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ola, ${user.name ?? 'Admin'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gerencie os dados da startup e responda as perguntas publicadas no FAQ.',
            style: TextStyle(color: Color(0xFFDCEAFF), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _StartupEditTab extends StatefulWidget {
  final StartupDetail detail;
  final bool isSaving;
  final Future<void> Function(_StartupAdminDraft draft) onSubmit;

  const _StartupEditTab({
    super.key,
    required this.detail,
    required this.isSaving,
    required this.onSubmit,
  });

  @override
  State<_StartupEditTab> createState() => _StartupEditTabState();
}

class _StartupEditTabState extends State<_StartupEditTab> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _stageController;
  late final TextEditingController _sectorController;
  late final TextEditingController _summaryController;
  late final TextEditingController _businessPlanController;
  late final TextEditingController _pitchDeckController;
  late final TextEditingController _mentorsController;
  late final TextEditingController _boardController;
  late final TextEditingController _videosController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _stageController = TextEditingController();
    _sectorController = TextEditingController();
    _summaryController = TextEditingController();
    _businessPlanController = TextEditingController();
    _pitchDeckController = TextEditingController();
    _mentorsController = TextEditingController();
    _boardController = TextEditingController();
    _videosController = TextEditingController();
    _fillControllers();
  }

  @override
  void didUpdateWidget(covariant _StartupEditTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.id != widget.detail.id ||
        oldWidget.detail.name != widget.detail.name ||
        oldWidget.detail.executiveSummary != widget.detail.executiveSummary) {
      _fillControllers();
    }
  }

  void _fillControllers() {
    _nameController.text = widget.detail.name;
    _descriptionController.text = widget.detail.description;
    _stageController.text = widget.detail.stage;
    _sectorController.text = widget.detail.sector ?? '';
    _summaryController.text = widget.detail.executiveSummary;
    _businessPlanController.text = widget.detail.businessPlanUrl ?? '';
    _pitchDeckController.text = widget.detail.pitchDeckUrl ?? '';
    _mentorsController.text = widget.detail.mentors.join('\n');
    _boardController.text = widget.detail.boardMembers.join('\n');
    _videosController.text = widget.detail.videos.join('\n');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _stageController.dispose();
    _sectorController.dispose();
    _summaryController.dispose();
    _businessPlanController.dispose();
    _pitchDeckController.dispose();
    _mentorsController.dispose();
    _boardController.dispose();
    _videosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Editar dados da startup',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Atualize os campos exibidos para investidores na tela de detalhes.',
          style: TextStyle(color: Color(0xFFB7BCC8), height: 1.5),
        ),
        const SizedBox(height: 18),
        _AdminCard(
          child: Column(
            children: [
              _AdminTextField(
                controller: _nameController,
                label: 'Nome da startup',
              ),
              const SizedBox(height: 14),
              _AdminTextField(controller: _stageController, label: 'Estagio'),
              const SizedBox(height: 14),
              _AdminTextField(controller: _sectorController, label: 'Setor'),
              const SizedBox(height: 14),
              _AdminTextField(
                controller: _descriptionController,
                label: 'Descricao',
                maxLines: 5,
              ),
              const SizedBox(height: 14),
              _AdminTextField(
                controller: _summaryController,
                label: 'Sumario executivo',
                maxLines: 5,
              ),
              const SizedBox(height: 14),
              _AdminTextField(
                controller: _businessPlanController,
                label: 'URL do plano de negocios',
              ),
              const SizedBox(height: 14),
              _AdminTextField(
                controller: _pitchDeckController,
                label: 'URL do pitch deck',
              ),
              const SizedBox(height: 14),
              _AdminTextField(
                controller: _mentorsController,
                label: 'Mentores (um por linha)',
                maxLines: 4,
              ),
              const SizedBox(height: 14),
              _AdminTextField(
                controller: _boardController,
                label: 'Conselho (um por linha)',
                maxLines: 4,
              ),
              const SizedBox(height: 14),
              _AdminTextField(
                controller: _videosController,
                label: 'Videos (um por linha)',
                maxLines: 4,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.isSaving
                      ? null
                      : () => widget.onSubmit(
                          _StartupAdminDraft(
                            name: _nameController.text.trim(),
                            description: _descriptionController.text.trim(),
                            stage: _stageController.text.trim(),
                            sector: _normalizedText(_sectorController.text),
                            executiveSummary: _summaryController.text.trim(),
                            businessPlanUrl: _normalizedText(
                              _businessPlanController.text,
                            ),
                            pitchDeckUrl: _normalizedText(
                              _pitchDeckController.text,
                            ),
                            mentors: _parseMultiline(_mentorsController.text),
                            boardMembers: _parseMultiline(
                              _boardController.text,
                            ),
                            videos: _parseMultiline(_videosController.text),
                          ),
                        ),
                  icon: widget.isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    widget.isSaving ? 'Salvando...' : 'Salvar alteracoes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _parseMultiline(String value) {
    return value
        .split(RegExp(r'\n|,|;'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String? _normalizedText(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class _StartupFaqMessagesTab extends StatefulWidget {
  final StartupDetail detail;
  final Future<void> Function(String questionId, String answer) onAnswer;

  const _StartupFaqMessagesTab({required this.detail, required this.onAnswer});

  @override
  State<_StartupFaqMessagesTab> createState() => _StartupFaqMessagesTabState();
}

class _StartupFaqMessagesTabState extends State<_StartupFaqMessagesTab> {
  String? _answeringQuestionId;
  String? _editingQuestionId;
  late final TextEditingController _answerController;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = [...widget.detail.questions]
      ..sort((left, right) {
        final leftUnanswered = left.answer?.trim().isEmpty ?? true;
        final rightUnanswered = right.answer?.trim().isEmpty ?? true;
        if (leftUnanswered == rightUnanswered) {
          return 0;
        }

        return leftUnanswered ? -1 : 1;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mensagens e FAQ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Responda perguntas pendentes para manter o FAQ da startup atualizado.',
          style: TextStyle(color: Color(0xFFB7BCC8), height: 1.5),
        ),
        const SizedBox(height: 18),
        if (questions.isEmpty)
          const _AdminCard(
            child: Text(
              'Nenhuma pergunta foi enviada para esta startup ainda.',
              style: TextStyle(color: Color(0xFFB7BCC8), height: 1.5),
            ),
          )
        else
          ...questions.map((question) {
            final hasAnswer = question.answer?.trim().isNotEmpty ?? false;
            final isBusy = _answeringQuestionId == question.id;
            final isEditing = _editingQuestionId == question.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AdminCard(
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
                            color: hasAnswer
                                ? const Color(0x332E8B57)
                                : const Color(0x33D68A12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            hasAnswer ? 'Respondida' : 'Pendente',
                            style: TextStyle(
                              color: hasAnswer
                                  ? const Color(0xFF89D4A3)
                                  : const Color(0xFFFFC85C),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      question.question,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasAnswer
                          ? question.answer!
                          : 'Sem resposta publicada ainda.',
                      style: TextStyle(
                        color: hasAnswer
                            ? const Color(0xFFD9DEE9)
                            : const Color(0xFF8F96A3),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isEditing) ...[
                      _AdminTextField(
                        controller: _answerController,
                        label: 'Resposta',
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isBusy ? null : _cancelEditing,
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: isBusy
                                  ? null
                                  : () => _submitAnswer(question),
                              child: Text(
                                isBusy ? 'Publicando...' : 'Publicar resposta',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => _startEditing(question),
                        icon: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.reply_rounded),
                        label: Text(
                          isEditing
                              ? 'Editando resposta'
                              : hasAnswer
                              ? 'Editar resposta'
                              : 'Responder',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _startEditing(StartupQuestion question) {
    setState(() {
      _editingQuestionId = question.id;
      _answerController.text = question.answer ?? '';
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingQuestionId = null;
      _answerController.clear();
    });
  }

  Future<void> _submitAnswer(StartupQuestion question) async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite uma resposta antes de publicar.')),
      );
      return;
    }

    setState(() {
      _answeringQuestionId = question.id;
    });

    try {
      await widget.onAnswer(question.id, answer);
      if (mounted) {
        setState(() {
          _editingQuestionId = null;
          _answerController.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _answeringQuestionId = null;
        });
      }
    }
  }
}

class _AdminCard extends StatelessWidget {
  final Widget child;

  const _AdminCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15181E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2B313C)),
      ),
      child: child,
    );
  }
}

class _AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _AdminTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFB7BCC8)),
        filled: true,
        fillColor: const Color(0xFF101318),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2B313C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2E7DFF)),
        ),
      ),
    );
  }
}

class _StartupAdminDraft {
  final String name;
  final String description;
  final String stage;
  final String? sector;
  final String executiveSummary;
  final String? businessPlanUrl;
  final String? pitchDeckUrl;
  final List<String> mentors;
  final List<String> boardMembers;
  final List<String> videos;

  const _StartupAdminDraft({
    required this.name,
    required this.description,
    required this.stage,
    required this.sector,
    required this.executiveSummary,
    required this.businessPlanUrl,
    required this.pitchDeckUrl,
    required this.mentors,
    required this.boardMembers,
    required this.videos,
  });
}
