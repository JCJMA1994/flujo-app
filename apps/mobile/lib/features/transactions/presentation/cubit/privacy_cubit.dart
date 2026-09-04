import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PrivacyState {
  const PrivacyState({this.isObscured = false});

  final bool isObscured;

  PrivacyState copyWith({bool? isObscured}) {
    return PrivacyState(isObscured: isObscured ?? this.isObscured);
  }
}

class PrivacyCubit extends Cubit<PrivacyState> {
  PrivacyCubit() : super(const PrivacyState());

  void toggle() {
    HapticFeedback.selectionClick();
    emit(state.copyWith(isObscured: !state.isObscured));
  }

  void setObscured({required bool obscured}) {
    emit(state.copyWith(isObscured: obscured));
  }
}
