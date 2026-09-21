import 'package:flutter_test/flutter_test.dart';

import 'package:e_comerce_appliction/main.dart';
import 'package:e_comerce_appliction/screens/flashe_screen.dart';
import 'package:e_comerce_appliction/screens/login_screen.dart';

void main() {
  testWidgets('app starts on splash screen and navigates to login', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(FlasheScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
