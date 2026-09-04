import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/usecases/usecases.dart';
import '../../data/datasources/notification_listener_datasource.dart';
import '../../data/parsers/expense_parsing_pipeline.dart';
import '../../domain/entities/parsed_expense.dart';

part 'capture_state.dart';

class CaptureCubit extends Cubit<CaptureState> {
  CaptureCubit({
    required NotificationListenerDataSource listener,
    required ExpenseParsingPipeline pipeline,
    required AddTransaction addTransaction,
    LocalNotificationService? notificationService,
    Uuid? uuid,
  })  : _listener = listener,
        _pipeline = pipeline,
        _addTransaction = addTransaction,
        _notificationService = notificationService,
        _uuid = uuid ?? const Uuid(),
        super(const CaptureState());

  final NotificationListenerDataSource _listener;
  final ExpenseParsingPipeline _pipeline;
  final AddTransaction _addTransaction;
  final LocalNotificationService? _notificationService;
  final Uuid _uuid;

  StreamSubscription<void>? _subscription;

  Future<void> checkPermission() async {
    if (!_listener.isSupported) {
      emit(state.copyWith(permission: CapturePermission.unsupported));
      return;
    }
    final granted = await _listener.hasPermission();
    emit(
      state.copyWith(
        permission:
            granted ? CapturePermission.granted : CapturePermission.denied,
      ),
    );
    if (granted) startListening();
  }

  Future<void> requestPermission() async {
    final granted = await _listener.requestPermission();
    emit(
      state.copyWith(
        permission:
            granted ? CapturePermission.granted : CapturePermission.denied,
      ),
    );
    if (granted) startListening();
  }

  Future<void> checkHealth() async {
    if (!_listener.isSupported) {
      emit(state.copyWith(health: CaptureHealth.processingError));
      return;
    }

    final hasPerm = await _listener.hasPermission();
    if (!hasPerm) {
      emit(
        state.copyWith(
          permission: CapturePermission.denied,
          health: CaptureHealth.notificationPermissionMissing,
        ),
      );
      return;
    }

    final isConnected = await _listener.isListenerConnected();
    final isIgnoringBattery = await _listener.isIgnoringBatteryOptimizations();
    final diagnostics = await _listener.getDiagnostics();
    final isAggressive = diagnostics['isAggressiveOem'] as bool? ?? false;

    CaptureHealth health;
    if (!isConnected) {
      health = CaptureHealth.listenerDisconnected;
    } else if (!isIgnoringBattery) {
      health = CaptureHealth.batteryRestricted;
    } else if (isAggressive && diagnostics['autostartConfigured'] == false) {
      health = CaptureHealth.manufacturerConfigurationRequired;
    } else {
      health = CaptureHealth.ready;
    }

    emit(
      state.copyWith(
        health: health,
        permission: CapturePermission.granted,
        isListenerConnected: isConnected,
        isBatteryRestricted: !isIgnoringBattery,
        isAggressiveOem: isAggressive,
        diagnostics: diagnostics,
      ),
    );
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    final result = await _listener.requestIgnoreBatteryOptimizations();
    await checkHealth();
    return result;
  }

  Future<bool> openAutostartSettings() async {
    final result = await _listener.openAutostartSettings();
    await checkHealth();
    return result;
  }

  void startListening() {
    _subscription?.cancel();

    _subscription = _listener.stream
        // asyncMap y no map: el pipeline puede llamar al backend. Con
        // `asyncMap` procesamos de a una y no saturamos la red si llegan
        // varias notificaciones seguidas.
        .asyncMap(_handle)
        .listen(null, onError: _onError);
  }

  Future<void> _handle(RawNotification notification) async {
    final result = await _pipeline.process(
      notification,
      rules: state.rules,
    );

    await result.fold(
      onFailure: (failure) async {
        // Un texto no reconocido no es un error que valga interrumpir al
        // usuario. Lo contamos para poder mejorar los parsers después.
        emit(state.copyWith(unrecognizedCount: state.unrecognizedCount + 1));
      },
      onSuccess: (expense) async {
        final isIncome = expense.type == TransactionType.income;
        final defaultCatId = isIncome ? 'other_income' : 'other';
        final catId = expense.suggestedCategoryId ?? defaultCatId;
        final category = kDefaultCategories.firstWhere(
          (c) => c.id == catId,
          orElse: () => Category(
            id: defaultCatId,
            name: isIncome ? 'Otros ingresos' : 'Otros',
            emoji: isIncome ? '💵' : '💸',
          ),
        );

        final transaction = Transaction(
          id: _uuid.v4(),
          amount: expense.amount,
          currency: expense.currency,
          merchant: expense.merchant,
          occurredAt: expense.occurredAt,
          category: category,
          source: TransactionSource.bankNotification,
          scope: expense.scope,
          type: expense.type,
          confidence: expense.confidence,
          rawText: expense.rawText,
          reviewed: expense.confidence >= 0.7,
          parser: expense.bankId ?? 'generic',
          parserVersion: expense.parserVersion,
          notificationHash:
              notification.notificationHash ?? expense.notificationHash,
          rawNotificationId: notification.id?.toString() ??
              expense.rawNotificationId?.toString(),
        );

        final saved = await _addTransaction(transaction);
        saved.fold(
          onFailure: (f) => emit(state.copyWith(failure: f)),
          onSuccess: (tx) {
            unawaited(_notificationService?.showTransactionNotification(tx));
            emit(
              state.copyWith(
                lastCaptured: tx,
                capturedCount: state.capturedCount + 1,
                clearFailure: true,
              ),
            );
          },
        );
      },
    );
  }

  void simulateNotification(RawNotification notification) =>
      _handle(notification);

  void _onError(Object error) =>
      emit(state.copyWith(failure: ParseFailure(error.toString())));

  void loadRules(List<UserRule> rules) => emit(state.copyWith(rules: rules));

  void addRule(UserRule rule) {
    final updated = List<UserRule>.from(state.rules)..add(rule);
    emit(state.copyWith(rules: updated));
  }

  void removeRule(String ruleId) {
    final updated = state.rules.where((r) => r.id != ruleId).toList();
    emit(state.copyWith(rules: updated));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
