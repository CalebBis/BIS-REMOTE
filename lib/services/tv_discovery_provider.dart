import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discovered_tv.dart';
import 'android_tv_pairing_service.dart';
import 'tv_discovery_service.dart';

/// Fournisseur pour l'instance du service de découverte réseau.
final tvDiscoveryServiceProvider = Provider<TvDiscoveryService>((ref) {
  return TvDiscoveryService();
});

/// Fournisseur pour le service d'appairage Android TV (instance unique).
final androidTvPairingServiceProvider = Provider<AndroidTvPairingService>((ref) {
  return AndroidTvPairingService();
});

/// Gestionnaire d'état pour le téléviseur actuellement sélectionné.
class SelectedTvNotifier extends Notifier<DiscoveredTv?> {
  @override
  DiscoveredTv? build() => null;

  void selectTv(DiscoveredTv tv) {
    state = tv;
  }

  void clearSelection() {
    state = null;
  }
}

/// Fournisseur Riverpod pour le téléviseur sélectionné.
final selectedTvProvider = NotifierProvider<SelectedTvNotifier, DiscoveredTv?>(
  SelectedTvNotifier.new,
);

/// Statut de liaison Android TV de la TV sélectionnée.
/// Null si la TV sélectionnée n'est pas une Android TV, ou si aucune TV n'est sélectionnée.
class AndroidTvConnectionStatusNotifier extends Notifier<AndroidTvConnectionState?> {
  @override
  AndroidTvConnectionState? build() => null;

  void set(AndroidTvConnectionState? s) => state = s;
}

final androidTvConnectionStateProvider =
    NotifierProvider<AndroidTvConnectionStatusNotifier, AndroidTvConnectionState?>(
  AndroidTvConnectionStatusNotifier.new,
);

/// Libellé dynamique affiché dans le bandeau supérieur de l'écran principal.
final tvConnectionStatusProvider = Provider<String>((ref) {
  final selectedTv = ref.watch(selectedTvProvider);
  if (selectedTv == null) return 'Aucune TV connectée';

  if (selectedTv.brand == TvBrand.androidTv) {
    final atv = ref.watch(androidTvConnectionStateProvider);
    final label = switch (atv) {
      AndroidTvConnectionState.connecting => 'connexion…',
      AndroidTvConnectionState.connected => 'connectée',
      AndroidTvConnectionState.offline => 'hors ligne',
      AndroidTvConnectionState.unpaired => 'non appairée',
      AndroidTvConnectionState.paired => 'appairée',
      null => 'connexion…',
    };
    return '${selectedTv.name} · $label';
  }

  return '${selectedTv.name} (${selectedTv.ip})';
});

