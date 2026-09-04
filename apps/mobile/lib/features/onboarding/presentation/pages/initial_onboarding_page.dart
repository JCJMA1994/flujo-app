import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/flujo_logo.dart';

// ──────────────────────────────────────────────────────────────────────────
//  Colores fijos del onboarding (siempre oscuro, premium)
// ──────────────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF050A14);
const _kSurface = Color(0xFF0F172A);
const _kBorder = Color(0xFF1E293B);
const _kTextPrimary = Color(0xFFF1F5F9);
const _kTextSecondary = Color(0xFF94A3B8);
const _kAccent = Color(0xFF2DD4BF);

class InitialOnboardingPage extends StatefulWidget {
  const InitialOnboardingPage({super.key});

  @override
  State<InitialOnboardingPage> createState() => _InitialOnboardingPageState();
}

class _InitialOnboardingPageState extends State<InitialOnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _Slide(
      icon: Icons.pie_chart_rounded,
      gradient: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
      title: 'Control Total de\ntu Dinero',
      body:
          'Visualiza tu balance mensual y el promedio de gasto diario en tiempo real. Nunca más te pases de presupuesto.',
      chips: ['📊 Balance en vivo', '⚡ Promedio/día', '🔒 100% Offline'],
    ),
    _Slide(
      icon: Icons.auto_awesome_rounded,
      gradient: [Color(0xFF4F46E5), Color(0xFF818CF8)],
      title: 'Captura Inteligente\ncon IA',
      body:
          'Comparte el voucher de Yape o Plin directamente a Flujo, o dejá que capture las notificaciones en segundo plano. Cero digitación.',
      chips: ['📱 Yape & Plin', '🧠 Gemini IA', '🔔 Segundo plano'],
    ),
    _Slide(
      icon: Icons.storefront_rounded,
      gradient: [Color(0xFF0284C7), Color(0xFF38BDF8)],
      title: 'Personal vs.\nNegocio',
      body:
          'Separa tus gastos diarios de las ventas de tu negocio o Yape Empresa con un solo toque. Cuentas claras.',
      chips: ['💼 Modo Negocio', '👤 Modo Personal', '📑 Métricas'],
    ),
  ];

  Future<void> _finish() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'has_seen_onboarding', value: 'true');
    if (mounted) context.go(AppRoutes.dashboard);
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _kBg,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const FlujoLogo(size: 32, showGlow: true),
                  const SizedBox(width: 10),
                  const Text(
                    'Flujo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _kTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (!isLast)
                    GestureDetector(
                      onTap: _finish,
                      child: const Text(
                        'Omitir',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kTextSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Slides ──────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _SlideView(data: _slides[i]),
              ),
            ),

            // ── Indicadores + Botón ─────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + bottomPad),
              child: Row(
                children: [
                  // Dots
                  ...List.generate(_slides.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 6),
                      width: active ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? _kAccent : _kBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                  const Spacer(),

                  // CTA
                  GestureDetector(
                    onTap: _next,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal: isLast ? 28 : 22,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLast ? 'Comenzar' : 'Continuar',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isLast
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Vista individual de cada slide
// ──────────────────────────────────────────────────────────────────────────
class _SlideView extends StatelessWidget {
  const _SlideView({required this.data});
  final _Slide data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono héroe con glow
          if (data.icon == Icons.pie_chart_rounded)
            const FlujoLogo(size: 120, showGlow: true)
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: data.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: data.gradient.first.withValues(alpha: 0.4),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Icon(data.icon, size: 56, color: Colors.white),
            ),
          const SizedBox(height: 40),

          // Título
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _kTextPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Descripción
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: _kTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Chips de features
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: data.chips.map((label) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kBorder),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Modelo de datos
// ──────────────────────────────────────────────────────────────────────────
class _Slide {
  const _Slide({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.body,
    required this.chips,
  });
  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String body;
  final List<String> chips;
}
