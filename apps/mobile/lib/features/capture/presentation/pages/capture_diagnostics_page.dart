import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/flujo_logo.dart';
import '../../domain/entities/parsed_expense.dart';
import '../cubit/capture_cubit.dart';

class CaptureDiagnosticsPage extends StatefulWidget {
  const CaptureDiagnosticsPage({super.key});

  @override
  State<CaptureDiagnosticsPage> createState() => _CaptureDiagnosticsPageState();
}

class _CaptureDiagnosticsPageState extends State<CaptureDiagnosticsPage> {
  @override
  void initState() {
    super.initState();
    context.read<CaptureCubit>().checkHealth();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlujoLogo(size: 24, showGlow: true),
            SizedBox(width: 8),
            Text('Diagnóstico de Captura'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar diagnóstico',
            onPressed: () => context.read<CaptureCubit>().checkHealth(),
          ),
        ],
      ),
      body: BlocBuilder<CaptureCubit, CaptureState>(
        buildWhen: (prev, current) =>
            prev.health != current.health ||
            prev.diagnostics != current.diagnostics ||
            prev.lastCaptured != current.lastCaptured ||
            prev.capturedCount != current.capturedCount,
        builder: (context, state) {
          final isPermissionGranted =
              state.permission == CapturePermission.granted;
          final isConnected = state.isListenerConnected;
          final isBatteryRestricted = state.isBatteryRestricted;
          final isAggressiveOem = state.isAggressiveOem;
          final diag = state.diagnostics;

          final pendingCount = diag['pendingCount'] ?? 0;
          final processedCount = diag['processedCount'] ?? 0;
          final failedCount = diag['failedCount'] ?? 0;
          final manufacturer = diag['manufacturer']?.toString() ?? 'Android';
          final model = diag['model']?.toString() ?? '';

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Tarjeta de Estado General ──
                  Card(
                    color:
                        _getHealthColor(state.health).withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _getHealthColor(state.health)
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _getHealthIcon(state.health),
                            color: _getHealthColor(state.health),
                            size: 36,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getHealthTitle(state.health),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getHealthColor(state.health),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getHealthSubtitle(state.health),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Checklist Técnico del Sistema ──
                  Text(
                    'Comprobación del Sistema',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  _ChecklistItem(
                    title: 'Acceso a notificaciones',
                    subtitle: isPermissionGranted
                        ? 'Permiso concedido en Ajustes'
                        : 'Falta autorizar en Notificaciones',
                    isValid: isPermissionGranted,
                    actionLabel: isPermissionGranted ? null : 'Activar',
                    onAction: () =>
                        context.read<CaptureCubit>().requestPermission(),
                  ),

                  _ChecklistItem(
                    title: 'Servicio en segundo plano',
                    subtitle: isConnected
                        ? 'Listener conectado al sistema Android'
                        : 'Servicio desvinculado por el SO',
                    isValid: isConnected,
                    actionLabel: isConnected ? null : 'Reconectar',
                    onAction: () =>
                        context.read<CaptureCubit>().rebindListener(),
                  ),

                  _ChecklistItem(
                    title: 'Optimización de batería',
                    subtitle: isBatteryRestricted
                        ? 'Restringida (riesgo de cierre por el SO)'
                        : 'Sin restricciones (óptimo)',
                    isValid: !isBatteryRestricted,
                    actionLabel: isBatteryRestricted ? 'Eximir' : null,
                    onAction: () => context
                        .read<CaptureCubit>()
                        .requestIgnoreBatteryOptimizations(),
                  ),

                  if (isAggressiveOem) ...[
                    _ChecklistItem(
                      title: 'Inicio automático ($manufacturer)',
                      subtitle: 'Requerido para evitar muerte del listener',
                      isValid: !state.isBatteryRestricted,
                      actionLabel: 'Configurar',
                      onAction: () =>
                          context.read<CaptureCubit>().openAutostartSettings(),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Buffer Nativo SQLite ──
                  Text(
                    'Métricas del Buffer RAW Nativo',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricColumn(
                            label: 'Pendientes',
                            value: '$pendingCount',
                            color: Colors.orange,
                          ),
                          _MetricColumn(
                            label: 'Procesadas',
                            value: '$processedCount',
                            color: Colors.green,
                          ),
                          _MetricColumn(
                            label: 'Fallidas',
                            value: '$failedCount',
                            color: Colors.redAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Dispositivo ──
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android),
                    title: Text('$manufacturer $model'),
                    subtitle:
                        Text('Android SDK ${diag['androidVersion'] ?? ''}'),
                  ),
                  const SizedBox(height: 16),

                  // ── Botón de Simulación de Prueba ──
                  OutlinedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Simular Notificación Yape (Prueba)'),
                    onPressed: () {
                      final fakeRaw = RawNotification(
                        packageName: 'com.bcp.innovacxion.yapeapp',
                        title: '¡Te acaban de yapear!',
                        body: 'Juan Pérez te envió S/ 25.00',
                        receivedAt: DateTime.now(),
                        notificationHash:
                            'fake_test_${DateTime.now().millisecondsSinceEpoch}',
                      );
                      // Disparamos la prueba directamente al cubit
                      context
                          .read<CaptureCubit>()
                          .simulateNotification(fakeRaw);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Simulación enviada al pipeline local'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getHealthColor(CaptureHealth health) {
    return switch (health) {
      CaptureHealth.ready => Colors.green,
      CaptureHealth.notificationPermissionMissing => Colors.red,
      CaptureHealth.listenerDisconnected => Colors.orange,
      CaptureHealth.batteryRestricted => Colors.amber.shade800,
      CaptureHealth.manufacturerConfigurationRequired => Colors.deepOrange,
      CaptureHealth.processingError => Colors.red,
    };
  }

  IconData _getHealthIcon(CaptureHealth health) {
    return switch (health) {
      CaptureHealth.ready => Icons.check_circle,
      CaptureHealth.notificationPermissionMissing => Icons.notifications_off,
      CaptureHealth.listenerDisconnected => Icons.link_off,
      CaptureHealth.batteryRestricted => Icons.battery_alert,
      CaptureHealth.manufacturerConfigurationRequired => Icons.settings_suggest,
      CaptureHealth.processingError => Icons.error_outline,
    };
  }

  String _getHealthTitle(CaptureHealth health) {
    return switch (health) {
      CaptureHealth.ready => 'Captura Activa y Óptima',
      CaptureHealth.notificationPermissionMissing =>
        'Falta Permiso de Notificaciones',
      CaptureHealth.listenerDisconnected => 'Servicio Desconectado',
      CaptureHealth.batteryRestricted => 'Batería Restringida',
      CaptureHealth.manufacturerConfigurationRequired =>
        'Ajuste de Inicio Automático Pendiente',
      CaptureHealth.processingError => 'Error en la Captura',
    };
  }

  String _getHealthSubtitle(CaptureHealth health) {
    return switch (health) {
      CaptureHealth.ready =>
        'Las notificaciones financieras se registrarán automáticamente.',
      CaptureHealth.notificationPermissionMissing =>
        'Concedé acceso a notificaciones para continuar.',
      CaptureHealth.listenerDisconnected =>
        'Android desvinculó el listener. Abre los ajustes para reconectar.',
      CaptureHealth.batteryRestricted =>
        'El ahorro de batería puede suspender la app cuando esté cerrada.',
      CaptureHealth.manufacturerConfigurationRequired =>
        'Configurá el inicio automático en tu dispositivo.',
      CaptureHealth.processingError =>
        'Ocurrió un inconveniente al inicializar el servicio.',
    };
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.title,
    required this.subtitle,
    required this.isValid,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final bool isValid;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isValid ? Icons.check_circle : Icons.warning_amber_rounded,
        color: isValid ? Colors.green : Colors.amber.shade800,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: actionLabel != null
          ? TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            )
          : null,
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
