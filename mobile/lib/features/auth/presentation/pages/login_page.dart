/// Thiago Ryuji Ogawa - RA:24024450
/// Lucca Schroelder Scovini - RA: 24011609
///
/// Tela de entrada de usuario.
/// Agrupa autenticacao, feedback de erro e navegacao inicial para
/// usuarios que ainda nao possuem sessao valida.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/auth_api_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/authenticated_user.dart';
import '../controllers/auth_controller.dart';
import '../widgets/mescla_brand_logo.dart';
import 'app_home_router.dart';
import 'reset_password_page.dart';
import 'signup_flow_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final AuthController controller;
  final AuthRemoteDataSource _authRemote = AuthRemoteDataSource();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isCompletingLoginTransition = false;
  BuildContext? _authSheetContext;
  bool _isShowingMfaSheet = false;

  @override
  void initState() {
    super.initState();

    controller = AuthController(
      AuthRepositoryImpl(
        AuthRemoteDataSource(),
        AuthApiDataSource(ApiClient()),
      ),
    );

    controller.addListener(() {
      if (controller.currentUser != null &&
          mounted &&
          !_isCompletingLoginTransition) {
        _handleAuthenticatedUser(controller.currentUser!);
      }

      if (controller.errorMessage != null && mounted) {
        showAppSnackBar(
          context,
          message: controller.errorMessage!,
          type: AppSnackBarType.error,
        );
      }

      if (mounted) {
        setState(() {});
      }
    });

    controller.restoreSession();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _openResetPasswordPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ResetPasswordPage(initialEmail: emailController.text.trim()),
      ),
    );
  }

  Future<void> _openAuthSheet() async {
    emailController.clear();
    passwordController.clear();
    _isCompletingLoginTransition = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        _authSheetContext = sheetContext;

        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isCompletingLoginTransition) ...[
                    const _SheetSuccessLoadingState(),
                  ] else ...[
                    Text(
                      'Entrar',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Acesse sua conta para continuar.',
                      style: const TextStyle(
                        color: Color(0xFFBDBDBD),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('E-mail'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Senha'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: controller.isLoading
                            ? null
                            : () async {
                                Navigator.of(sheetContext).pop();
                                await _openResetPasswordPage();
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF84B5FF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          'Esqueceu a Senha?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: controller.isLoading
                            ? null
                            : () async => _handleLogin(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3C78D8),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: controller.isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Entrar'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _authSheetContext = null;
    });
  }

  Future<void> _handleLogin() async {
    final validationError = controller.validateCredentials(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    if (validationError != null && mounted) {
      showAppSnackBar(
        context,
        message: validationError,
        type: AppSnackBarType.error,
      );
      return;
    }

    await controller.signIn(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    final resolver = controller.pendingSecondFactorResolver;
    if (resolver != null) {
      if (_authSheetContext != null) {
        Navigator.of(_authSheetContext!).pop();
        _authSheetContext = null;
      }

      await _showMfaSheet(resolver);
    }
  }

  Future<void> _showMfaSheet(MultiFactorResolver resolver) async {
    if (_isShowingMfaSheet) {
      return;
    }

    _isShowingMfaSheet = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MfaSignInSheet(
        authRemote: _authRemote,
        resolver: resolver,
        onAuthenticated: () async {
          controller.clearPendingSecondFactorChallenge();
          await controller.restoreSession();
        },
        onCancel: controller.clearPendingSecondFactorChallenge,
      ),
    );

    _isShowingMfaSheet = false;
  }

  Future<void> _handleAuthenticatedUser(AuthenticatedUser user) async {
    setState(() {
      _isCompletingLoginTransition = true;
    });

    if (_authSheetContext != null) {
      Navigator.of(_authSheetContext!).pop();
      _authSheetContext = null;
    }

    await _showPostLoginLoading();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(_buildHomeRoute(user));
  }

  Future<void> _showPostLoginLoading() async {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Carregando sua conta',
      barrierColor: const Color(0xCC090B10),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _PostLoginLoadingDialog();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final scaleAnimation = Tween<double>(
          begin: 0.94,
          end: 1.0,
        ).animate(curvedAnimation);

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) {
      return;
    }

    Navigator.of(context, rootNavigator: true).pop();
  }

  Route<void> _buildHomeRoute(AuthenticatedUser user) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return buildHomePageForUser(user);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(fadeAnimation);

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFBDBDBD)),
      filled: true,
      fillColor: const Color(0xFF242424),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF323232)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF3C78D8), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                'MesclaInvest',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'invista nas melhores startups do mercado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE8E8E8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              const MesclaBrandLogo(size: 148),
              const SizedBox(height: 72),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isLoading
                      ? null
                      : () => _openAuthSheet(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF346AC0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Entrar'),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: controller.isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignupFlowPage(),
                            ),
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 1.2),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Cadastrar-se'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MfaSignInSheet extends StatefulWidget {
  final AuthRemoteDataSource authRemote;
  final MultiFactorResolver resolver;
  final Future<void> Function() onAuthenticated;
  final VoidCallback onCancel;

  const _MfaSignInSheet({
    required this.authRemote,
    required this.resolver,
    required this.onAuthenticated,
    required this.onCancel,
  });

  @override
  State<_MfaSignInSheet> createState() => _MfaSignInSheetState();
}

class _MfaSignInSheetState extends State<_MfaSignInSheet> {
  late final List<AuthSecondFactor> _factors;
  late AuthSecondFactor _selectedFactor;
  final TextEditingController _codeController = TextEditingController();

  bool _isSendingCode = true;
  bool _isSubmittingCode = false;
  String? _verificationId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _factors = widget.authRemote.getSecondFactors(widget.resolver);
    _selectedFactor = _factors.first;
    _sendCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
      _verificationId = null;
    });

    try {
      final request = await widget.authRemote.startSecondFactorSignIn(
        resolver: widget.resolver,
        factorUid: _selectedFactor.uid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _verificationId = request.verificationId;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Nao foi possivel enviar o codigo por SMS.';
      });

      showAppSnackBar(
        context,
        message: _errorMessage!,
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _submitCode() async {
    final verificationId = _verificationId;
    final smsCode = _codeController.text.trim();
    if (verificationId == null || smsCode.length < 6 || _isSubmittingCode) {
      return;
    }

    setState(() {
      _isSubmittingCode = true;
      _errorMessage = null;
    });

    try {
      await widget.authRemote.resolveSecondFactorSignIn(
        resolver: widget.resolver,
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await widget.onAuthenticated();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Codigo invalido ou expirado. Tente novamente.';
      });

      showAppSnackBar(
        context,
        message: _errorMessage!,
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingCode = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verificacao em duas etapas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirme o codigo enviado para ${_factorLabel(_selectedFactor)}.',
            style: const TextStyle(
              color: Color(0xFFBDBDBD),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (_factors.length > 1) ...[
            const SizedBox(height: 18),
            DropdownButtonFormField<AuthSecondFactor>(
              initialValue: _selectedFactor,
              dropdownColor: const Color(0xFF242424),
              decoration: _mfaInputDecoration('Dispositivo'),
              style: const TextStyle(color: Colors.white),
              items: _factors
                  .map((factor) {
                    return DropdownMenuItem<AuthSecondFactor>(
                      value: factor,
                      child: Text(_factorLabel(factor)),
                    );
                  })
                  .toList(growable: false),
              onChanged: _isSendingCode
                  ? null
                  : (factor) {
                      if (factor == null) {
                        return;
                      }

                      setState(() {
                        _selectedFactor = factor;
                        _codeController.clear();
                      });
                      _sendCode();
                    },
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _mfaInputDecoration('Codigo SMS'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFFF98A5), fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSendingCode || _isSubmittingCode
                      ? null
                      : () {
                          widget.onCancel();
                          Navigator.of(context).pop();
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3D4556)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSendingCode || _isSubmittingCode
                      ? null
                      : _submitCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3C78D8),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _isSendingCode || _isSubmittingCode
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirmar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _isSendingCode || _isSubmittingCode ? null : _sendCode,
              child: const Text('Reenviar codigo'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _mfaInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFBDBDBD)),
      filled: true,
      fillColor: const Color(0xFF242424),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF323232)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF3C78D8), width: 1.4),
      ),
    );
  }
}

class _PostLoginLoadingDialog extends StatelessWidget {
  const _PostLoginLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 232,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF13161D),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF2A3140)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 26,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MesclaBrandLogo(size: 86),
              SizedBox(height: 18),
              Text(
                'Conectando ao Mescla Invest',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Estamos preparando seu ambiente de investimento.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFB8C1D1),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 18),
              SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFF84B5FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSuccessLoadingState extends StatelessWidget {
  const _SheetSuccessLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MesclaBrandLogo(size: 74),
          SizedBox(height: 18),
          Text(
            'Login concluido',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Redirecionando voce para a plataforma.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFBDBDBD),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          SizedBox(height: 22),
          SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Color(0xFF84B5FF),
            ),
          ),
        ],
      ),
    );
  }
}
