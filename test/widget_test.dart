import 'package:flutter_test/flutter_test.dart';

import 'package:e_comerce_appliction/screens/login_screen.dart';
import 'package:e_comerce_appliction/provider/authprovider.dart';
import 'package:e_comerce_appliction/provider/themeprovider.dart';
import 'package:e_comerce_appliction/utils/error_handling.dart';
import 'package:e_comerce_appliction/widgets/error_state.dart';
import 'package:e_comerce_appliction/utils/date_format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  Widget appWithProviders({Widget? home}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AthenDiction()),
      ],
      child: MaterialApp(home: home ?? const LoginScreen()),
    );
  }

  testWidgets('login screen fits a narrow viewport and scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(appWithProviders(home: const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Log in for the best experience'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error state invokes retry action', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorState(
          message: 'No internet connection.',
          onRetry: () => retryCount++,
        ),
      ),
    );

    expect(find.text('No internet connection.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retryCount, 1);
  });

  test('shared error formatter returns user-facing messages', () {
    expect(
      providerErrorMessage(Exception('SocketException: failed host lookup')),
      'No internet connection. Please check your network and try again.',
    );
    expect(
      providerErrorMessage(Exception('OUT_OF_STOCK: item')),
      'This product is out of stock. Please review your cart.',
    );
  });

  test(
    'order ids resolve consistently across buyer, seller, and return cards',
    () {
      expect(resolveOrderId({'id': 'ord_abc_123'}), 'ord_abc_123');
      expect(
        resolveOrderId({}, item: {'order_id': 'ord_item_456'}),
        'ord_item_456',
      );
      expect(
        resolveOrderId({}, request: {'order_id': 'ord_return_789'}),
        'ord_return_789',
      );
      expect(
        resolveOrderId({}, fallback: 'ord_fallback_000'),
        'ord_fallback_000',
      );
    },
  );
}
