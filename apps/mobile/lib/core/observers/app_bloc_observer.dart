import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

/// Punto único para observar el ciclo de vida de todos los blocs.
/// En producción, reemplaza los `log` por tu servicio de crash reporting.
class AppBlocObserver extends BlocObserver {
  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      developer.log(
        '${transition.event.runtimeType} → ${transition.nextState.runtimeType}',
        name: bloc.runtimeType.toString(),
      );
    }
  }

  @override
  void onError(
    BlocBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      'Error no capturado',
      name: bloc.runtimeType.toString(),
      error: error,
      stackTrace: stackTrace,
    );
    // Sentry.captureException(error, stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    if (kDebugMode) {
      developer.log('cerrado', name: bloc.runtimeType.toString());
    }
  }
}
