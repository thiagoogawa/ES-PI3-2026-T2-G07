/// Thiago Ryuji Ogawa - RA:24024450
///
/// Widget auxiliar do fluxo de logout.
/// Centraliza a confirmacao de saida e o encerramento seguro da
/// sessao para evitar repeticao nas telas autenticadas.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/app_snackbar.dart';
import 'mescla_brand_logo.dart';
import '../pages/login_page.dart';

Future<void> performLogoutFlow(BuildContext context) async {
  if (!context.mounted) {
    return;
  }

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Encerrando sessao',
    barrierColor: const Color(0xCC090B10),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return const _LogoutLoadingDialog();
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final scaleAnimation = Tween<double>(
        begin: 0.95,
        end: 1.0,
      ).animate(curvedAnimation);

      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(scale: scaleAnimation, child: child),
      );
    },
  );

  try {
    await Future.wait([
      FirebaseAuth.instance.signOut(),
      Future<void>.delayed(const Duration(milliseconds: 850)),
    ]);
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    Navigator.of(context, rootNavigator: true).pop();
    showAppSnackBar(
      context,
      message: 'Nao foi possivel sair agora. Tente novamente.',
      type: AppSnackBarType.error,
    );
    return;
  }

  if (!context.mounted) {
    return;
  }

  Navigator.of(context, rootNavigator: true).pop();
  Navigator.of(
    context,
  ).pushAndRemoveUntil(_buildLoginRoute(), (route) => false);
}

Route<void> _buildLoginRoute() {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const LoginPage();
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

class _LogoutLoadingDialog extends StatelessWidget {
  const _LogoutLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 228,
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
              MesclaBrandLogo(size: 84),
              SizedBox(height: 18),
              Text(
                'Saindo da conta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Encerrando sua sessao com seguranca.',
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
