import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../features/capture/data/datasources/ai_categorizer_datasource.dart';
import '../../features/capture/data/datasources/gemini_ai_categorizer_datasource.dart';
import '../../features/capture/data/datasources/notification_listener_datasource.dart';
import '../../features/capture/data/parsers/bank_parsers.dart';
import '../../features/capture/data/parsers/expense_parsing_pipeline.dart';
import '../../features/capture/data/services/share_intent_service.dart';
import '../../features/capture/presentation/cubit/capture_cubit.dart';
import '../../features/transactions/data/datasources/drift_transaction_local_datasource.dart';
import '../../features/transactions/data/datasources/transaction_local_datasource.dart';
import '../../features/transactions/data/datasources/transaction_remote_datasource.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../features/transactions/domain/usecases/usecases.dart';
import '../../features/transactions/presentation/bloc/transaction_bloc.dart';
import '../../features/transactions/presentation/cubit/dashboard_cubit.dart';
import '../database/app_database.dart';
import '../network/dio_client.dart';

final getIt = GetIt.instance;

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.system-failed-tech.com',
);

const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

Future<void> configureDependencies() async {
  getIt
    // ---------- Infraestructura ----------
    ..registerLazySingleton(AppDatabase.new)
    ..registerLazySingleton(() => const FlutterSecureStorage())
    ..registerLazySingleton(
      () => DioClient(baseUrl: _apiBaseUrl, storage: getIt()).dio,
    )

    // ---------- Datasources ----------
    ..registerLazySingleton<TransactionLocalDataSource>(
      () => DriftTransactionLocalDataSource(getIt()),
    )
    ..registerLazySingleton<TransactionRemoteDataSource>(
      () => TransactionRemoteDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<GeminiAiCategorizerDataSource>(
      () => GeminiAiCategorizerDataSource(
        dio: getIt(),
        storage: getIt(),
        defaultApiKey: _geminiApiKey.isNotEmpty ? _geminiApiKey : null,
      ),
    )
    ..registerLazySingleton<AiCategorizerDataSource>(
      getIt.call<GeminiAiCategorizerDataSource>,
    )
    ..registerLazySingleton<NotificationListenerDataSource>(
      // iOS no puede leer notificaciones ajenas: ahí va el noop y la
      // captura se resuelve en el servidor. Ver docs/adr/0003.
      () => Platform.isAndroid
          ? AndroidNotificationListener()
          : NoopNotificationListener(),
    )

    // ---------- Parsers ----------
    // El orden importa: se evalúan en secuencia y el genérico es el último
    // recurso. Un parser nuevo va SIEMPRE antes de GenericAmountParser.
    ..registerLazySingleton<List<BankParser>>(
      () => [
        YapeParser(),
        PlinParser(),
        BcpParser(),
        InterbankParser(),
        BbvaParser(),
        GenericAmountParser(),
      ],
    )
    ..registerLazySingleton(
      () => ExpenseParsingPipeline(
        parsers: getIt(),
        aiCategorizer: getIt(),
      ),
    )

    // ---------- Repositorios ----------
    // Singleton: el stream local debe ser compartido entre todos los consumidores.
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(local: getIt(), remote: getIt()),
    )

    // ---------- Casos de uso ----------
    // Sin estado, singleton perezoso.
    ..registerLazySingleton(() => WatchTransactions(getIt()))
    ..registerLazySingleton(() => WatchMonthlySummary(getIt()))
    ..registerLazySingleton(() => AddTransaction(getIt()))
    ..registerLazySingleton(() => ReviewTransaction(getIt()))
    ..registerLazySingleton(() => DeleteTransaction(getIt()))

    // ---------- Blocs y Cubits ----------
    // SIEMPRE factory. Un singleton sobrevive al widget que lo usa, se queda
    // con streams abiertos y termina emitiendo sobre un contexto muerto.
    ..registerFactory(
      () => TransactionBloc(
        watchTransactions: getIt(),
        deleteTransaction: getIt(),
      ),
    )
    ..registerFactory(() => DashboardCubit(watchMonthlySummary: getIt()))
    // CaptureCubit es Singleton porque gestiona la suscripción persistente
    // en segundo plano para interceptar notificaciones de bancos y Yape.
    ..registerLazySingleton(
      () => CaptureCubit(
        listener: getIt(),
        pipeline: getIt(),
        addTransaction: getIt(),
      ),
    )
    ..registerLazySingleton(
      () => ShareIntentService(
        aiCategorizer: getIt(),
        addTransaction: getIt(),
      ),
    );
}
