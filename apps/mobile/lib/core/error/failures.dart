import 'package:equatable/equatable.dart';

/// Errores del dominio. No conocen HTTP, SQL ni ninguna tecnología concreta.
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'No pudimos conectar con el servidor']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'No hay datos guardados en el equipo']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Revisa tu conexión a internet']);
}

class ParseFailure extends Failure {
  const ParseFailure(super.message, {this.rawText});

  /// Texto original de la notificación que no se pudo interpretar.
  final String? rawText;

  @override
  List<Object?> get props => [message, rawText];
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
