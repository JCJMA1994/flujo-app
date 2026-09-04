import 'package:flujo/features/transactions/presentation/cubit/privacy_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivacyCubit', () {
    late PrivacyCubit cubit;

    setUp(() {
      cubit = PrivacyCubit();
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state has isObscured as false', () {
      expect(cubit.state.isObscured, false);
    });

    test('toggle toggles isObscured state', () {
      cubit.toggle();
      expect(cubit.state.isObscured, true);

      cubit.toggle();
      expect(cubit.state.isObscured, false);
    });

    test('setObscured directly updates state', () {
      cubit.setObscured(obscured: true);
      expect(cubit.state.isObscured, true);

      cubit.setObscured(obscured: false);
      expect(cubit.state.isObscured, false);
    });
  });
}
