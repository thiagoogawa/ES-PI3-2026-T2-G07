/// Thiago Ryuji Ogawa - RA:24024450
///
/// Arquivo de teste automatizado do aplicativo mobile.
/// Serve como ponto de verificacao para comportamento de widgets
/// ou para a configuracao basica do ambiente de testes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic widget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Smoke test'))),
    );

    expect(find.text('Smoke test'), findsOneWidget);
  });
}
