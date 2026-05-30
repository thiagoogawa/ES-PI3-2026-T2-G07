/// Thiago Ryuji Ogawa - RA:24024450
///
/// Tela de transicao apos autenticacao.
/// Resolve carregamento inicial e encaminha o usuario para a home
/// adequada conforme o contexto de sessao.

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/auth_api_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../controllers/auth_controller.dart';
import '../widgets/mescla_brand_logo.dart';
import 'app_home_router.dart';
import 'login_page.dart';

class StartupSplashPage extends StatefulWidget {
  const StartupSplashPage({super.key});

  @override
  State<StartupSplashPage> createState() => _StartupSplashPageState();
}

class _StartupSplashPageState extends State<StartupSplashPage>
    with SingleTickerProviderStateMixin {
  late final AuthController _authController;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _authController = AuthController(
      AuthRepositoryImpl(
        AuthRemoteDataSource(),
        AuthApiDataSource(ApiClient()),
      ),
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
    _resolveInitialRoute();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _resolveInitialRoute() async {
    await Future.wait([
      _authController.restoreSession(),
      Future<void>.delayed(const Duration(milliseconds: 1900)),
    ]);

    if (!mounted) {
      return;
    }

    final currentUser = _authController.currentUser;
    final nextPage = currentUser == null
        ? const LoginPage()
        : buildHomePageForUser(currentUser);

    Navigator.of(context).pushReplacement(_buildRoute(nextPage));
  }

  Route<void> _buildRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final opacity = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(opacity);

        return FadeTransition(
          opacity: opacity,
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B11), Color(0xFF111723), Color(0xFF1B263B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: child,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1AE40062),
                          blurRadius: 34,
                          spreadRadius: 4,
                          offset: Offset(0, 22),
                        ),
                      ],
                    ),
                    child: const MesclaBrandLogo(size: 152),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'MesclaInvest',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Capital inteligente para startups de alto potencial',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD4DCEC),
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Color(0xFF84B5FF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
