import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/capture/presentation/cubit/capture_cubit.dart';
import '../../features/transactions/presentation/widgets/transaction_form_sheet.dart';

/// Shell adaptativo que provee una barra de navegación inferior (NavigationBar)
/// en pantallas móviles (< 720px) y un NavigationRail lateral en pantallas
/// amplias (tablets, foldables o escritorios >= 720px).
class AdaptiveNavigationShell extends StatelessWidget {
  const AdaptiveNavigationShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  static const double _breakpoint = 720;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isLargeScreen = width >= _breakpoint;

    return BlocBuilder<CaptureCubit, CaptureState>(
      builder: (context, captureState) {
        final isCaptureActive =
            captureState.permission == CapturePermission.granted;

        final destinations = [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Movimientos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_fix_high_outlined),
            selectedIcon: Icon(Icons.auto_fix_high_rounded),
            label: 'Reglas',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: isCaptureActive,
              backgroundColor: const Color(0xFF10B981),
              smallSize: 8,
              child: const Icon(Icons.bolt_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: isCaptureActive,
              backgroundColor: const Color(0xFF10B981),
              smallSize: 8,
              child: const Icon(Icons.bolt_rounded),
            ),
            label: 'Captura',
          ),
        ];

        if (isLargeScreen) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    theme.colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Flujo',
                          style: theme.textTheme.labelMedium?.copyWith(
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
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const TransactionFormSheet(),
                          ),
                          tooltip: 'Nuevo movimiento',
                          child: const Icon(Icons.add_rounded),
                        ),
                      ),
                    ),
                  ),
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: Text('Inicio'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Movimientos'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.auto_fix_high_outlined),
                      selectedIcon: Icon(Icons.auto_fix_high_rounded),
                      label: Text('Reglas'),
                    ),
                    NavigationRailDestination(
                      icon: Badge(
                        isLabelVisible: isCaptureActive,
                        backgroundColor: const Color(0xFF10B981),
                        smallSize: 8,
                        child: const Icon(Icons.bolt_outlined),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: isCaptureActive,
                        backgroundColor: const Color(0xFF10B981),
                        smallSize: 8,
                        child: const Icon(Icons.bolt_rounded),
                      ),
                      label: const Text('Captura'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: navigationShell,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            elevation: 3,
            destinations: destinations,
          ),
        );
      },
    );
  }
}
