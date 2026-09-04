import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_router.dart';

import '../transaction_form_sheet.dart';

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accesos rápidos',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              dense: true,
              leading: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE0F2FE),
                child: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Color(0xFF0284C7),
                ),
              ),
              title: const Text('Registrar movimiento'),
              subtitle: const Text('Gasto o ingreso manual'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                HapticFeedback.lightImpact();
                TransactionFormSheet.show(context);
              },
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFDCFCE7),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: Color(0xFF16A34A),
                ),
              ),
              title: const Text('Captura automática'),
              subtitle: const Text('Yape, Plin y bancos'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                HapticFeedback.lightImpact();
                context.go(AppRoutes.captureOnboarding);
              },
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFF3E8FF),
                child: Icon(
                  Icons.auto_fix_high_rounded,
                  size: 18,
                  color: Color(0xFF9333EA),
                ),
              ),
              title: const Text('Reglas inteligentes'),
              subtitle: const Text('Categorización automática'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                HapticFeedback.lightImpact();
                context.go(AppRoutes.userRules);
              },
            ),
          ],
        ),
      ),
    );
  }
}
