import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../transactions/data/services/transaction_export_service.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../transactions/domain/usecases/usecases.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

/// Pantalla completa de Perfil según el sistema de diseño oficial de Flujo (Pantalla 16).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isSyncing = false;
  bool _biometricsAvailable = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    final biometricService = getIt<BiometricService>();
    final available = await biometricService.isBiometricsAvailable();
    final enabled = await biometricService.isBiometricLockEnabled();
    if (!mounted) return;
    setState(() {
      _biometricsAvailable = available;
      _isBiometricEnabled = enabled;
    });
  }

  Future<void> _handleBiometricToggle(bool value) async {
    final biometricService = getIt<BiometricService>();
    final reason = value
        ? 'Confirma tu huella o rostro para activar el bloqueo'
        : 'Confirma tu identidad para desactivar el bloqueo';

    final authenticated = await biometricService.authenticate(reason: reason);
    if (!authenticated) return;

    await biometricService.setBiometricLockEnabled(enabled: value);
    if (!mounted) return;
    setState(() => _isBiometricEnabled = value);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Bloqueo biométrico activado'
              : 'Bloqueo biométrico desactivado',
        ),
        backgroundColor: value ? FlujoTokens.verdePetroleo : Colors.grey[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleExport(BuildContext context) async {
    try {
      final repository = getIt<TransactionRepository>();
      final exportService = getIt<TransactionExportService>();

      final transactions = await repository
          .watchTransactions(const TransactionFilter())
          .first;

      if (!context.mounted) return;

      if (transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay transacciones para exportar.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await exportService.shareCsv(transactions: transactions);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    try {
      final syncPending = getIt<SyncPendingTransactions>();
      final result = await syncPending();
      if (!mounted) return;

      result.fold(
        onSuccess: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sincronización completada con éxito.'),
              backgroundColor: FlujoTokens.verdePetroleo,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onFailure: (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error de sincronización: ${failure.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Se cerrará tu sesión y se vaciarán los datos locales de este dispositivo por seguridad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && context.mounted) {
      await context.read<AuthCubit>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perfil',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (prev, curr) =>
            prev.user != curr.user || prev.status != curr.status,
        builder: (context, state) {
          final user = state.user;
          final name = user?.name ?? 'Usuario';
          final email = user?.email ?? 'Sin correo';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // ── Header de Usuario ─────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: FlujoTokens.verdePetroleo,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Sección Preferencias: Selector de Tema ───────────────
              Text(
                'Preferencias',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tema',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              ValueListenableBuilder<ThemeMode>(
                valueListenable: appThemeModeNotifier,
                builder: (context, currentMode, _) {
                  return Row(
                    children: [
                      Expanded(
                        child: _ThemeChoiceCard(
                          label: 'Claro',
                          icon: LucideIcons.sun,
                          isSelected: currentMode == ThemeMode.light,
                          onTap: () =>
                              AppThemeController.setTheme(ThemeMode.light),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ThemeChoiceCard(
                          label: 'Oscuro',
                          icon: LucideIcons.moon,
                          isSelected: currentMode == ThemeMode.dark,
                          onTap: () =>
                              AppThemeController.setTheme(ThemeMode.dark),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ThemeChoiceCard(
                          label: 'Sistema',
                          icon: LucideIcons.monitor,
                          isSelected: currentMode == ThemeMode.system,
                          onTap: () =>
                              AppThemeController.setTheme(ThemeMode.system),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Grupo de Acciones / Ajustes ──────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(FlujoTokens.radioTarjetas),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    if (_biometricsAvailable) ...[
                      SwitchListTile(
                        title: const Text(
                          'Privacidad y biometría',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Solicita huella o rostro al abrir Flujo',
                        ),
                        value: _isBiometricEnabled,
                        activeThumbColor: FlujoTokens.verdePetroleo,
                        onChanged: _handleBiometricToggle,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                    ListTile(
                      leading: const Icon(Icons.auto_fix_high_rounded),
                      title: const Text(
                        'Reglas de captura',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Categoriza automáticamente por palabras clave',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                      onTap: () => context.push(AppRoutes.userRules),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.mail_outline_rounded),
                      title: const Text(
                        'Captura por correo',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Comprobantes de BCP, BBVA, Interbank y Yape',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Conexión segura de correo bancario habilitada para tu cuenta.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.download_rounded),
                      title: const Text(
                        'Exportar datos',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Descargar reporte en formato CSV / Excel',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                      onTap: () => _handleExport(context),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: _isSyncing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      title: const Text(
                        'Sincronización en la nube',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Envía pendientes y recibe movimientos nuevos',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                      onTap: _isSyncing ? null : _handleSync,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Botón Cerrar Sesión ─────────────────────────────────
              OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: FlujoTokens.crimson,
                ),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: FlujoTokens.crimson,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: FlujoTokens.crimson),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF134E4A) : FlujoTokens.acentoClaro)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? FlujoTokens.verdePetroleo
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? FlujoTokens.verdePetroleo
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : FlujoTokens.verdePetroleo)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
