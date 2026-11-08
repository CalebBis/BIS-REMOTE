import 'package:bis_remote/models/remote_key.dart';
import 'package:bis_remote/services/android_tv_controller.dart';
import 'package:bis_remote/services/android_tv_pairing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidTvController - Correspondance des touches Android KeyCode', () {
    test('Toutes les touches requises sont correctement mappées', () {
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.power), equals(26));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.up), equals(19));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.down), equals(20));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.left), equals(21));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.right), equals(22));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.ok), equals(23));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.back), equals(4));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.home), equals(3));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.menu), equals(82));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.volumeUp), equals(24));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.volumeDown), equals(25));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.mute), equals(164));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.channelUp), equals(166));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.channelDown), equals(167));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.digit0), equals(7));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.digit1), equals(8));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.digit2), equals(9));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.digit3), equals(10));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.digit4), equals(11));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.digit5), equals(12));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.digit6), equals(13));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.digit7), equals(14));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.digit8), equals(15));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.digit9), equals(16));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.playPause), equals(85));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.previous), equals(88));
      expect(AndroidTvController.remoteKeyToAndroidKeyCode(RemoteKey.next), equals(87));
    });
  });

  group('AndroidTvController - Encodage des trames Protobuf RemoteMessage', () {
    test('buildKeyInjectPayload encode correctement field 10 avec direction SHORT', () {
      final payload = AndroidTvController.buildKeyInjectPayload(26, direction: 3);

      expect(payload.isNotEmpty, isTrue);
      // Le premier octet est la longueur du message
      expect(payload[0], equals(payload.length - 1));
      // Tag de remote_key_inject = (10 << 3) | 2 = 82 = 0x52
      expect(payload[1], equals(0x52));
    });

    test('buildConfigurePayload encode le message remote_configure', () {
      final payload = AndroidTvController.buildConfigurePayload(code1: 622);

      expect(payload.isNotEmpty, isTrue);
      // Tag de remote_configure = (1 << 3) | 2 = 10 = 0x0A
      expect(payload[1], equals(0x0A));
    });

    test('buildSetActivePayload encode le message remote_set_active', () {
      final payload = AndroidTvController.buildSetActivePayload(active: 622);

      expect(payload.isNotEmpty, isTrue);
      // Tag de remote_set_active = (2 << 3) | 2 = 18 = 0x12
      expect(payload[1], equals(0x12));
    });

    test('buildPingResponsePayload encode le pong avec la valeur val1 reçue', () {
      final payload = AndroidTvController.buildPingResponsePayload(42);

      expect(payload.isNotEmpty, isTrue);
      // Tag de remote_ping_response = (9 << 3) | 2 = 74 = 0x4A
      expect(payload[1], equals(0x4A));
    });
  });

  group('AndroidTvController - Capacités', () {
    test('Capacités vides (aucun pointer, aucune saisie de texte)', () {
      final controller = AndroidTvController(
        host: '192.168.1.64',
        pairingService: AndroidTvPairingService(),
      );

      expect(controller.capabilities, isEmpty);
      controller.dispose();
    });
  });
}
