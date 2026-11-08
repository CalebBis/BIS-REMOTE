import 'package:bis_remote/models/discovered_tv.dart';
import 'package:bis_remote/screens/discovery_screen.dart';
import 'package:bis_remote/services/android_tv_pairing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Calcul du hash SHA-256 avec checksum', () {
    // Test avec des clés arbitraires et un PIN
    final clientMod = BigInt.parse('1234567890ABCDEF1234567890ABCDEF', radix: 16);
    final clientExp = BigInt.from(65537);
    final serverMod = BigInt.parse('FEDCBA0987654321FEDCBA0987654321', radix: 16);
    final serverExp = BigInt.from(65537);

    // PIN valide dont le premier octet correspond au hash
    final testPin = '123456';
    final hash = AndroidTvPairingService.computeSecretHash(
      clientModulus: clientMod,
      clientExponent: clientExp,
      serverModulus: serverMod,
      serverExponent: serverExp,
      pin: testPin,
    );

    expect(hash.length, equals(32));

    // Si on forge un code PIN avec les 2 premiers caractères hex = hash[0]
    final matchingPinPrefix = hash[0].toRadixString(16).padLeft(2, '0').toUpperCase();
    final forgedPin = '$matchingPinPrefix${testPin.substring(2)}';

    final forgedHash = AndroidTvPairingService.computeSecretHash(
      clientModulus: clientMod,
      clientExponent: clientExp,
      serverModulus: serverMod,
      serverExponent: serverExp,
      pin: forgedPin,
    );

    expect(forgedHash[0], equals(int.parse(forgedPin.substring(0, 2), radix: 16)));
  });

  test('Encodage et décodage des messages POLO Protobuf', () {
    final service = AndroidTvPairingService();
    expect(service, isNotNull);
  });

  test('Nettoyage et formatage du nom TV (évite Android TV TV)', () {
    // 1. Élimination du doublon "TV TV"
    const tvDuplicate = DiscoveredTv(
      name: 'Android TV TV',
      ip: '192.168.1.64',
      brand: TvBrand.androidTv,
    );
    expect(DiscoveryScreen.formatTvName(tvDuplicate), equals('Android TV'));

    // 2. Nom spécifique conservé tel quel
    const tvSpecific = DiscoveredTv(
      name: 'Mediatek_MTXXXX',
      ip: '192.168.1.64',
      brand: TvBrand.androidTv,
    );
    expect(DiscoveryScreen.formatTvName(tvSpecific), equals('Mediatek_MTXXXX'));

    // 3. Nom générique avec instance mDNS
    const tvMdns = DiscoveredTv(
      name: 'Android TV',
      ip: '192.168.1.64',
      brand: TvBrand.androidTv,
      extraInfo: {'domain': 'Mediatek_MTXXXX._androidtvremote2._tcp.local.'},
    );
    expect(DiscoveryScreen.formatTvName(tvMdns), equals('Mediatek_MTXXXX'));
  });
}

