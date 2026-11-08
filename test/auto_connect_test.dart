import 'package:bis_remote/models/discovered_tv.dart';
import 'package:bis_remote/services/android_tv_pairing_service.dart';
import 'package:bis_remote/services/tv_discovery_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DiscoveredTv - Sérialisation JSON pour mémorisation', () {
    test('toJson et fromJson préservent fidèlement toutes les propriétés', () {
      const tv = DiscoveredTv(
        name: 'Mediatek_MTXXXX',
        ip: '192.168.1.64',
        brand: TvBrand.androidTv,
        port: 6466,
        location: 'http://192.168.1.64:8008/ssdp/device-desc.xml',
        extraInfo: {'model': 'AndroidTV', 'manufacturer': 'Mediatek'},
      );

      final json = tv.toJson();
      expect(json['name'], equals('Mediatek_MTXXXX'));
      expect(json['ip'], equals('192.168.1.64'));
      expect(json['brand'], equals('androidTv'));
      expect(json['port'], equals(6466));

      final restored = DiscoveredTv.fromJson(json);
      expect(restored.name, equals(tv.name));
      expect(restored.ip, equals(tv.ip));
      expect(restored.brand, equals(tv.brand));
      expect(restored.port, equals(tv.port));
      expect(restored.location, equals(tv.location));
      expect(restored.extraInfo?['model'], equals('AndroidTV'));
    });

    test('fromJson gère les valeurs par défaut et champs optionnels absents', () {
      final json = {
        'name': 'Samsung Salon',
        'ip': '192.168.1.20',
        'brand': 'samsung',
      };

      final tv = DiscoveredTv.fromJson(json);
      expect(tv.name, equals('Samsung Salon'));
      expect(tv.ip, equals('192.168.1.20'));
      expect(tv.brand, equals(TvBrand.samsung));
      expect(tv.port, isNull);
      expect(tv.location, isNull);
      expect(tv.extraInfo, isNull);
    });

    test('fromJson gère une marque inconnue sans planter', () {
      final json = {
        'name': 'Custom TV',
        'ip': '192.168.1.99',
        'brand': 'une_marque_inexistante',
      };

      final tv = DiscoveredTv.fromJson(json);
      expect(tv.brand, equals(TvBrand.unknown));
    });
  });

  group('SelectedTvNotifier & Persistance FlutterSecureStorage', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('selectTv enregistre la TV et loadSavedTv la restaure', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const tv = DiscoveredTv(
        name: 'Android TV Salon',
        ip: '192.168.1.64',
        brand: TvBrand.androidTv,
      );

      // 1. Sélectionne et sauvegarde
      await container.read(selectedTvProvider.notifier).selectTv(tv);
      expect(container.read(selectedTvProvider), equals(tv));

      // 2. Nouveau container simulant un redémarrage de l'app
      final newContainer = ProviderContainer();
      addTearDown(newContainer.dispose);

      expect(newContainer.read(selectedTvProvider), isNull);
      final loaded = await newContainer.read(selectedTvProvider.notifier).loadSavedTv();

      expect(loaded, isNotNull);
      expect(loaded?.name, equals('Android TV Salon'));
      expect(loaded?.ip, equals('192.168.1.64'));
      expect(loaded?.brand, equals(TvBrand.androidTv));
      expect(newContainer.read(selectedTvProvider)?.ip, equals('192.168.1.64'));
    });

    test('clearSelection efface la TV de l\'état et du stockage', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const tv = DiscoveredTv(
        name: 'TV Chambre',
        ip: '192.168.1.50',
        brand: TvBrand.lg,
      );

      await container.read(selectedTvProvider.notifier).selectTv(tv);
      expect(container.read(selectedTvProvider), isNotNull);

      await container.read(selectedTvProvider.notifier).clearSelection();
      expect(container.read(selectedTvProvider), isNull);

      final newContainer = ProviderContainer();
      addTearDown(newContainer.dispose);
      final loaded = await newContainer.read(selectedTvProvider.notifier).loadSavedTv();
      expect(loaded, isNull);
    });

    test('updateTvIp met à jour l\'adresse IP dans l\'état et le stockage', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const tv = DiscoveredTv(
        name: 'Android TV Salon',
        ip: '192.168.1.64',
        brand: TvBrand.androidTv,
      );

      await container.read(selectedTvProvider.notifier).selectTv(tv);
      await container.read(selectedTvProvider.notifier).updateTvIp('192.168.1.80');

      expect(container.read(selectedTvProvider)?.ip, equals('192.168.1.80'));
      expect(container.read(selectedTvProvider)?.name, equals('Android TV Salon'));

      final newContainer = ProviderContainer();
      addTearDown(newContainer.dispose);
      final loaded = await newContainer.read(selectedTvProvider.notifier).loadSavedTv();
      expect(loaded?.ip, equals('192.168.1.80'));
    });
  });

  group('AndroidTvPairingService - Oubli et transfert d\'appairage', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('unpairTv supprime le flag d\'appairage et les identifiants', () async {
      const storage = FlutterSecureStorage();
      final pairingService = AndroidTvPairingService(secureStorage: storage);

      await pairingService.setTvPaired('192.168.1.64', true);
      expect(await pairingService.isTvPaired('192.168.1.64'), isTrue);

      await pairingService.unpairTv('192.168.1.64', clearCertificates: true);
      expect(await pairingService.isTvPaired('192.168.1.64'), isFalse);
    });

    test('transferPairing transfère l\'état d\'appairage vers la nouvelle IP', () async {
      const storage = FlutterSecureStorage();
      final pairingService = AndroidTvPairingService(secureStorage: storage);

      await pairingService.setTvPaired('192.168.1.64', true);
      expect(await pairingService.isTvPaired('192.168.1.64'), isTrue);
      expect(await pairingService.isTvPaired('192.168.1.80'), isFalse);

      await pairingService.transferPairing('192.168.1.64', '192.168.1.80');
      expect(await pairingService.isTvPaired('192.168.1.64'), isFalse);
      expect(await pairingService.isTvPaired('192.168.1.80'), isTrue);
    });
  });
}

