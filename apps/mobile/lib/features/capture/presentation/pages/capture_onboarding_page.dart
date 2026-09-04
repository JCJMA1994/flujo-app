import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/flujo_logo.dart';
import '../cubit/capture_cubit.dart';

/// El permiso de lectura de notificaciones asusta si se pide en frío.
/// Esta pantalla explica exactamente qué se lee y qué no antes de mandar
/// al usuario a Ajustes.
class CaptureOnboardingPage extends StatelessWidget {
  const CaptureOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CaptureOnboardingView();
  }
}

class _CaptureOnboardingView extends StatefulWidget {
  const _CaptureOnboardingView();

  @override
  State<_CaptureOnboardingView> createState() => _CaptureOnboardingViewState();
}

class _CaptureOnboardingViewState extends State<_CaptureOnboardingView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<CaptureCubit>().checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de Ajustes de Android, revalidamos el permiso automáticamente.
    if (state == AppLifecycleState.resumed) {
      context.read<CaptureCubit>().checkPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captura con Inteligencia Artificial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reverificar permiso',
            onPressed: () => context.read<CaptureCubit>().checkPermission(),
          ),
        ],
      ),
      body: BlocBuilder<CaptureCubit, CaptureState>(
        buildWhen: (p, c) => p.permission != c.permission,
        builder: (context, state) {
          if (state.permission == CapturePermission.unsupported) {
            return const _UnsupportedView();
          }

          final isGranted = state.permission == CapturePermission.granted;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const FlujoLogo(size: 48, showGlow: true),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deja que Flujo anote por ti',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'IA en segundo plano para Yape, Plin y bancos',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Detecta automáticamente cada Yape, Yape Empresa, Plin y consumo bancario usando IA.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                const SizedBox(height: 24),
                const _Bullet(
                  icon: Icons.flash_on_rounded,
                  text: 'Instantáneo: El registro se crea en el momento exacto '
                      'en que recibes la notificación.',
                ),
                const _Bullet(
                  icon: Icons.storefront_rounded,
                  text: 'Personal y Empresa: Reconoce y clasifica movimientos '
                      'personales de los de negocio (Yape Empresa, RUC).',
                ),
                const _Bullet(
                  icon: Icons.wifi_rounded,
                  text:
                      'Conexión a internet: Al igual que tus pagos en Yape o bancos, '
                      'requiere internet activo para interpretar la transacción con la IA.',
                ),
                const _Bullet(
                  icon: Icons.shield_outlined,
                  text:
                      'Privacidad garantizada: Solo procesamos notificaciones de apps '
                      'financieras autorizadas (Yape, Plin, BCP, BBVA, Interbank).',
                ),
                const SizedBox(height: 24),
                if (isGranted)
                  const _GrantedBanner()
                else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 22,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Al tocar el botón se abrirán los Ajustes de Android. '
                            'Busca "Flujo" en la lista y activa el interruptor.',
                            style: TextStyle(fontSize: 13, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.read<CaptureCubit>().requestPermission(),
                      icon: const Icon(Icons.settings_suggest_rounded),
                      label: const Text('Activar en Ajustes de Android'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.battery_saver_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Captura con app cerrada (Xiaomi / Android)',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Para que Android no suspenda Flujo al cerrar la app y capture tus pagos de Yape automáticamente, configura la batería en "Sin restricciones" y activa "Inicio automático".',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          const MethodChannel('com.flujo.app/share')
                              .invokeMethod(
                            'requestIgnoreBatteryOptimizations',
                          );
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text(
                          'Configurar Batería (Sin restricciones)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Puedes desactivarlo en cualquier momento desde los Ajustes.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
        },
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrantedBanner extends StatelessWidget {
  const _GrantedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Captura con IA activa!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Flujo interpreta tus notificaciones con Google Gemini y registra tus movimientos al instante.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_email_read_rounded,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Captura automática en iOS',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'iOS no permite que una aplicación lea las notificaciones de otra en segundo plano. '
            'Sin embargo, Flujo puede capturar tus compras y pagos directamente desde los comprobantes '
            'que BCP, BBVA, Interbank y Yape te envían al correo.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          const _Bullet(
            icon: Icons.security_rounded,
            text: 'Conexión oficial con Google OAuth 2.0 en modo solo lectura.',
          ),
          const _Bullet(
            icon: Icons.shield_outlined,
            text:
                'Privacidad total: solo filtramos y procesamos correos de dominios bancarios verificados.',
          ),
          const _Bullet(
            icon: Icons.sync_rounded,
            text:
                'Sincronización en la nube mediante webhooks seguros de Google Cloud Pub/Sub.',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Abriendo autorización segura de Google...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Vincular cuenta de Gmail'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
