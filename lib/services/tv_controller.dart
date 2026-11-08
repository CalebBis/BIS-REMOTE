import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discovered_tv.dart';
import '../models/remote_key.dart';
import '../models/tv_capability.dart';
import 'android_tv_controller.dart';
import 'android_tv_pairing_service.dart';
import 'tv_discovery_provider.dart';

export 'android_tv_controller.dart';
export 'remote_mode_provider.dart';
export 'tv_discovery_provider.dart';

/// Contrat d'interface abstrait pour le pilotage d'un téléviseur.
abstract class TvController {
  /// Ensemble des fonctionnalités matérielles/logicielles supportées.
  Set<TvCapability> get capabilities => const {};

  /// Envoie un signal de commande correspondant à la touche [key].
  Future<void> sendCommand(RemoteKey key);

  /// Déplace le curseur relatif de [dx] et [dy] points.
  Future<void> sendPointerMove(double dx, double dy) async {}

  /// Déclenche un clic avec le pointeur actif.
  Future<void> sendPointerClick() async {}

  /// Envoie un défilement vertical de [dy] points (par exemple à deux doigts).
  Future<void> sendScroll(double dy) async {}

  /// Transmet une séquence ou un caractère de texte [text] au téléviseur.
  Future<void> sendText(String text) async {}

  /// Transmet une commande d'effacement arrière (Backspace).
  Future<void> sendBackspace() async {}

  /// Transmet une commande de validation (Entrée / Submit).
  Future<void> sendEnter() async {}
}

/// Implémentation factice (Mock) utilisée pour les tests et la maquette UI.
/// Déclare la prise en charge du pointeur et de la saisie de texte,
/// et affiche chaque action reçue dans la console de débogage.
class MockTvController implements TvController {
  @override
  Set<TvCapability> get capabilities => {
        TvCapability.pointer,
        TvCapability.textInput,
      };

  @override
  Future<void> sendCommand(RemoteKey key) async {
    debugPrint('[TvController - Mock] Touche pressée : ${key.name} (${key.label})');
  }

  @override
  Future<void> sendPointerMove(double dx, double dy) async {
    debugPrint(
      '[TvController - Mock] Déplacement pointeur : dx=${dx.toStringAsFixed(1)}, dy=${dy.toStringAsFixed(1)}',
    );
  }

  @override
  Future<void> sendPointerClick() async {
    debugPrint('[TvController - Mock] Clic pointeur');
  }

  @override
  Future<void> sendScroll(double dy) async {
    debugPrint('[TvController - Mock] Défilement : dy=${dy.toStringAsFixed(1)}');
  }

  @override
  Future<void> sendText(String text) async {
    debugPrint('[TvController - Mock] Texte saisi : "$text"');
  }

  @override
  Future<void> sendBackspace() async {
    debugPrint('[TvController - Mock] Touche Retour arrière (Backspace)');
  }

  @override
  Future<void> sendEnter() async {
    debugPrint('[TvController - Mock] Touche Entrée (Enter)');
  }
}

/// Fournisseur Riverpod pour l'instance d'AndroidTvController (géré par hôte avec autoDispose).
final androidTvControllerProvider =
    Provider.autoDispose.family<AndroidTvController, String>((ref, host) {
  final pairingService = ref.watch(androidTvPairingServiceProvider);
  final controller = AndroidTvController(
    host: host,
    pairingService: pairingService,
    onStateChanged: (state) {
      ref.read(androidTvConnectionStateProvider.notifier).set(state);
      if (state == AndroidTvConnectionState.connected) {
        ref.read(autoConnectNotifierProvider.notifier).resetFailureFlags();
      }
    },
    onReconnectFailed: (attempts) {
      ref.read(autoConnectNotifierProvider.notifier).handleReconnectAttempt(attempts);
    },
  );

  ref.onDispose(() {
    controller.dispose();
  });

  controller.connect();
  return controller;
});

/// Fournisseur Riverpod pour l'instance active de [TvController].
/// Fournit [AndroidTvController] si une Android TV appairée est sélectionnée, sinon [MockTvController].
final tvControllerProvider = Provider<TvController>((ref) {
  final selectedTv = ref.watch(selectedTvProvider);
  if (selectedTv != null && selectedTv.brand == TvBrand.androidTv) {
    final connState = ref.watch(androidTvConnectionStateProvider);
    if (connState != AndroidTvConnectionState.unpaired) {
      return ref.watch(androidTvControllerProvider(selectedTv.ip));
    }
  }
  return MockTvController();
});
