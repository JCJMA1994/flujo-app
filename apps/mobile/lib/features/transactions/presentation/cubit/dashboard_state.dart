part of 'dashboard_cubit.dart';

enum DashboardStatus { initial, loading, success, failure }

final class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.summary,
    this.failure,
  });

  final DashboardStatus status;
  final MonthlySummary? summary;
  final Failure? failure;

  DashboardState copyWith({
    DashboardStatus? status,
    MonthlySummary? summary,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return DashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, summary, failure];
}
