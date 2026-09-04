import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/capture/data/datasources/ai_categorizer_datasource.dart';
import '../../features/capture/data/datasources/notification_listener_datasource.dart';
import '../../features/capture/data/parsers/bank_parsers.dart';
import '../../features/capture/data/parsers/expense_parsing_pipeline.dart';
import '../../features/capture/data/services/share_intent_service.dart';
import '../../features/capture/presentation/cubit/capture_cubit.dart';
import '../../features/chat/data/datasources/chat_remote_datasource.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/ask_financial_assistant.dart';
import '../../features/chat/presentation/cubit/chat_cubit.dart';
import '../../features/insights/domain/usecases/insights_usecases.dart';
import '../../features/insights/presentation/cubit/insights_cubit.dart';
import '../../features/transactions/data/datasources/drift_transaction_local_datasource.dart';
import '../../features/transactions/data/datasources/transaction_local_datasource.dart';
import '../../features/transactions/data/datasources/transaction_remote_datasource.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/data/services/transaction_export_service.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../features/transactions/domain/usecases/usecases.dart';
import '../../features/transactions/presentation/bloc/transaction_bloc.dart';
import '../../features/transactions/presentation/cubit/dashboard_cubit.dart';
import '../../features/transactions/presentation/cubit/privacy_cubit.dart';
import '../database/app_database.dart';
import '../network/dio_client.dart';
import '../security/biometric_service.dart';
import '../services/local_notification_service.dart';

final getIt = GetIt.instance;

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.system-failed-tech.com',
);

Future<void> configureDependencies() async {
  getIt
    // ---------- Infraestructura ----------
    ..registerLazySingleton(AppDatabase.new)
    ..registerLazySingleton(() => const FlutterSecureStorage())
    ..registerLazySingleton(
      () => BiometricService(storage: getIt()),
    )
    ..registerLazySingleton(TransactionExportService.new)
    ..registerLazySingleton(LocalNotificationService.new)
    ..registerLazySingleton(
      () => DioClient(
        baseUrl: _apiBaseUrl,
        storage: getIt(),
        onUnauthorized: () {
          if (getIt.isRegistered<AuthCubit>()) {
            getIt<AuthCubit>().sessionExpired();
          }
        },
      ).dio,
    )

    // ---------- Datasources ----------
    ..registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(storage: getIt()),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(dio: getIt()),
    )
    ..registerLazySingleton<TransactionLocalDataSource>(
      () => DriftTransactionLocalDataSource(getIt()),
    )
    ..registerLazySingleton<TransactionRemoteDataSource>(
      () => TransactionRemoteDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<AiCategorizerDataSource>(
      () => RemoteAiCategorizerDataSource(getIt()),
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
        PayPalParser(),
        GenericAmountParser(),
      ],
    )
    ..registerLazySingleton(
      () => ExpenseParsingPipeline(
        parsers: getIt(),
        aiCategorizer: getIt(),
      ),
    )

    // ---------- Datasources ----------
    ..registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSourceImpl(dio: getIt()),
    )

    // ---------- Repositorios ----------
    // Singleton: el stream local debe ser compartido entre todos los consumidores.
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: getIt(),
        localDataSource: getIt(),
      ),
    )
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(remoteDataSource: getIt()),
    )
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(local: getIt(), remote: getIt()),
    )

    // ---------- Casos de uso ----------
    // Sin estado, singleton perezoso.
    ..registerLazySingleton(() => LoginUseCase(getIt()))
    ..registerLazySingleton(() => RegisterUseCase(getIt()))
    ..registerLazySingleton(() => LogoutUseCase(getIt()))
    ..registerLazySingleton(() => GetAuthSessionUseCase(getIt()))
    ..registerLazySingleton(() => WatchTransactions(getIt()))
    ..registerLazySingleton(() => WatchMonthlySummary(getIt()))
    ..registerLazySingleton(() => AddTransaction(getIt()))
    ..registerLazySingleton(() => ReviewTransaction(getIt()))
    ..registerLazySingleton(() => DeleteTransaction(getIt()))
    ..registerLazySingleton(() => SyncPendingTransactions(getIt()))
    ..registerLazySingleton(DetectRecurringExpenses.new)
    ..registerLazySingleton(CalculateMonthlyProjection.new)
    ..registerLazySingleton(() => AskFinancialAssistant(getIt()))

    // ---------- Blocs y Cubits ----------
    ..registerLazySingleton(
      () => AuthCubit(
        loginUseCase: getIt(),
        registerUseCase: getIt(),
        logoutUseCase: getIt(),
        getAuthSessionUseCase: getIt(),
      ),
    )
    // SIEMPRE factory. Un singleton sobrevive al widget que lo usa, se queda
    // con streams abiertos y termina emitiendo sobre un contexto muerto.
    ..registerFactory(
      () => TransactionBloc(
        watchTransactions: getIt(),
        deleteTransaction: getIt(),
        syncPendingTransactions: getIt(),
      ),
    )
    ..registerFactory(() => DashboardCubit(watchMonthlySummary: getIt()))
    ..registerFactory(
      () => InsightsCubit(
        repository: getIt(),
        detectRecurringExpenses: getIt(),
        calculateMonthlyProjection: getIt(),
      ),
    )
    ..registerFactory(() => ChatCubit(askFinancialAssistant: getIt()))
    ..registerLazySingleton(PrivacyCubit.new)
    // CaptureCubit es Singleton porque gestiona la suscripción persistente
    // en segundo plano para interceptar notificaciones de bancos y Yape.
    ..registerLazySingleton(
      () => CaptureCubit(
        listener: getIt(),
        pipeline: getIt(),
        addTransaction: getIt(),
        notificationService: getIt(),
      ),
    )
    ..registerLazySingleton(
      () => ShareIntentService(
        aiCategorizer: getIt(),
        addTransaction: getIt(),
        notificationService: getIt(),
      ),
    );
}
