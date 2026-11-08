import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discovered_tv.dart';
import 'tv_discovery_service.dart';

/// Fournisseur pour l'instance du service de découverte réseau.
final tvDiscoveryServiceProvider = Provider<TvDiscoveryService>((ref) {
  return TvDiscoveryService();
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

/// Libellé dynamique affiché dans le bandeau supérieur de l'écran principal.
final tvConnectionStatusProvider = Provider<String>((ref) {
  final selectedTv = ref.watch(selectedTvProvider);
  if (selectedTv != null) {
    return '${selectedTv.name} (${selectedTv.ip})';
  }
  return 'Aucune TV connectée';
});
