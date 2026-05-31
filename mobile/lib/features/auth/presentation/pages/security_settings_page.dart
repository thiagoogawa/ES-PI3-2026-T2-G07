/// Thiago Ryuji Ogawa - RA:24024450
/// Lucca Schroelder Scovini - RA: 24011609
///
/// Tela de acesso e seguranca da conta.
/// Permite verificar o status do e-mail e configurar a autenticacao
/// em duas etapas por SMS diretamente no perfil do usuario.

import 'package:flutter/material.dart';

import '../../../../core/errors/auth_exception_mapper.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/datasources/auth_api_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/authenticated_user.dart';

class SecuritySettingsPage extends StatefulWidget {
  final AuthenticatedUser initialUser;
  final AuthRemoteDataSource authRemoteDataSource;
  final AuthApiDataSource authApiDataSource;

  const SecuritySettingsPage({
    super.key,
    required this.initialUser,
    required this.authRemoteDataSource,
    required this.authApiDataSource,
  });

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  late AuthenticatedUser _user;
  List<AuthSecondFactor> _factors = const [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _refreshSecurityState();
  }

  Future<void> _refreshSecurityState({bool showFeedback = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await widget.authRemoteDataSource.reloadCurrentUser();
      final idToken = await widget.authRemoteDataSource.getIdToken(
        forceRefresh: true,
      );
      final refreshedUser = await widget.authApiDataSource.fetchMe(idToken);
      final factors = await widget.authRemoteDataSource
          .getEnrolledSecondFactors();

      if (!mounted) {
        return;
      }

      setState(() {
        _user = refreshedUser;
        _factors = factors;
      });

      if (showFeedback) {
        showAppSnackBar(
          context,
          message: 'Dados de seguranca atualizados.',
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapAuthException(error),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    await _runSubmittingAction(() async {
      await widget.authRemoteDataSource.sendEmailVerification();
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: 'Enviamos um e-mail para verificar sua conta.',
        type: AppSnackBarType.success,
      );
    });
  }

  Future<void> _startEnrollmentFlow() async {
    if ((_user.email ?? '').trim().isEmpty) {
      showAppSnackBar(
        context,
        message: 'Sua conta precisa de um e-mail valido para ativar o 2FA.',
        type: AppSnackBarType.error,
      );
      return;
    }

    if (!_user.emailVerified) {
      showAppSnackBar(
        context,
        message: 'Verifique o e-mail da conta antes de ativar o 2FA.',
        type: AppSnackBarType.error,
      );
      return;
    }

    final input = await _showEnrollmentSetupSheet();
    if (input == null || !mounted) {
      return;
    }

    AuthPhoneVerificationRequest? request;
    await _runSubmittingAction(() async {
      await widget.authRemoteDataSource.reauthenticateWithPassword(
        email: _user.email!,
        password: input.password,
      );
      request = await widget.authRemoteDataSource.startPhoneEnrollment(
        phoneNumber: input.phoneNumber,
      );
    });

    final verificationRequest = request;
    if (verificationRequest == null || !mounted) {
      return;
    }

    final smsCode = verificationRequest.wasAutoVerified
        ? ''
        : await _showSmsCodeSheet(
            phoneNumber: AuthRemoteDataSource.normalizePhoneNumber(
              input.phoneNumber,
            ),
          );

    if (!verificationRequest.wasAutoVerified && (smsCode == null || !mounted)) {
      return;
    }

    await _runSubmittingAction(() async {
      await widget.authRemoteDataSource.enrollPhoneSecondFactor(
        request: verificationRequest,
        smsCode: smsCode ?? '',
        displayName: input.displayName,
      );
      await _refreshSecurityState();

      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: '2FA por SMS ativado com sucesso.',
        type: AppSnackBarType.success,
      );
    });
  }

  Future<void> _disableFactor(AuthSecondFactor factor) async {
    final password = await _showPasswordSheet(
      title: 'Desativar 2FA',
      description:
          'Confirme sua senha para remover o fator ${factor.label} da conta.',
      buttonLabel: 'Remover fator',
    );
    if (password == null || !mounted) {
      return;
    }

    await _runSubmittingAction(() async {
      await widget.authRemoteDataSource.reauthenticateWithPassword(
        email: _user.email ?? '',
        password: password,
      );
      await widget.authRemoteDataSource.unenrollSecondFactor(factor);
      await _refreshSecurityState();

      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: 'Fator removido. O acesso voltou a usar apenas a senha.',
        type: AppSnackBarType.success,
      );
    });
  }

  Future<void> _runSubmittingAction(Future<void> Function() action) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapAuthException(error),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<_EnrollmentSetupInput?> _showEnrollmentSetupSheet() {
    return showModalBottomSheet<_EnrollmentSetupInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EnrollmentSetupSheet(initialPhone: _user.phone),
    );
  }

  Future<String?> _showSmsCodeSheet({required String phoneNumber}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SmsCodeSheet(phoneNumber: phoneNumber),
    );
  }

  Future<String?> _showPasswordSheet({
    required String title,
    required String description,
    required String buttonLabel,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PasswordConfirmationSheet(
        title: title,
        description: description,
        buttonLabel: buttonLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFactors = _factors.isNotEmpty;
    final mfaStatus = hasFactors ? 'Ativo' : 'Desativado';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F10),
        elevation: 0,
        title: const Text('Acesso e seguranca'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(_user),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshSecurityState(showFeedback: true),
        color: const Color(0xFF4E91F3),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF151618),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2A2E36)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SecurityBadge(
                        label: 'E-mail',
                        value: _user.emailVerified ? 'Verificado' : 'Pendente',
                        accent: _user.emailVerified
                            ? const Color(0xFF8CC9AF)
                            : const Color(0xFFE7B97B),
                      ),
                      _SecurityBadge(
                        label: '2FA',
                        value: mfaStatus,
                        accent: hasFactors
                            ? const Color(0xFF84B5FF)
                            : const Color(0xFF9398A6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _user.email ?? 'Sem e-mail associado',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use o segundo fator por SMS para proteger acessos e operacoes sensiveis da sua conta.',
                    style: TextStyle(
                      color: Color(0xFFB7BCC8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!_user.emailVerified)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1814),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3A3020)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verifique seu e-mail primeiro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'O Firebase exige e-mail verificado antes do cadastro do segundo fator.',
                      style: TextStyle(
                        color: Color(0xFFE7D7BA),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : _sendVerificationEmail,
                        icon: const Icon(Icons.mark_email_read_outlined),
                        label: const Text('Enviar e-mail de verificacao'),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_user.emailVerified) const SizedBox(height: 18),
            Text(
              hasFactors ? 'Fatores cadastrados' : 'Segundo fator por SMS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!hasFactors)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF151618),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2A2E36)),
                ),
                child: const Text(
                  'Nenhum segundo fator foi configurado. Ative o 2FA por SMS para exigir um codigo extra no login.',
                  style: TextStyle(
                    color: Color(0xFFB7BCC8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              )
            else
              ..._factors.map(
                (factor) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151618),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2A2E36)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF17212F),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFF84B5FF),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              factor.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              factor.phoneNumber ?? 'Fator por SMS',
                              style: const TextStyle(
                                color: Color(0xFFB7BCC8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _disableFactor(factor),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFFFA2AE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting || _isLoading
                    ? null
                    : _startEnrollmentFlow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF346AC0),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(
                  hasFactors
                      ? 'Adicionar outro fator SMS'
                      : 'Ativar 2FA por SMS',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _refreshSecurityState(showFeedback: true),
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Sincronizar status de seguranca'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentSetupInput {
  final String phoneNumber;
  final String displayName;
  final String password;

  const _EnrollmentSetupInput({
    required this.phoneNumber,
    required this.displayName,
    required this.password,
  });
}

class _EnrollmentSetupSheet extends StatefulWidget {
  final String? initialPhone;

  const _EnrollmentSetupSheet({required this.initialPhone});

  @override
  State<_EnrollmentSetupSheet> createState() => _EnrollmentSetupSheetState();
}

class _EnrollmentSetupSheetState extends State<_EnrollmentSetupSheet> {
  late final TextEditingController _phoneController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _displayNameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SecuritySheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ativar 2FA por SMS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Informe o telefone em formato internacional e confirme sua senha para iniciar o cadastro do fator.',
            style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Telefone com DDI',
              hintText: '+5511999999999',
              labelStyle: TextStyle(color: Color(0xFFBDBDBD)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _displayNameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Nome do dispositivo ou telefone',
              hintText: 'Meu celular principal',
              labelStyle: TextStyle(color: Color(0xFFBDBDBD)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Senha atual',
              labelStyle: TextStyle(color: Color(0xFFBDBDBD)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop(
                  _EnrollmentSetupInput(
                    phoneNumber: _phoneController.text.trim(),
                    displayName: _displayNameController.text.trim(),
                    password: _passwordController.text,
                  ),
                );
              },
              child: const Text('Enviar codigo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmsCodeSheet extends StatefulWidget {
  final String phoneNumber;

  const _SmsCodeSheet({required this.phoneNumber});

  @override
  State<_SmsCodeSheet> createState() => _SmsCodeSheetState();
}

class _SmsCodeSheetState extends State<_SmsCodeSheet> {
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SecuritySheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirmar codigo SMS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Digite o codigo enviado para ${widget.phoneNumber}.',
            style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Codigo de verificacao',
              labelStyle: TextStyle(color: Color(0xFFBDBDBD)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop(_codeController.text);
              },
              child: const Text('Ativar 2FA'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordConfirmationSheet extends StatefulWidget {
  final String title;
  final String description;
  final String buttonLabel;

  const _PasswordConfirmationSheet({
    required this.title,
    required this.description,
    required this.buttonLabel,
  });

  @override
  State<_PasswordConfirmationSheet> createState() =>
      _PasswordConfirmationSheetState();
}

class _PasswordConfirmationSheetState
    extends State<_PasswordConfirmationSheet> {
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SecuritySheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.description,
            style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Senha atual',
              labelStyle: TextStyle(color: Color(0xFFBDBDBD)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop(_passwordController.text);
              },
              child: Text(widget.buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecuritySheetFrame extends StatelessWidget {
  final Widget child;

  const _SecuritySheetFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: child,
        ),
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _SecurityBadge({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101318),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF252A33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9398A6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
