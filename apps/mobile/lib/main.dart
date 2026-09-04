import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/capture/data/services/share_intent_service.dart';
import 'features/capture/presentation/cubit/capture_cubit.dart';

void main() async {
  // Aseguramos la inicialización del motor de Flutter y las dependencias antes
  // de montar el árbol de widgets.
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await configureDependencies();

  // Inicia la escucha para recibir comprobantes compartidos desde Yape o bancos
  getIt<ShareIntentService>().init();

  // Si ya tiene permiso en Android, arrancamos la escucha en segundo plano
  // inmediatamente al iniciar la app.
  unawaited(getIt<CaptureCubit>().checkPermission());

  runApp(const FlujoApp());
}

class FlujoApp extends StatelessWidget {
  const FlujoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Proveemos CaptureCubit y AuthCubit a nivel de raíz para mantener
    // el estado de autenticación y captura sincronizado en toda la app.
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<CaptureCubit>()),
        BlocProvider.value(value: getIt<AuthCubit>()),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status &&
            curr.status == AuthStatus.unauthenticated &&
            curr.errorMessage != null,
        listener: (context, state) {
          appRouter.go(AppRoutes.login);
          ShareIntentService.scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: MaterialApp.router(
          scaffoldMessengerKey: ShareIntentService.scaffoldMessengerKey,
          title: 'Flujo: Gastos & Yape',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
