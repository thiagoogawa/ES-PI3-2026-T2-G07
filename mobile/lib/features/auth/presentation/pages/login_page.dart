/// Thiago Ryuji Ogawa - RA:24024450
/// Lucca Schroelder Scovini - RA: 24011609
///
/// Tela de entrada de usuario.
/// Agrupa autenticacao, feedback de erro e navegacao inicial para
/// usuarios que ainda nao possuem sessao valida.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/errors/auth_exception_mapper.dart';
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
  late final AuthRemoteDataSource _authRemoteDataSource;
  late final AuthApiDataSource _authApiDataSource;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isCompletingLoginTransition = false;
  BuildContext? _authSheetContext;

  @override
  void initState() {
    super.initState();

    _authRemoteDataSource = AuthRemoteDataSource();
    _authApiDataSource = AuthApiDataSource(ApiClient());

    controller = AuthController(
      AuthRepositoryImpl(_authRemoteDataSource, _authApiDataSource),
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

    final resolver = controller.pendingSecondFactorResolver;
    if (resolver == null || !mounted) {
      return;
    }

    if (_authSheetContext != null) {
      Navigator.of(_authSheetContext!).pop();
      _authSheetContext = null;
    }

    final authenticatedUser = await showModalBottomSheet<AuthenticatedUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MfaSignInSheet(
        resolver: resolver,
        authRemoteDataSource: _authRemoteDataSource,
        authApiDataSource: _authApiDataSource,
      ),
    );

    controller.clearPendingSecondFactorResolver();

    if (authenticatedUser != null && mounted) {
      await _handleAuthenticatedUser(authenticatedUser);
    }
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

class _MfaSignInSheet extends StatefulWidget {
  final MultiFactorResolver resolver;
  final AuthRemoteDataSource authRemoteDataSource;
  final AuthApiDataSource authApiDataSource;

  const _MfaSignInSheet({
    required this.resolver,
    required this.authRemoteDataSource,
    required this.authApiDataSource,
  });

  @override
  State<_MfaSignInSheet> createState() => _MfaSignInSheetState();
}

class _MfaSignInSheetState extends State<_MfaSignInSheet> {
  late final List<AuthSecondFactor> _factors;
  final _codeController = TextEditingController();
  int _selectedFactorIndex = 0;
  bool _isSendingCode = false;
  bool _isConfirmingCode = false;
  AuthPhoneVerificationRequest? _verificationRequest;

  @override
  void initState() {
    super.initState();
    _factors = widget.authRemoteDataSource.mapSecondFactors(
      widget.resolver.hints,
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  AuthSecondFactor get _selectedFactor => _factors[_selectedFactorIndex];

  Future<void> _sendCode() async {
    setState(() {
      _isSendingCode = true;
    });

    try {
      final request = await widget.authRemoteDataSource.startSecondFactorSignIn(
        widget.resolver,
        factor: _selectedFactor,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _verificationRequest = request;
      });

      if (request.wasAutoVerified) {
        await _confirmCode();
        return;
      }

      showAppSnackBar(
        context,
        message:
            'Codigo SMS enviado para ${_selectedFactor.phoneNumber ?? 'o fator selecionado'}.',
        type: AppSnackBarType.success,
      );
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
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _confirmCode() async {
    final request = _verificationRequest;
    if (request == null) {
      showAppSnackBar(
        context,
        message: 'Solicite o codigo SMS antes de confirmar o acesso.',
        type: AppSnackBarType.error,
      );
      return;
    }

    if (!request.wasAutoVerified && _codeController.text.trim().isEmpty) {
      showAppSnackBar(
        context,
        message: 'Digite o codigo enviado por SMS.',
        type: AppSnackBarType.error,
      );
      return;
    }

    setState(() {
      _isConfirmingCode = true;
    });

    try {
      await widget.authRemoteDataSource.resolveSecondFactorSignIn(
        resolver: widget.resolver,
        request: request,
        smsCode: _codeController.text.trim(),
      );
      final idToken = await widget.authRemoteDataSource.getIdToken(
        forceRefresh: true,
      );
      final user = await widget.authApiDataSource.fetchMe(idToken);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(user);
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
          _isConfirmingCode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRequestedCode = _verificationRequest != null;

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
            'Confirmacao em duas etapas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecione um fator cadastrado para receber o codigo de acesso.',
            style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
          ),
          const SizedBox(height: 20),
          ...List.generate(_factors.length, (index) {
            final factor = _factors[index];
            final isSelected = index == _selectedFactorIndex;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF202226),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF3C78D8)
                      : const Color(0xFF30353D),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: hasRequestedCode || _isSendingCode || _isConfirmingCode
                    ? null
                    : () {
                        setState(() {
                          _selectedFactorIndex = index;
                        });
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF84B5FF)
                                : const Color(0xFF566070),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFF84B5FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(height: 10, width: 10),
                                ),
                              )
                            : null,
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              factor.phoneNumber ?? 'Fator SMS configurado',
                              style: const TextStyle(color: Color(0xFFB7BCC8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (hasRequestedCode) ...[
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Codigo SMS',
                labelStyle: TextStyle(color: Color(0xFFBDBDBD)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSendingCode || _isConfirmingCode
                  ? null
                  : hasRequestedCode
                  ? _confirmCode
                  : _sendCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF346AC0),
                foregroundColor: Colors.white,
              ),
              child: _isSendingCode || _isConfirmingCode
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      hasRequestedCode ? 'Confirmar codigo' : 'Enviar codigo',
                    ),
            ),
          ),
          if (hasRequestedCode) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSendingCode || _isConfirmingCode
                    ? null
                    : () {
                        setState(() {
                          _verificationRequest = null;
                          _codeController.clear();
                        });
                      },
                child: const Text('Escolher outro fator'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
