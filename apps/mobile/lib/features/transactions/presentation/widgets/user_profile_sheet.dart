import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../data/services/transaction_export_service.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/usecases.dart';

class UserProfileSheet extends StatefulWidget {
  const UserProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const UserProfileSheet(),
    );
  }

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
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
        backgroundColor: value ? Colors.green : Colors.grey[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleExport(BuildContext context) async {
    try {
      final repository = getIt<TransactionRepository>();
      final transactions =
          await repository.watchTransactions(const TransactionFilter()).first;
      if (transactions.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay transacciones registradas para exportar.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final exportService = getIt<TransactionExportService>();
      await exportService.shareCsv(transactions: transactions);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar transacciones: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    final syncUseCase = getIt<SyncPendingTransactions>();
    final result = await syncUseCase();

    if (!mounted) return;
    setState(() => _isSyncing = false);

    result.fold(
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronización completada con éxito'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar: ${failure.message}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
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
      Navigator.of(context).pop(); // Cierra el bottom sheet
      await context.read<AuthCubit>().logout();
      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (prev, curr) =>
          prev.user != curr.user || prev.status != curr.status,
      builder: (context, state) {
        final user = state.user;
        final name = user?.name ?? 'Usuario';
        final email = user?.email ?? 'Sin correo';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    initial,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                ListTile(
                  leading: _isSyncing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  title: const Text('Sincronizar ahora'),
                  subtitle: const Text(
                    'Envía pendientes y recibe movimientos nuevos',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _isSyncing ? null : _handleSync,
                ),
                ListTile(
                  leading: const Icon(Icons.mark_email_read_rounded),
                  title: const Text('Captura por Correo (iOS & Gmail)'),
                  subtitle:
                      const Text('Comprobantes de BCP, BBVA, Interbank y Yape'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.captureOnboarding);
                  },
                ),
                const ListTile(
                  leading: Icon(Icons.security_rounded),
                  title: Text('Seguridad y Sesión'),
                  subtitle: Text('Token JWT seguro y almacenamiento cifrado'),
                  trailing:
                      Icon(Icons.verified_user_rounded, color: Colors.green),
                ),
                if (_biometricsAvailable)
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint_rounded),
                    title: const Text('Bloqueo biométrico'),
                    subtitle:
                        const Text('Solicita huella o rostro al abrir Flujo'),
                    value: _isBiometricEnabled,
                    onChanged: _handleBiometricToggle,
                  ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Exportar transacciones'),
                  subtitle:
                      const Text('Descargar reporte en formato CSV / Excel'),
                  onTap: () => _handleExport(context),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: Icon(
                      Icons.logout_rounded,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      'Cerrar sesión',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
