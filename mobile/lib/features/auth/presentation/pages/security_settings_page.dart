/// Thiago Ryuji Ogawa - RA:24024450
///
/// Tela de acesso e seguranca do usuario autenticado.
/// Centraliza verificacao de e-mail e gestao do segundo fator por SMS.

import 'package:flutter/material.dart';

import '../../../../core/errors/user_friendly_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/datasources/auth_api_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/authenticated_user.dart';

class SecuritySettingsPage extends StatefulWidget {
  final AuthenticatedUser user;

  const SecuritySettingsPage({super.key, required this.user});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  late final AuthRemoteDataSource _authRemote;
  late final AuthApiDataSource _authApi;
  late final TextEditingController _phoneController;

  late AuthenticatedUser _user;
  List<AuthSecondFactor> _secondFactors = const [];
  bool _isRefreshing = false;
  bool _isSendingEmail = false;
  bool _isStartingEnrollment = false;
  String? _activeFactorUid;

  bool get _hasEnabledMfa => _secondFactors.isNotEmpty || _user.mfaEnabled;

  @override
  void initState() {
    super.initState();
    _authRemote = AuthRemoteDataSource();
    _authApi = AuthApiDataSource(ApiClient());
    _user = widget.user;
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _refreshSecurityState();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _refreshSecurityState({bool showFeedback = false}) async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _authRemote.reloadCurrentUser();
      final idToken = await _authRemote.getIdToken(forceRefresh: true);
      final refreshedUser = await _authApi.fetchMe(idToken);
      final secondFactors = await _authRemote.getCurrentSecondFactors();

      if (!mounted) {
        return;
      }

      setState(() {
        _user = refreshedUser;
        _secondFactors = secondFactors;
      });

      if (showFeedback) {
        showAppSnackBar(
          context,
          message: 'Configuracoes de seguranca atualizadas.',
          type: AppSnackBarType.success,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage:
              'Nao foi possivel atualizar as configuracoes de seguranca.',
        ),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _sendEmailVerification() async {
    if (_isSendingEmail) {
      return;
    }

    setState(() {
      _isSendingEmail = true;
    });

    try {
      await _authRemote.sendEmailVerification();
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: 'E-mail de verificacao enviado com sucesso.',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel enviar o e-mail de verificacao.',
        ),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingEmail = false;
        });
      }
    }
  }

  Future<void> _startEnrollment() async {
    if (_isStartingEnrollment) {
      return;
    }

    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Informe um telefone para ativar o 2FA.',
        type: AppSnackBarType.error,
      );
      return;
    }

    setState(() {
      _isStartingEnrollment = true;
    });

    try {
      final request = await _authRemote.startPhoneEnrollment(
        phoneNumber: phoneNumber,
      );

      if (!mounted) {
        return;
      }

      final smsCode = await _showSmsCodeDialog(phoneNumber);
      if (smsCode == null || smsCode.isEmpty) {
        return;
      }

      await _authRemote.enrollPhoneSecondFactor(
        verificationId: request.verificationId,
        smsCode: smsCode,
        displayName: 'Celular principal',
      );

      await _refreshSecurityState();
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: 'Verificacao em duas etapas ativada com sucesso.',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel ativar o 2FA por SMS.',
        ),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingEnrollment = false;
        });
      }
    }
  }

  Future<void> _removeFactor(AuthSecondFactor factor) async {
    setState(() {
      _activeFactorUid = factor.uid;
    });

    try {
      await _authRemote.unenrollSecondFactor(factor.uid);
      await _refreshSecurityState();
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: 'Segundo fator removido com sucesso.',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: mapUserFriendlyError(
          error,
          fallbackMessage: 'Nao foi possivel remover o segundo fator.',
        ),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeFactorUid = null;
        });
      }
    }
  }

  Future<String?> _showSmsCodeDialog(String phoneNumber) async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151618),
          title: const Text(
            'Confirmar codigo SMS',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digite o codigo enviado para $phoneNumber.',
                style: const TextStyle(color: Color(0xFFB7BCC8), height: 1.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Codigo SMS',
                  labelStyle: const TextStyle(color: Color(0xFF96A1B2)),
                  filled: true,
                  fillColor: const Color(0xFF0D1219),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF4E91F3)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return code;
  }

  String _factorLabel(AuthSecondFactor factor) {
    final displayName = factor.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final phoneNumber = factor.phoneNumber?.trim();
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      return phoneNumber;
    }

    return 'Telefone cadastrado';
  }

  AuthenticatedUser get _effectiveUser {
    if (_user.mfaEnabled == _hasEnabledMfa) {
      return _user;
    }

    return AuthenticatedUser(
      uid: _user.uid,
      email: _user.email,
      emailVerified: _user.emailVerified,
      mfaEnabled: _hasEnabledMfa,
      name: _user.name,
      cpf: _user.cpf,
      phone: _user.phone,
      picture: _user.picture,
      provider: _user.provider,
      roles: _user.roles,
      managedStartups: _user.managedStartups,
    );
  }

  Future<void> _closePage() async {
    Navigator.of(context).pop(_effectiveUser);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closePage();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F10),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F10),
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: _closePage,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: const Text('Acesso e seguranca'),
          actions: [
            IconButton(
              onPressed: _isRefreshing
                  ? null
                  : () => _refreshSecurityState(showFeedback: true),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Atualizar',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _SecurityCard(
              title: 'Verificacao de e-mail',
              subtitle: _user.email ?? '-',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusLine(
                    label: 'Status',
                    value: _user.emailVerified ? 'Verificado' : 'Pendente',
                    valueColor: _user.emailVerified
                        ? const Color(0xFF89D4A3)
                        : const Color(0xFFFFC85C),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _user.emailVerified || _isSendingEmail
                          ? null
                          : _sendEmailVerification,
                      icon: _isSendingEmail
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.mark_email_read_outlined),
                      label: Text(
                        _user.emailVerified
                            ? 'E-mail ja verificado'
                            : 'Enviar e-mail de verificacao',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SecurityCard(
              title: 'Verificacao em duas etapas',
              subtitle: 'Proteja o acesso com codigo enviado por SMS.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusLine(
                    label: 'Status',
                    value: _hasEnabledMfa ? 'Ativa' : 'Desativada',
                    valueColor: _hasEnabledMfa
                        ? const Color(0xFF89D4A3)
                        : const Color(0xFFFFC85C),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Telefone para 2FA',
                      helperText: 'Pode informar com ou sem +55.',
                      labelStyle: const TextStyle(color: Color(0xFF96A1B2)),
                      helperStyle: const TextStyle(color: Color(0xFF757C89)),
                      filled: true,
                      fillColor: const Color(0xFF0D1219),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF4E91F3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isStartingEnrollment
                          ? null
                          : _startEnrollment,
                      icon: _isStartingEnrollment
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_user_outlined),
                      label: Text(
                        _hasEnabledMfa
                            ? 'Adicionar outro telefone'
                            : 'Ativar 2FA por SMS',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_secondFactors.isEmpty)
                    const Text(
                      'Nenhum segundo fator cadastrado no momento.',
                      style: TextStyle(color: Color(0xFF9FA8B7), height: 1.5),
                    )
                  else
                    ..._secondFactors.map((factor) {
                      final isBusy = _activeFactorUid == factor.uid;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF11161D),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF2A2E36)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.smartphone_rounded,
                                color: Color(0xFF84B5FF),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _factorLabel(factor),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      factor.phoneNumber ??
                                          'Telefone nao informado',
                                      style: const TextStyle(
                                        color: Color(0xFF9FA8B7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: isBusy
                                    ? null
                                    : () => _removeFactor(factor),
                                child: isBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFFFA2AE),
                                        ),
                                      )
                                    : const Text(
                                        'Remover',
                                        style: TextStyle(
                                          color: Color(0xFFFFA2AE),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SecurityCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151618),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A2E36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF9FA8B7), height: 1.5),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatusLine({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF9FA8B7),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
