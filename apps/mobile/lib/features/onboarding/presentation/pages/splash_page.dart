import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _pulseController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<double> _loadingFade;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF050A14),
      ),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );
    _loadingFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.6, 1, curve: Curves.easeOut),
    );

    _logoController.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    const storage = FlutterSecureStorage();
    final seen = await storage.read(key: 'has_seen_onboarding');
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    context.go(seen == 'true' ? AppRoutes.dashboard : AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A14),
      body: Stack(
        children: [
          // ── Fondo con gradientes radiales ──
          Positioned.fill(
            child: CustomPaint(painter: _SplashBgPainter()),
          ),

          // ── Contenido central ──
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo animado con glow
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, child) {
                        final glow = 0.25 + _pulseController.value * 0.15;
                        return Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2DD4BF)
                                    .withValues(alpha: glow),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 52,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Nombre de la app
                FadeTransition(
                  opacity: _textFade,
                  child: const Text(
                    'Flujo',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Eslogan
                FadeTransition(
                  opacity: _textFade,
                  child: const Text(
                    'Tus finanzas claras, cada día',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Indicador de carga inferior ──
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _loadingFade,
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta gradientes radiales suaves para darle profundidad al splash.
class _SplashBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.4;
    final radius = size.width * 0.9;

    // Glow esmeralda superior
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF0F766E).withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        ),
    );

    // Glow índigo inferior derecho
    final cx2 = size.width * 0.8;
    final cy2 = size.height * 0.7;
    canvas.drawCircle(
      Offset(cx2, cy2),
      radius * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF4F46E5).withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(cx2, cy2), radius: radius * 0.7),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
