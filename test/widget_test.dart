import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bis_remote/main.dart';

void main() {
  testWidgets('Smoke test de l interface télécommande et changement de modes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BisRemoteApp());

    // 1. Vérifie la présence du bandeau d'état et du bouton Power
    expect(find.text('Aucune TV connectée'), findsOneWidget);
    expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);

    // 2. Par défaut en mode Navigation : le D-Pad avec OK est affiché
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('Navigation'), findsOneWidget);

    // 3. Bascule en mode Pavé tactile
    final touchpadSegment = find.byIcon(Icons.touch_app_rounded);
    expect(touchpadSegment, findsOneWidget);
    await tester.tap(touchpadSegment);
    await tester.pumpAndSettle();

    expect(find.text('Pavé tactile'), findsOneWidget);
    expect(find.text('Glissez pour déplacer le curseur'), findsOneWidget);

    // 4. Bascule en mode Chiffres
    final dialpadSegment = find.byIcon(Icons.dialpad_rounded);
    expect(dialpadSegment, findsOneWidget);
    await tester.tap(dialpadSegment);
    await tester.pumpAndSettle();

    expect(find.text('Chiffres'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    // Vérifie la présence du bouton Supprimer avec son icône et son label sémantique
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    expect(find.bySemanticsLabel('Supprimer'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    // 5. Vérifie la présence des boutons Muet et Texte
    expect(find.text('Muet'), findsOneWidget);
    expect(find.text('Texte'), findsOneWidget);

    // 6. Test d'ouverture du bottom sheet de saisie de texte
    final textButton = find.byIcon(Icons.keyboard_outlined);
    expect(textButton, findsOneWidget);
    await tester.tap(textButton);
    await tester.pumpAndSettle();

    expect(find.text('Saisir sur la TV'), findsOneWidget);
    expect(find.text('Envoyer'), findsOneWidget);

    // Fermeture du bottom sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 7. Test d'ouverture de l'écran de découverte via le bandeau
    await tester.tap(find.text('Aucune TV connectée'));
    await tester.pumpAndSettle();

    expect(find.text('Recherche de téléviseurs'), findsOneWidget);
    expect(find.text('Par IP'), findsOneWidget);

    // Test de l'ajout manuel par IP
    await tester.tap(find.text('Par IP'));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter par adresse IP'), findsOneWidget);

    // Saisie de l'adresse IP et validation
    final ipField = find.byType(TextField).first;
    await tester.enterText(ipField, '192.168.1.50');
    await tester.pump();

    await tester.tap(find.text('Sélectionner'));
    await tester.pumpAndSettle();

    // Retour sur l'écran principal : le bandeau affiche désormais la TV sélectionnée
    expect(find.text('Samsung TV (192.168.1.50)'), findsOneWidget);
  });
}
