import 'package:flutter/material.dart';

abstract final class SifaBrand {
  static const charcoal = Color(0xFF111111);
  static const gold = Color(0xFFD4AF37);
  static const deepGold = Color(0xFFB98920);
  static const ivory = Color(0xFFFAFAF8);
  static const paper = Color(0xFFFFFFFF);
  static const softGrey = Color(0xFFE5E5E5);
  static const textGrey = Color(0xFF6F7175);

  static const successBg = Color(0xFFEDF8EF);
  static const success = Color(0xFF278C4B);
  static const infoBg = Color(0xFFEDF5FC);
  static const info = Color(0xFF2678B8);
  static const goldBg = Color(0xFFFFF6DF);
}

class SifaBuildingMark extends StatelessWidget {
  final double size;
  final bool gold;

  const SifaBuildingMark({
    super.key,
    this.size = 38,
    this.gold = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SifaBuildingPainter(
        color: gold ? SifaBrand.gold : const Color(0xFF777A7F),
      ),
    );
  }
}

class _SifaBuildingPainter extends CustomPainter {
  final Color color;

  const _SifaBuildingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final base = h * 0.86;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.13, h * 0.48, w * 0.17, base - h * 0.48),
        Radius.circular(w * 0.025),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.34, h * 0.30, w * 0.18, base - h * 0.30),
        Radius.circular(w * 0.025),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.56, h * 0.12, w * 0.19, base - h * 0.12),
        Radius.circular(w * 0.025),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.78, h * 0.55, w * 0.10, base - h * 0.55),
        Radius.circular(w * 0.02),
      ),
      paint,
    );

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(w * 0.05, h * 0.89)
      ..quadraticBezierTo(w * 0.50, h * 0.76, w * 0.95, h * 0.89);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _SifaBuildingPainter oldDelegate) =>
      oldDelegate.color != color;
}

class SifaSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SifaSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: SifaBrand.charcoal,
                ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!),
          ),
      ],
    );
  }
}
