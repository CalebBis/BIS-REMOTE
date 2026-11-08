import 'package:bis_remote/models/discovered_tv.dart';
import 'package:bis_remote/services/wake_on_lan_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WakeOnLanService - Validation et normalisation des adresses MAC', () {
    test('isValidMac valide les formats standards avec : ou -', () {
      expect(WakeOnLanService.isValidMac('00:11:22:33:44:55'), isTrue);
      expect(WakeOnLanService.isValidMac('AA:BB:CC:DD:EE:FF'), isTrue);
      expect(WakeOnLanService.isValidMac('aa-bb-cc-dd-ee-ff'), isTrue);
      expect(WakeOnLanService.isValidMac('A1:b2:C3:d4:E5:f6'), isTrue);
      expect(WakeOnLanService.isValidMac('  00:11:22:33:44:55  '), isTrue);
    });

    test('isValidMac rejette les formats invalides', () {
      expect(WakeOnLanService.isValidMac(''), isFalse);
      expect(WakeOnLanService.isValidMac('00:11:22:33:44'), isFalse); // trop court
      expect(WakeOnLanService.isValidMac('00:11:22:33:44:55:66'), isFalse); // trop long
      expect(WakeOnLanService.isValidMac('00:11:22:33:44:ZZ'), isFalse); // non-hex
      expect(WakeOnLanService.isValidMac('00.11.22.33.44.55'), isFalse); // séparateur point
      expect(WakeOnLanService.isValidMac('001122334455'), isFalse); // pas de séparateur
    });

    test('normalizeMac formate en majuscules avec séparateur :', () {
      expect(
        WakeOnLanService.normalizeMac('aa:bb:cc:dd:ee:ff'),
        equals('AA:BB:CC:DD:EE:FF'),
      );
      expect(
        WakeOnLanService.normalizeMac('a1-b2-c3-d4-e5-f6'),
        equals('A1:B2:C3:D4:E5:F6'),
      );
      expect(WakeOnLanService.normalizeMac('invalide'), isNull);
    });

    test('maskMac masque partiellement l\'adresse pour les logs (ex : A1:B2:**:**:**:F6)', () {
      expect(
        WakeOnLanService.maskMac('A1:B2:C3:D4:E5:F6'),
        equals('A1:B2:**:**:**:F6'),
      );
      expect(
        WakeOnLanService.maskMac('a1-b2-c3-d4-e5-f6'),
        equals('A1:B2:**:**:**:F6'),
      );
      expect(
        WakeOnLanService.maskMac('invalide'),
        equals('**:**:**:**:**:**'),
      );
    });
  });

  group('WakeOnLanService - Construction du paquet magique', () {
    test('buildMagicPacket construit exactement 102 octets avec 6x 0xFF et 16x MAC', () {
      const mac = '00:11:22:33:44:55';
      final packet = WakeOnLanService.buildMagicPacket(mac);

      // Taille obligatoire : 6 + 16 * 6 = 102 octets
      expect(packet.length, equals(102));

      // Les 6 premiers octets doivent être 0xFF
      for (int i = 0; i < 6; i++) {
        expect(packet[i], equals(0xFF));
      }

      // Les 96 octets suivants doivent contenir 16 répétitions des 6 octets de l'adresse MAC
      final expectedMacBytes = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55];
      for (int rep = 0; rep < 16; rep++) {
        final offset = 6 + rep * 6;
        for (int byteIdx = 0; byteIdx < 6; byteIdx++) {
          expect(
            packet[offset + byteIdx],
            equals(expectedMacBytes[byteIdx]),
            reason: 'Octet $byteIdx de la répétition $rep incorrect',
          );
        }
      }
    });

    test('buildMagicPacket lance une ArgumentError si la MAC est invalide', () {
      expect(
        () => WakeOnLanService.buildMagicPacket('mac_invalide'),
        throwsArgumentError,
      );
    });
  });

  group('DiscoveredTv - Rétrocompatibilité macAddress', () {
    test('toJson et fromJson préservent macAddress', () {
      const tv = DiscoveredTv(
        name: 'Android TV Salon',
        ip: '192.168.1.64',
        brand: TvBrand.androidTv,
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final json = tv.toJson();
      expect(json['macAddress'], equals('AA:BB:CC:DD:EE:FF'));

      final restored = DiscoveredTv.fromJson(json);
      expect(restored.macAddress, equals('AA:BB:CC:DD:EE:FF'));
    });

    test('fromJson supporte les JSON existants sans macAddress (rétrocompatibilité)', () {
      final legacyJson = {
        'name': 'Ancienne TV',
        'ip': '192.168.1.64',
        'brand': 'androidTv',
      };

      final tv = DiscoveredTv.fromJson(legacyJson);
      expect(tv.name, equals('Ancienne TV'));
      expect(tv.ip, equals('192.168.1.64'));
      expect(tv.macAddress, isNull);
    });

    test('copyWith permet d\'ajouter ou mettre à jour macAddress', () {
      const tv = DiscoveredTv(
        name: 'TV',
        ip: '192.168.1.64',
        brand: TvBrand.androidTv,
      );
      expect(tv.macAddress, isNull);

      final withMac = tv.copyWith(macAddress: '11:22:33:44:55:66');
      expect(withMac.macAddress, equals('11:22:33:44:55:66'));
      expect(withMac.ip, equals('192.168.1.64'));
    });
  });
}

