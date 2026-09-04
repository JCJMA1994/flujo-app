import 'package:flutter/material.dart';

/// Componente de marca oficial para el logo de Flujo.
class FlujoLogo extends StatelessWidget {
  const FlujoLogo({
    super.key,
    this.size = 36,
    this.borderRadius,
    this.showGlow = false,
  });

  final double size;
  final BorderRadius? borderRadius;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(size * 0.28);

    final image = ClipRRect(
      borderRadius: effectiveRadius,
      child: Image.asset(
        'assets/images/flujo_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: effectiveRadius,
          ),
          child: Icon(
            Icons.all_inclusive_rounded,
            size: size * 0.6,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (showGlow) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.35),
              blurRadius: size * 0.4,
              offset: Offset(0, size * 0.12),
            ),
          ],
        ),
        child: image,
      );
    }

    return image;
  }
}
