import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/remote_mode.dart';

/// Gestionnaire d'état pour le mode de contrôle actif (navigation, touchpad, numérique).
class RemoteModeNotifier extends Notifier<RemoteMode> {
  @override
  RemoteMode build() => RemoteMode.navigation;

  void setMode(RemoteMode mode) {
    state = mode;
  }
}

/// Fournisseur Riverpod pour le mode de contrôle de la télécommande.
final remoteModeProvider = NotifierProvider<RemoteModeNotifier, RemoteMode>(
  RemoteModeNotifier.new,
);

