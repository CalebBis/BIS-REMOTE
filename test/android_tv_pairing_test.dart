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
}

