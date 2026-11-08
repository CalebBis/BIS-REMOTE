import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/discovered_tv.dart';
import 'android_tv_pairing_service.dart';
import 'tv_discovery_service.dart';

/// Instance partagée du stockage sécurisé pour la persistance locale.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Fournisseur pour l'instance du service de découverte réseau.
final tvDiscoveryServiceProvider = Provider<TvDiscoveryService>((ref) {
  return TvDiscoveryService();
});

/// Fournisseur pour le service d'appairage Android TV (instance unique).
final androidTvPairingServiceProvider = Provider<AndroidTvPairingService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return AndroidTvPairingService(secureStorage: storage);
});

/// Gestionnaire d'état pour le téléviseur actuellement sélectionné avec mémorisation.
class SelectedTvNotifier extends Notifier<DiscoveredTv?> {
  static const String _storageKey = 'last_selected_tv';

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  @override
  DiscoveredTv? build() => null;

  /// Sélectionne une TV et l'enregistre immédiatement dans le stockage sécurisé.
  Future<void> selectTv(DiscoveredTv tv) async {
    state = tv;
    try {
      final jsonStr = jsonEncode(tv.toJson());
      await _storage.write(key: _storageKey, value: jsonStr);
      debugPrint('[AutoConnect] TV sélectionnée et mémorisée : ${tv.name} (${tv.ip})');
    } catch (e) {
      debugPrint('[AutoConnect] Erreur sauvegarde TV mémorisée : $e');
    }
  }

  /// Charge la dernière TV mémorisée depuis le stockage sécurisé.
  Future<DiscoveredTv?> loadSavedTv() async {
    try {
      final jsonStr = await _storage.read(key: _storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final tv = DiscoveredTv.fromJson(map);
        state = tv;
        debugPrint('[AutoConnect] TV mémorisée chargée avec succès : ${tv.name} (${tv.ip})');
        return tv;
      } else {
        debugPrint('[AutoConnect] Aucune TV mémorisée.');
      }
    } catch (e) {
      debugPrint('[AutoConnect] Erreur chargement TV mémorisée : $e');
    }
    return null;
  }

  /// Met à jour l'adresse IP de la TV sélectionnée (ex: suite à un scan de secours).
  Future<void> updateTvIp(String newIp) async {
    if (state == null) return;
    final oldIp = state!.ip;
    final updatedTv = state!.copyWith(ip: newIp);
    state = updatedTv;

    try {
      final jsonStr = jsonEncode(updatedTv.toJson());
      await _storage.write(key: _storageKey, value: jsonStr);
      debugPrint('[AutoConnect] Nouvelle IP mémorisée : $newIp pour ${updatedTv.name}');

      // Si la TV est une Android TV, transférer l'état d'appairage
      if (updatedTv.brand == TvBrand.androidTv) {
        final pairing = ref.read(androidTvPairingServiceProvider);
        await pairing.transferPairing(oldIp, newIp);
      }
    } catch (e) {
      debugPrint('[AutoConnect] Erreur mise à jour IP : $e');
    }
  }

  /// Efface la TV sélectionnée et sa mémorisation locale.
  Future<void> clearSelection() async {
    state = null;
    try {
      await _storage.delete(key: _storageKey);
      debugPrint('[AutoConnect] TV mémorisée effacée.');
    } catch (e) {
      debugPrint('[AutoConnect] Erreur suppression TV mémorisée : $e');
    }
  }
}

/// Fournisseur Riverpod pour le téléviseur sélectionné.
final selectedTvProvider = NotifierProvider<SelectedTvNotifier, DiscoveredTv?>(
  SelectedTvNotifier.new,
);

/// Gestionnaire d'auto-reconnexion et de détection de changement d'IP.
class AutoConnectNotifier extends Notifier<void> {
  bool _isRescueScanning = false;
  bool _rescueScanDone = false;
  StreamSubscription<DiscoveredTv>? _scanSub;

  @override
  void build() {
    ref.onDispose(() {
      _scanSub?.cancel();
    });
  }

  /// Réinitialise l'indicateur de scan de secours (appelé lors d'une connexion réussie).
  void resetFailureFlags() {
    _rescueScanDone = false;
  }

  /// Déclenché lorsqu'un échec de reconnexion survient.
  /// Si au moins 3 échecs consécutifs sont constatés, lance un scan silencieux de 8s.
  Future<void> handleReconnectAttempt(int attempts) async {
    debugPrint('[AutoConnect] Tentative #$attempts échouée.');
    if (attempts >= 3 && !_isRescueScanning && !_rescueScanDone) {
      await performRescueScan();
    }
  }

  /// Lance un scan silencieux de 8 secondes pour détecter si l'IP de la TV a changé.
  Future<void> performRescueScan() async {
    final currentTv = ref.read(selectedTvProvider);
    if (currentTv == null) return;

    _isRescueScanning = true;
    _rescueScanDone = true;
    debugPrint('[AutoConnect] Scan de secours : 3 échecs consécutifs. Recherche silencieuse (8s)...');

    final discoveryService = ref.read(tvDiscoveryServiceProvider);
    _scanSub?.cancel();

    _scanSub = discoveryService.scanTvs(duration: const Duration(seconds: 8)).listen(
      (foundTv) async {
        if (!_isRescueScanning) return;

        // Détection de correspondance : même nom ou même marque si nom équivalent
        final sameName = foundTv.name.toLowerCase().trim() == currentTv.name.toLowerCase().trim();
        final sameBrand = foundTv.brand != TvBrand.unknown && foundTv.brand == currentTv.brand;

        if ((sameName || sameBrand) && foundTv.ip != currentTv.ip) {
          debugPrint('[AutoConnect] TV retrouvée sur le réseau avec une nouvelle IP : ${foundTv.ip} (ancienne : ${currentTv.ip})');
          _isRescueScanning = false;
          _scanSub?.cancel();
          await ref.read(selectedTvProvider.notifier).updateTvIp(foundTv.ip);
        }
      },
      onDone: () {
        _isRescueScanning = false;
        debugPrint('[AutoConnect] Fin du scan de secours silencieux.');
      },
    );

    // Timeout de sécurité au bout de 8 secondes
    await Future.delayed(const Duration(seconds: 8));
    if (_isRescueScanning) {
      _isRescueScanning = false;
      await _scanSub?.cancel();
      debugPrint('[AutoConnect] Fin du scan de secours : aucune nouvelle IP trouvée.');
    }
  }
}

/// Fournisseur Riverpod pour la gestion de l'auto-reconnexion.
final autoConnectNotifierProvider = NotifierProvider<AutoConnectNotifier, void>(
  AutoConnectNotifier.new,
);

/// Statut de liaison Android TV de la TV sélectionnée.
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

