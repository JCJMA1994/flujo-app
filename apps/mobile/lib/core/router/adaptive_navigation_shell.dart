import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/capture/presentation/cubit/capture_cubit.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../features/transactions/presentation/widgets/review_transaction_sheet.dart';
import '../di/injection.dart';
import '../services/local_notification_service.dart';
import '../widgets/flujo_logo.dart';
import '../widgets/quick_action_hub_sheet.dart';

/// Shell adaptativo que provee una barra de navegación inferior moderna tipo dock
/// con botón central de acción rápida en pantallas móviles (< 720px) y un NavigationRail lateral en pantallas
/// amplias (tablets, foldables o escritorios >= 720px).
class AdaptiveNavigationShell extends StatefulWidget {
  const AdaptiveNavigationShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  static const double _breakpoint = 720;

  @override
  State<AdaptiveNavigationShell> createState() =>
      _AdaptiveNavigationShellState();
}

class _AdaptiveNavigationShellState extends State<AdaptiveNavigationShell> {
  StreamSubscription<String>? _reviewSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToReviewRequests();
    });
  }

  void _subscribeToReviewRequests() {
    if (!getIt.isRegistered<LocalNotificationService>()) return;
    final notifService = getIt<LocalNotificationService>();

    final pendingId = notifService.pendingReviewId;
    if (pendingId != null) {
      notifService.clearPendingReviewId();
      _openReviewFor(pendingId);
    }

    _reviewSubscription = notifService.onReviewRequested.listen(_openReviewFor);
  }

  Future<void> _openReviewFor(String transactionId) async {
    if (!mounted) return;
    if (!getIt.isRegistered<TransactionRepository>()) return;

    final tx =
        await getIt<TransactionRepository>().getTransaction(transactionId);
    if (tx != null && mounted) {
      await ReviewTransactionSheet.show(context, tx);
    }
  }

  @override
  void dispose() {
    _reviewSubscription?.cancel();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isLargeScreen = width >= AdaptiveNavigationShell._breakpoint;

    return BlocBuilder<CaptureCubit, CaptureState>(
      buildWhen: (prev, curr) => prev.permission != curr.permission,
      builder: (context, captureState) {
        final isCaptureActive =
            captureState.permission == CapturePermission.granted;

        if (isLargeScreen) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        FlujoLogo(size: 42, showGlow: true),
                        SizedBox(height: 8),
                        Text(
                          'Flujo',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: FloatingActionButton.small(
                          onPressed: () => QuickActionHubSheet.show(context),
                          tooltip: 'Acción rápida',
                          child: const Icon(LucideIcons.plus),
                        ),
                      ),
                    ),
                  ),
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(LucideIcons.layoutDashboard),
                      selectedIcon: Icon(LucideIcons.layoutDashboard),
                      label: Text('Inicio'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(LucideIcons.receipt),
                      selectedIcon: Icon(LucideIcons.receipt),
                      label: Text('Movimientos'),
                    ),
                    NavigationRailDestination(
                      icon: Badge(
                        isLabelVisible: isCaptureActive,
                        backgroundColor: const Color(0xFF10B981),
                        smallSize: 8,
                        child: const Icon(LucideIcons.zap),
                      ),
                      label: const Text('Captura'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(LucideIcons.user),
                      selectedIcon: Icon(LucideIcons.user),
                      label: Text('Perfil'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: widget.navigationShell,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: widget.navigationShell,
          bottomNavigationBar: _FlujoBottomBar(
            currentIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            isCaptureActive: isCaptureActive,
            onCenterAction: () => QuickActionHubSheet.show(context),
          ),
        );
      },
    );
  }
}

/// Barra de navegación inferior estilizada tipo Dock fintech con botón central flotante.
class _FlujoBottomBar extends StatelessWidget {
  const _FlujoBottomBar({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.isCaptureActive,
    required this.onCenterAction,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isCaptureActive;
  final VoidCallback onCenterAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding:
          EdgeInsets.fromLTRB(12, 6, 12, bottomInset > 0 ? bottomInset : 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Inicio
          _NavTabItem(
            label: 'Inicio',
            icon: LucideIcons.layoutDashboard,
            activeIcon: LucideIcons.layoutDashboard,
            isSelected: currentIndex == 0,
            onTap: () => onDestinationSelected(0),
          ),

          // 2. Movimientos
          _NavTabItem(
            label: 'Movimientos',
            icon: LucideIcons.receipt,
            activeIcon: LucideIcons.receipt,
            isSelected: currentIndex == 1,
            onTap: () => onDestinationSelected(1),
          ),

          // 3. Botón Central Flotante Elevado (+)
          _CenterActionButton(onPressed: onCenterAction),

          // 4. Captura
          _NavTabItem(
            label: 'Captura',
            icon: LucideIcons.zap,
            activeIcon: LucideIcons.zap,
            isSelected: currentIndex == 2,
            isBadgeVisible: isCaptureActive,
            onTap: () => onDestinationSelected(2),
          ),

          // 5. Perfil
          _NavTabItem(
            label: 'Perfil',
            icon: LucideIcons.user,
            activeIcon: LucideIcons.user,
            isSelected: currentIndex == 3,
            onTap: () => onDestinationSelected(3),
          ),
        ],
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  const _NavTabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isSelected,
    required this.onTap,
    this.isBadgeVisible = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final bool isBadgeVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    Widget iconWidget = Icon(
      isSelected ? activeIcon : icon,
      size: 24,
      color: isSelected ? activeColor : inactiveColor,
    );

    if (isBadgeVisible) {
      iconWidget = Badge(
        backgroundColor: const Color(0xFF10B981),
        smallSize: 8,
        child: iconWidget,
      );
    }

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterActionButton extends StatelessWidget {
  const _CenterActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF2DD4BF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          LucideIcons.plus,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
