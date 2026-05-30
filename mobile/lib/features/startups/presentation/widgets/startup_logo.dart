/// Thiago Ryuji Ogawa - RA:24024450
///
/// Widget reutilizavel das telas de startups.
/// Padroniza elementos visuais usados no marketplace e melhora a
/// consistencia das informacoes apresentadas ao investidor.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StartupLogo extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  final double fontSize;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  const StartupLogo({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.size,
    required this.fontSize,
    required this.backgroundColor,
    required this.borderColor,
    this.borderWidth = 1,
  });

  String get _initial {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed.characters.first.toUpperCase();
  }

  bool get _hasPhotoUrl {
    final value = photoUrl?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get _isSvgUrl {
    final value = photoUrl?.trim().toLowerCase();
    return value != null && value.contains('.svg');
  }

  Widget _buildFallback() {
    return Center(
      child: Text(
        _initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildZoomed(Widget child) {
    return Transform.scale(scale: 1.14, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: !_hasPhotoUrl
          ? _buildFallback()
          : _isSvgUrl
          ? _buildZoomed(
              SvgPicture.network(
                photoUrl!.trim(),
                fit: BoxFit.cover,
                placeholderBuilder: (context) => _buildFallback(),
              ),
            )
          : _buildZoomed(
              Image.network(
                photoUrl!.trim(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallback(),
              ),
            ),
    );
  }
}
