/// Thiago Ryuji Ogawa - RA:24024450
///
/// Utilitario compartilhado entre diferentes fluxos do mobile.
/// Centraliza comportamento reaproveitavel para reduzir duplicacao
/// e manter a interface mais consistente.

import 'package:flutter/material.dart';

enum AppSnackBarType { error, success, info }

void showAppSnackBar(
  BuildContext context, {
  required String message,
  AppSnackBarType type = AppSnackBarType.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = _snackBarScheme(type);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: scheme.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.border),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow,
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: scheme.iconSurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(scheme.icon, color: scheme.iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: scheme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
}

_AppSnackBarScheme _snackBarScheme(AppSnackBarType type) {
  switch (type) {
    case AppSnackBarType.error:
      return const _AppSnackBarScheme(
        background: Color(0xFF181317),
        border: Color(0xFF3B2933),
        iconSurface: Color(0xFF251922),
        iconColor: Color(0xFFE39AB0),
        textColor: Color(0xFFF7EEF2),
        shadow: Color(0x26110D10),
        icon: Icons.error_outline_rounded,
      );
    case AppSnackBarType.success:
      return const _AppSnackBarScheme(
        background: Color(0xFF141A18),
        border: Color(0xFF293833),
        iconSurface: Color(0xFF192521),
        iconColor: Color(0xFF8CC9AF),
        textColor: Color(0xFFF1F7F4),
        shadow: Color(0x26101010),
        icon: Icons.check_circle_outline_rounded,
      );
    case AppSnackBarType.info:
      return const _AppSnackBarScheme(
        background: Color(0xFF131821),
        border: Color(0xFF2C3644),
        iconSurface: Color(0xFF172232),
        iconColor: Color(0xFF8DB8F4),
        textColor: Color(0xFFF0F5FC),
        shadow: Color(0x26101216),
        icon: Icons.info_outline_rounded,
      );
  }
}

class _AppSnackBarScheme {
  final Color background;
  final Color border;
  final Color iconSurface;
  final Color iconColor;
  final Color textColor;
  final Color shadow;
  final IconData icon;

  const _AppSnackBarScheme({
    required this.background,
    required this.border,
    required this.iconSurface,
    required this.iconColor,
    required this.textColor,
    required this.shadow,
    required this.icon,
  });
}
