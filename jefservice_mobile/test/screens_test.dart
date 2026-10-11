import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jefservice_mobile/core/jef_core.dart';
import 'package:jefservice_mobile/main.dart';

void main() {
  testWidgets('L’écran OTP client s’ouvre sans profil ni API', (tester) async {
    final session = JefSession();
    await tester.pumpWidget(MaterialApp(home: AuthPage(session: session)));
    expect(find.text('Bienvenue !'), findsOneWidget);
    expect(find.text('Recevoir mon code SMS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('L’écran demandes gère un identifiant client absent', (tester) async {
    final session = JefSession();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MissionsPage(session: session)),
    ));
    await tester.pump();
    expect(find.text('Mes demandes'), findsOneWidget);
    expect(find.textContaining('profil métier'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('L’écran documents gère un identifiant technicien absent', (tester) async {
    final session = JefSession();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DocumentsPage(session: session)),
    ));
    await tester.pump();
    expect(find.text('Mes documents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le dashboard professionnel gère un profil absent', (tester) async {
    final session = JefSession();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProDashboard(session: session)),
    ));
    expect(find.text('Espace professionnel'), findsOneWidget);
    expect(find.textContaining('Profil technicien introuvable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Un service sans ID affiche une erreur contrôlée', (tester) async {
    final session = JefSession();
    await tester.pumpWidget(MaterialApp(
      home: TechniciansPage(session: session, service: const {'nom':'Test'}),
    ));
    await tester.pump();
    expect(find.textContaining('Service introuvable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
