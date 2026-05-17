import 'package:flutter/material.dart';

class MesclaBrandLogo extends StatelessWidget {
  final double size;

  const MesclaBrandLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            spreadRadius: 1,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(painter: _MesclaBrandLogoPainter()),
    );
  }
}

class _MesclaBrandLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pinkPaint = Paint()
      ..color = const Color(0xFFE40062)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pinkPath = Path()
      ..moveTo(size.width * 0.18, size.height * 0.26)
      ..lineTo(size.width * 0.76, size.height * 0.26)
      ..lineTo(size.width * 0.76, size.height * 0.68);

    final whitePath = Path()
      ..moveTo(size.width * 0.18, size.height * 0.48)
      ..lineTo(size.width * 0.18, size.height * 0.78)
      ..lineTo(size.width * 0.76, size.height * 0.78);

    canvas.drawPath(pinkPath, pinkPaint);
    canvas.drawPath(whitePath, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
