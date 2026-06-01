/// Thiago Ryuji Ogawa - RA:24024450
///
/// Tela principal do administrador de startup.
/// Reune indicadores, atalhos e operacoes de gestao para quem
/// administra uma ou mais startups na plataforma.

import 'package:flutter/material.dart';

import '../../../../core/errors/user_friendly_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_snackbar.dart';
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

    final idToken = await _authRemoteDataSource.getIdToken();

    return _startupsApiDataSource.fetchStartupDetailAuthenticated(
      idToken,
      _selectedStartupId,
    );
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

      _showMessage(
        mapUserFriendlyError(
          error,
          fallbackMessage:
              'Nao foi possivel atualizar os dados da startup agora.',
        ),
        isError: true,
      );
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

      _showMessage(
        mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel enviar a resposta agora.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    try {
      final idToken = await _authRemoteDataSource.getIdToken();
      final updatedDetail = await _startupsApiDataSource.deleteQuestion(
        idToken,
        startupId: _selectedStartupId,
        questionId: questionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _startupFuture = Future.value(updatedDetail);
      });
      _showMessage('Pergunta removida do FAQ.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel remover a pergunta agora.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _signOut() async {
    await performLogoutFlow(context);
  }

  void _showMessage(String message, {bool isError = false}) {
    showAppSnackBar(
      context,
      message: message,
      type: isError ? AppSnackBarType.error : AppSnackBarType.success,
    );
  }

  Widget _buildTabBody(StartupDetail detail) {
    final tabContent = _selectedIndex == 0
        ? _StartupEditTab(
            key: ValueKey(
              '${detail.id}-${detail.name}-${detail.executiveSummary}',
            ),
            detail: detail,
            isSaving: _isSavingStartup,
            onSubmit: _updateStartup,
          )
        : _StartupFaqMessagesTab(
            key: ValueKey('faq-${detail.id}'),
            detail: detail,
            onAnswer: _answerQuestion,
            onDelete: _deleteQuestion,
          );

    return RefreshIndicator(
      onRefresh: _reloadSelectedStartup,
      color: const Color(0xFF2E7DFF),
      child: ListView(
        key: ValueKey('admin-list-${detail.id}-$_selectedIndex'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _AdminStartupHeader(user: widget.user),
          const SizedBox(height: 28),
          tabContent,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
        backgroundColor: const Color(0xFF11161D),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0x223A7BDA),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
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
                      mapUserFriendlyError(
                        snapshot.error!,
                        fallbackMessage:
                            'Verifique sua conexao e tente novamente.',
                      ),
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

          return _buildTabBody(detail);
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
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163153), Color(0xFF2E6CBC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ola, ${user.name ?? 'Admin'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Gerencie os dados da startup e responda as perguntas publicadas no FAQ.',
            style: TextStyle(
              color: Color(0xFFE2ECFF),
              height: 1.6,
              fontSize: 14,
            ),
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
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Atualize os campos exibidos para investidores na tela de detalhes.',
          style: TextStyle(color: Color(0xFF9FA8B7), height: 1.6),
        ),
        const SizedBox(height: 20),
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
  final Future<void> Function(String questionId) onDelete;

  const _StartupFaqMessagesTab({
    super.key,
    required this.detail,
    required this.onAnswer,
    required this.onDelete,
  });

  @override
  State<_StartupFaqMessagesTab> createState() => _StartupFaqMessagesTabState();
}

class _StartupFaqMessagesTabState extends State<_StartupFaqMessagesTab> {
  String? _answeringQuestionId;
  String? _editingQuestionId;
  String? _deletingQuestionId;
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
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Responda perguntas pendentes para manter o FAQ da startup atualizado.',
          style: TextStyle(color: Color(0xFF9FA8B7), height: 1.6),
        ),
        const SizedBox(height: 20),
        if (questions.isEmpty)
          const _AdminCard(
            child: Text(
              'Nenhuma pergunta foi enviada para esta startup ainda.',
              style: TextStyle(color: Color(0xFFB7BCC8), height: 1.5),
            ),
          )
        else
          ...questions.map(_buildQuestionCard),
      ],
    );
  }

  Widget _buildQuestionCard(StartupQuestion question) {
    final hasAnswer = question.answer?.trim().isNotEmpty ?? false;
    final isAnswerBusy = _answeringQuestionId == question.id;
    final isDeleteBusy = _deletingQuestionId == question.id;
    final isBusy = isAnswerBusy || isDeleteBusy;
    final isEditing = _editingQuestionId == question.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FaqBadge(
                  label: hasAnswer ? 'Respondida' : 'Pendente',
                  backgroundColor: hasAnswer
                      ? const Color(0x332E8B57)
                      : const Color(0x33D68A12),
                  foregroundColor: hasAnswer
                      ? const Color(0xFF89D4A3)
                      : const Color(0xFFFFC85C),
                ),
                _FaqBadge(
                  label: question.isPublic ? 'Publica' : 'Privada',
                  backgroundColor: question.isPublic
                      ? const Color(0x332E7DFF)
                      : const Color(0x338B5CF6),
                  foregroundColor: question.isPublic
                      ? const Color(0xFF84B5FF)
                      : const Color(0xFFD3B4FF),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              question.question.trim().isEmpty
                  ? 'Pergunta sem texto'
                  : question.question,
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
                  ? (question.answer ?? '')
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
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isBusy ? null : () => _submitAnswer(question),
                  child: Text(
                    isAnswerBusy ? 'Publicando...' : 'Publicar resposta',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: isBusy ? null : _cancelEditing,
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : () => _startEditing(question),
                icon: isAnswerBusy
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : () => _confirmDelete(question),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFA2AE),
                  side: const BorderSide(color: Color(0xFF3A2830)),
                ),
                icon: isDeleteBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFFA2AE),
                        ),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: const Text('Remover'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(StartupQuestion question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171A20),
          title: const Text(
            'Remover pergunta',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Deseja remover esta pergunta do FAQ? Esta acao nao pode ser desfeita.',
            style: TextStyle(color: Color(0xFFB7BCC8), height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB33A4B),
              ),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deletingQuestionId = question.id;
    });

    try {
      await widget.onDelete(question.id);
    } finally {
      if (mounted) {
        setState(() {
          _deletingQuestionId = null;
        });
      }
    }
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
      showAppSnackBar(
        context,
        message: 'Digite uma resposta antes de publicar.',
        type: AppSnackBarType.error,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121720),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FaqBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _FaqBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
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
        labelStyle: const TextStyle(color: Color(0xFF96A1B2)),
        filled: true,
        fillColor: const Color(0xFF0D1219),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x443A7BDA), width: 1.1),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.transparent),
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
