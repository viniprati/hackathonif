import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/ui/screens/login_screen.dart';

void main() {
  testWidgets('requires CPF and password before entering', (tester) async {
    var entered = false;
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(onSignIn: () => entered = true)),
    );

    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(entered, isFalse);
    expect(find.text('Informe 11 dígitos.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '12345678901');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(entered, isTrue);
  });
}
