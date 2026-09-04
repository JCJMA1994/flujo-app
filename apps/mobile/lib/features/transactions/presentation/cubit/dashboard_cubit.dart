import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/usecases.dart';

part 'dashboard_state.dart';

/// Cubit y no Bloc: el dashboard solo reacciona a "muéstrame este mes".
/// No hay un vocabulario de eventos que valga la pena modelar.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required WatchMonthlySummary watchMonthlySummary})
      : _watchMonthlySummary = watchMonthlySummary,
        super(const DashboardState());

  final WatchMonthlySummary _watchMonthlySummary;

  final _monthSubject = BehaviorSubject<DateTime>();
  StreamSubscription<MonthlySummary>? _subscription;

  void start({DateTime? month}) {
    final now = DateTime.now();
    _monthSubject.add(month ?? DateTime(now.year, now.month));

    emit(state.copyWith(status: DashboardStatus.loading));

    _subscription?.cancel();
    _subscription = _monthSubject
        .distinct()
        // El usuario puede barrer meses rápido; nos quedamos con el último.
        .debounceTime(const Duration(milliseconds: 150))
        .switchMap(_watchMonthlySummary.call)
        .listen(
          (summary) => emit(
            state.copyWith(
              status: DashboardStatus.success,
              summary: summary,
              clearFailure: true,
            ),
          ),
          onError: (Object error) => emit(
            state.copyWith(
              status: DashboardStatus.failure,
              failure: CacheFailure(error.toString()),
            ),
          ),
        );
  }

  void selectMonth(DateTime month) =>
      _monthSubject.add(DateTime(month.year, month.month));

  void previousMonth() {
    final current = _monthSubject.valueOrNull ?? DateTime.now();
    selectMonth(DateTime(current.year, current.month - 1));
  }

  void nextMonth() {
    final current = _monthSubject.valueOrNull ?? DateTime.now();
    selectMonth(DateTime(current.year, current.month + 1));
  }

  void goToCurrentMonth() {
    final now = DateTime.now();
    selectMonth(DateTime(now.year, now.month));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _monthSubject.close();
    return super.close();
  }
}
