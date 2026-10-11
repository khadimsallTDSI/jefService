import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jefservice_mobile/core/jef_core.dart';
import 'package:jefservice_mobile/main.dart';

void main() {
  test('brand palette matches product requirements', () {
    expect(jefPrimary, const Color(0xFF079B8F));
    expect(jefOrange, const Color(0xFFFF8500));
    expect(jefPale, const Color(0xFFDFF7F4));
    expect(jefDark, const Color(0xFF046B64));
  });

  test('JHipster list decoding handles empty data', () {
    expect(jefList(null), isEmpty);
    expect(jefList([]), isEmpty);
    expect(jefId('28'), 28);
    expect(jefMoney(null), 'À convenir');
  });

  testWidgets('splash screen has a Jef Service identity', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JefSplash()));
    expect(find.text('jefservice'), findsOneWidget);
    expect(find.byIcon(Icons.handyman_rounded), findsOneWidget);
  });
}
