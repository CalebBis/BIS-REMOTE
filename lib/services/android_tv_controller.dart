import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/remote_key.dart';
import '../models/tv_capability.dart';
import 'android_tv_pairing_service.dart';
import 'tv_controller.dart';

/// Contrôleur réel pour téléviseurs Android TV / Google TV.
/// Implémente le protocole Android TV Remote v2 (TLS sur port 6466)
/// basé sur l'implémentation de référence tronikos/androidtvremote2.
class AndroidTvController implements TvController {
  AndroidTvController({
    required this.host,
    required this.pairingService,
    this.onStateChanged,
    this.onReconnectFailed,
  });

  /// Adresse IP du téléviseur.
  final String host;

  /// Service d'appairage fournissant les certificats et la persistance.
  final AndroidTvPairingService pairingService;

  /// Callback de notification des changements d'état de connexion.
  final void Function(AndroidTvConnectionState state)? onStateChanged;

  /// Callback appelé lors d'un échec de reconnexion avec le numéro de tentative.
  final void Function(int attempts)? onReconnectFailed;

  /// Port TLS standard du service de télécommande Android TV Remote v2.
  static const int remotePort = 6466;

  SecureSocket? _socket;
  StreamSubscription<Uint8List>? _socketSub;
  final List<int> _receiveBuffer = [];

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;
  bool _isConnecting = false;

  /// Vrai dès que la connexion TLS est établie (SecureSocket.connect a réussi).
  bool _tlsConnected = false;

  /// Vrai uniquement après réception du remote_set_active de la TV
  /// (session complètement activée, prête à recevoir des touches).
  bool _handshakeDone = false;

  /// Capacités : aucun pointeur (le touchpad bascule en mode flèches de secours)
  /// et saisie de texte déportée absente tant qu'un support IME complet n'est pas actif.
  @override
  Set<TvCapability> get capabilities => const {};

  /// Démarre la connexion TLS et la boucle de maintien de session.
  Future<void> connect() async {
    if (_isDisposed || _isConnecting) return;

    // Vérifie que le téléviseur est bien appairé
    final isPaired = await pairingService.isTvPaired(host);
    if (!isPaired) {
      debugPrint('[AndroidTv] Téléviseur $host non appairé. Connexion annulée.');
      _notifyState(AndroidTvConnectionState.unpaired);
      return;
    }

    _isConnecting = true;
    _notifyState(AndroidTvConnectionState.connecting);
    debugPrint('[AndroidTv] Connexion TLS vers $host:$remotePort...');

    try {
      final context = await pairingService.createSecurityContext();
      _socket = await SecureSocket.connect(
        host,
        remotePort,
        context: context,
        onBadCertificate: (cert) => true, // Le téléviseur utilise son certificat auto-signé
        timeout: const Duration(seconds: 6),
      );

      _isConnecting = false;
      _tlsConnected = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      debugPrint('[AndroidTv] Connexion TLS établie sur le port $remotePort ($host:$remotePort). En attente du remote_configure de la TV...');

      _socketSub = _socket!.listen(
        _onSocketData,
        onError: (err) {
          debugPrint('[AndroidTv] Erreur flux socket : $err');
          _handleConnectionError(err);
        },
        onDone: () {
          debugPrint('[AndroidTv] Connexion fermée par le téléviseur.');
          _handleConnectionError(const SocketException('Connexion fermée par le téléviseur'));
        },
      );

      // Protocole correct : on N'envoie RIEN ici.
      // On attend le remote_configure de la TV (field 1) dans _handleSubMessage.
    } catch (e) {
      _isConnecting = false;
      _handleConnectionError(e);
    }
  }

  void _onSocketData(Uint8List data) {
    _receiveBuffer.addAll(data);

    while (_receiveBuffer.isNotEmpty) {
      final lengthResult = _decodeVarint(_receiveBuffer, 0);
      if (lengthResult == null) return;

      final msgLength = lengthResult.value;
      final varintLen = lengthResult.bytesConsumed;
      final totalExpected = varintLen + msgLength;

      if (_receiveBuffer.length < totalExpected) return;

      final rawMsg = Uint8List.fromList(_receiveBuffer.sublist(varintLen, totalExpected));
      _receiveBuffer.removeRange(0, totalExpected);

      _processRemoteMessage(rawMsg);
    }
  }

  void _processRemoteMessage(Uint8List rawMsg) {
    final hex = rawMsg.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    debugPrint('[AndroidTv] ← RX ${rawMsg.length}B [RemoteMessage] 0x$hex');

    int offset = 0;
    while (offset < rawMsg.length) {
      final tagResult = _decodeVarint(rawMsg, offset);
      if (tagResult == null) break;
      offset += tagResult.bytesConsumed;

      final fieldNumber = tagResult.value >> 3;
      final wireType = tagResult.value & 0x07;

      if (wireType == 2) {
        // Length-delimited message
        final lenResult = _decodeVarint(rawMsg, offset);
        if (lenResult == null) break;
        offset += lenResult.bytesConsumed;
        final subMsgLen = lenResult.value;
        final subMsg = rawMsg.sublist(offset, offset + subMsgLen);
        offset += subMsgLen;

        _handleSubMessage(fieldNumber, subMsg);
      } else if (wireType == 0) {
        // Varint
        final valResult = _decodeVarint(rawMsg, offset);
        if (valResult == null) break;
        offset += valResult.bytesConsumed;
        debugPrint('[AndroidTv]   field $fieldNumber (varint) = ${valResult.value}');
      } else {
        // Autre wire type non critique : arrêt du parcours
        break;
      }
    }
  }

  void _handleSubMessage(int fieldNumber, Uint8List subMsg) {
    final typeName = messageTypeName(fieldNumber);
    final hex = subMsg.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    debugPrint('[AndroidTv]   field $fieldNumber [$typeName] ${subMsg.length}B 0x$hex');

    switch (fieldNumber) {
      case 1:
        // remote_configure reçu de la TV : on répond avec le même code1
        final code1 = _parseFirstIntField(subMsg) ?? 622;
        debugPrint('[AndroidTv] ← RX remote_configure de la TV (code1: $code1). Envoi de notre remote_configure en écho.');
        _sendRaw(buildConfigurePayload(code1: code1));
        // On attend maintenant le remote_set_active de la TV (case 2).
        break;

      case 2:
        // remote_set_active reçu de la TV : on répond avec le même active, PUIS session active
        final active = _parseFirstIntField(subMsg) ?? 622;
        debugPrint('[AndroidTv] ← RX remote_set_active de la TV (active: $active). Envoi de notre remote_set_active en écho.');
        _sendRaw(buildSetActivePayload(active: active));
        // C'est MAINTENANT que la session est totalement active
        _handshakeDone = true;
        _reconnectAttempts = 0; // Reset du compteur uniquement après activation complète
        _notifyState(AndroidTvConnectionState.connected);
        debugPrint('[AndroidTv] ✓ Session active. Télécommande opérationnelle.');
        break;

      case 8:
        // remote_ping_request reçu de la TV : réponse pong obligatoire
        final val1 = _parseFirstIntField(subMsg) ?? 0;
        debugPrint('[AndroidTv] ← RX remote_ping_request (val1: $val1) → envoi pong.');
        _sendRaw(buildPingResponsePayload(val1));
        break;

      case 3:
        // remote_error : décodage de tous les champs pour diagnostic
        debugPrint('[AndroidTv] ← RX remote_error. Décodage des champs :');
        _decodeAndLogAllFields(subMsg);
        break;

      default:
        // Autre message informatif ignoré sans erreur
        break;
    }
  }

  /// Retourne le nom du type de message pour les logs (visible pour les tests).
  static String messageTypeName(int fieldNumber) {
    switch (fieldNumber) {
      case 1: return 'remote_configure';
      case 2: return 'remote_set_active';
      case 3: return 'remote_error';
      case 8: return 'remote_ping_request';
      case 9: return 'remote_ping_response';
      case 10: return 'remote_key_inject';
      default: return 'unknown_$fieldNumber';
    }
  }

  /// Décode et journalise tous les champs d'un sous-message (pour remote_error).
  void _decodeAndLogAllFields(Uint8List bytes) {
    int offset = 0;
    while (offset < bytes.length) {
      final tagResult = _decodeVarint(bytes, offset);
      if (tagResult == null) break;
      offset += tagResult.bytesConsumed;
      final fieldNumber = tagResult.value >> 3;
      final wireType = tagResult.value & 0x07;

      if (wireType == 0) {
        final valResult = _decodeVarint(bytes, offset);
        if (valResult == null) break;
        offset += valResult.bytesConsumed;
        debugPrint('[AndroidTv]   erreur field $fieldNumber (varint) = ${valResult.value}');
      } else if (wireType == 2) {
        final lenResult = _decodeVarint(bytes, offset);
        if (lenResult == null) break;
        offset += lenResult.bytesConsumed;
        final sub = bytes.sublist(offset, offset + lenResult.value);
        offset += lenResult.value;
        final hex = sub.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        debugPrint('[AndroidTv]   erreur field $fieldNumber (bytes) = 0x$hex');
      } else {
        break;
      }
    }
  }

  int? _parseFirstIntField(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    int offset = 0;
    while (offset < bytes.length) {
      final tagResult = _decodeVarint(bytes, offset);
      if (tagResult == null) break;
      offset += tagResult.bytesConsumed;

      final wireType = tagResult.value & 0x07;
      if (wireType == 0) {
        final valResult = _decodeVarint(bytes, offset);
        if (valResult != null) return valResult.value;
      } else if (wireType == 2) {
        final lenResult = _decodeVarint(bytes, offset);
        if (lenResult == null) break;
        offset += lenResult.bytesConsumed + lenResult.value;
      } else {
        break;
      }
    }
    return null;
  }

  void _handleConnectionError(Object error) {
    final wasTlsConnected = _tlsConnected;
    final wasHandshakeDone = _handshakeDone;
    _cleanupSocket();

    String messageFr;
    if (!wasTlsConnected) {
      // La connexion TLS elle-même a échoué → TV hors ligne / éteinte
      messageFr = 'TV hors ligne ou éteinte ($host)';
    } else if (error is HandshakeException || error.toString().toLowerCase().contains('certificate')) {
      messageFr = 'Certificat client refusé par la TV ($host) : réappairage nécessaire';
    } else if (!wasHandshakeDone) {
      // TLS OK mais handshake protocolaire incomplet (remote_error ou déconnexion pendant le handshake)
      messageFr = 'Connexion refusée par la TV – erreur de protocole ($host)';
    } else if (error is TimeoutException) {
      messageFr = 'Délai d\'attente dépassé pour $host (TV occupée ou éteinte)';
    } else {
      messageFr = 'Liaison interrompue avec la TV ($host)';
    }

    debugPrint('[AndroidTv] ✗ $messageFr (détail : $error)');
    _notifyState(AndroidTvConnectionState.offline);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();

    // Délai exponentiel croissant : 1s, 2s, 4s, 8s, 16s, max 30s
    final delays = [1, 2, 4, 8, 16, 30];
    final seconds = delays[min(_reconnectAttempts, delays.length - 1)];
    final delay = Duration(seconds: seconds);

    _reconnectAttempts++;
    debugPrint('[AndroidTv] Tentative de reconnexion dans ${delay.inSeconds}s (essai #$_reconnectAttempts)...');
    onReconnectFailed?.call(_reconnectAttempts);
    _reconnectTimer = Timer(delay, () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  /// Déconnecte proprement la socket TLS sans disposer définitivement le contrôleur
  /// (pour mise en veille prolongée ou passage en arrière-plan).
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupSocket();
    _isConnecting = false;
    _notifyState(AndroidTvConnectionState.offline);
    debugPrint('[AutoConnect] Connexion Android TV fermée proprement en arrière-plan.');
  }

  /// Indique si la liaison est actuellement active et prête.
  bool get isConnected => _socket != null && _handshakeDone;

  void _sendRaw(Uint8List payload) {
    if (_socket == null) return;
    try {
      final hex = payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      debugPrint('[AndroidTv] → TX ${payload.length}B 0x$hex');
      _socket!.add(payload);
    } catch (e) {
      debugPrint('[AndroidTv] Erreur transmission socket : $e');
      _handleConnectionError(e);
    }
  }

  void _cleanupSocket() {
    _tlsConnected = false;
    _handshakeDone = false;
    _socketSub?.cancel();
    _socketSub = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket?.destroy();
    _socket = null;
    _receiveBuffer.clear();
  }

  void _notifyState(AndroidTvConnectionState state) {
    if (_isDisposed) return;
    onStateChanged?.call(state);
  }

  // --- Implémentation TvController ---

  @override
  Future<void> sendCommand(RemoteKey key) async {
    final keyCode = remoteKeyToAndroidKeyCode(key);
    if (keyCode == null) {
      debugPrint('[AndroidTv] Touche inconnue ignorée : ${key.name} (${key.label})');
      return;
    }

    debugPrint('[AndroidTv] Touche envoyée : ${key.name} (keycode: $keyCode)');
    if (_socket == null) {
      debugPrint('[AndroidTv] Impossible d\'envoyer la touche : téléviseur non connecté.');
      return;
    }

    _sendRaw(buildKeyInjectPayload(keyCode, direction: 3));
  }

  @override
  Future<void> sendBackspace() async {
    // Android KEYCODE_DEL = 67
    debugPrint('[AndroidTv] Touche envoyée : DEL / Backspace (keycode: 67)');
    if (_socket == null) return;
    _sendRaw(buildKeyInjectPayload(67, direction: 3));
  }

  @override
  Future<void> sendEnter() async {
    // Android KEYCODE_ENTER = 66
    debugPrint('[AndroidTv] Touche envoyée : ENTER (keycode: 66)');
    if (_socket == null) return;
    _sendRaw(buildKeyInjectPayload(66, direction: 3));
  }

  @override
  Future<void> sendPointerMove(double dx, double dy) async {}

  @override
  Future<void> sendPointerClick() async {}

  @override
  Future<void> sendScroll(double dy) async {}

  @override
  Future<void> sendText(String text) async {}

  /// Arrêt propre de la connexion et des tâches d'arrière-plan.
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupSocket();
    debugPrint('[AndroidTv] Contrôleur Android TV arrêté proprement.');
  }

  // --- Encodage et décodage Protobuf / KeyCodes Android ---

  /// Mappe chaque [RemoteKey] vers son KeyCode Android standard officiel.
  static int? remoteKeyToAndroidKeyCode(RemoteKey key) {
    switch (key) {
      case RemoteKey.power:
        return 26; // KEYCODE_POWER
      case RemoteKey.up:
        return 19; // KEYCODE_DPAD_UP
      case RemoteKey.down:
        return 20; // KEYCODE_DPAD_DOWN
      case RemoteKey.left:
        return 21; // KEYCODE_DPAD_LEFT
      case RemoteKey.right:
        return 22; // KEYCODE_DPAD_RIGHT
      case RemoteKey.ok:
        return 23; // KEYCODE_DPAD_CENTER
      case RemoteKey.back:
        return 4; // KEYCODE_BACK
      case RemoteKey.home:
        return 3; // KEYCODE_HOME
      case RemoteKey.menu:
        return 82; // KEYCODE_MENU
      case RemoteKey.volumeUp:
        return 24; // KEYCODE_VOLUME_UP
      case RemoteKey.volumeDown:
        return 25; // KEYCODE_VOLUME_DOWN
      case RemoteKey.mute:
        return 164; // KEYCODE_VOLUME_MUTE
      case RemoteKey.channelUp:
        return 166; // KEYCODE_CHANNEL_UP
      case RemoteKey.channelDown:
        return 167; // KEYCODE_CHANNEL_DOWN
      case RemoteKey.digit0:
        return 7; // KEYCODE_0
      case RemoteKey.digit1:
        return 8; // KEYCODE_1
      case RemoteKey.digit2:
        return 9; // KEYCODE_2
      case RemoteKey.digit3:
        return 10; // KEYCODE_3
      case RemoteKey.digit4:
        return 11; // KEYCODE_4
      case RemoteKey.digit5:
        return 12; // KEYCODE_5
      case RemoteKey.digit6:
        return 13; // KEYCODE_6
      case RemoteKey.digit7:
        return 14; // KEYCODE_7
      case RemoteKey.digit8:
        return 15; // KEYCODE_8
      case RemoteKey.digit9:
        return 16; // KEYCODE_9
      case RemoteKey.playPause:
        return 85; // KEYCODE_MEDIA_PLAY_PAUSE
      case RemoteKey.previous:
        return 88; // KEYCODE_MEDIA_PREVIOUS
      case RemoteKey.next:
        return 87; // KEYCODE_MEDIA_NEXT
    }
  }

  /// Construit un paquet varint-délimité [RemoteMessage] contenant [RemoteKeyInject].
  static Uint8List buildKeyInjectPayload(int keyCode, {int direction = 3}) {
    final inner = <int>[
      ..._fieldTag(1, 0),
      ..._encodeVarint(keyCode),
      ..._fieldTag(2, 0),
      ..._encodeVarint(direction),
    ];

    final msg = <int>[
      ..._fieldTag(10, 2),
      ..._encodeVarint(inner.length),
      ...inner,
    ];

    return Uint8List.fromList([
      ..._encodeVarint(msg.length),
      ...msg,
    ]);
  }

  /// Construit un paquet varint-délimité [RemoteMessage] contenant [RemoteConfigure].
  static Uint8List buildConfigurePayload({int code1 = 622}) {
    final modelBytes = utf8.encode('BIS Remote');
    final vendorBytes = utf8.encode('BIS');
    final unknown2Bytes = utf8.encode('1');
    final pkgBytes = utf8.encode('atvremote');
    final verBytes = utf8.encode('1.0.0');

    final devInfo = <int>[
      ..._fieldTag(1, 2),
      ..._encodeVarint(modelBytes.length),
      ...modelBytes,
      ..._fieldTag(2, 2),
      ..._encodeVarint(vendorBytes.length),
      ...vendorBytes,
      ..._fieldTag(3, 0),
      ..._encodeVarint(1),
      ..._fieldTag(4, 2),
      ..._encodeVarint(unknown2Bytes.length),
      ...unknown2Bytes,
      ..._fieldTag(5, 2),
      ..._encodeVarint(pkgBytes.length),
      ...pkgBytes,
      ..._fieldTag(6, 2),
      ..._encodeVarint(verBytes.length),
      ...verBytes,
    ];

    final config = <int>[
      ..._fieldTag(1, 0),
      ..._encodeVarint(code1),
      ..._fieldTag(2, 2),
      ..._encodeVarint(devInfo.length),
      ...devInfo,
    ];

    final msg = <int>[
      ..._fieldTag(1, 2),
      ..._encodeVarint(config.length),
      ...config,
    ];

    return Uint8List.fromList([
      ..._encodeVarint(msg.length),
      ...msg,
    ]);
  }

  /// Construit un paquet varint-délimité [RemoteMessage] contenant [RemoteSetActive].
  static Uint8List buildSetActivePayload({int active = 622}) {
    final activeInner = <int>[
      ..._fieldTag(1, 0),
      ..._encodeVarint(active),
    ];

    final msg = <int>[
      ..._fieldTag(2, 2),
      ..._encodeVarint(activeInner.length),
      ...activeInner,
    ];

    return Uint8List.fromList([
      ..._encodeVarint(msg.length),
      ...msg,
    ]);
  }

  /// Construit un paquet varint-délimité [RemoteMessage] contenant [RemotePingResponse].
  static Uint8List buildPingResponsePayload(int val1) {
    final pingInner = <int>[
      ..._fieldTag(1, 0),
      ..._encodeVarint(val1),
    ];

    final msg = <int>[
      ..._fieldTag(9, 2),
      ..._encodeVarint(pingInner.length),
      ...pingInner,
    ];

    return Uint8List.fromList([
      ..._encodeVarint(msg.length),
      ...msg,
    ]);
  }

  static Uint8List _encodeVarint(int value) {
    final bytes = <int>[];
    int v = value;
    while (v > 0x7F) {
      bytes.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
    bytes.add(v & 0x7F);
    return Uint8List.fromList(bytes);
  }

  static Uint8List _fieldTag(int fieldNumber, int wireType) {
    return _encodeVarint((fieldNumber << 3) | wireType);
  }

  static ({int value, int bytesConsumed})? _decodeVarint(List<int> bytes, int offset) {
    int result = 0;
    int shift = 0;
    int consumed = 0;

    for (int i = offset; i < bytes.length; i++) {
      final byte = bytes[i];
      consumed++;
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) {
        return (value: result, bytesConsumed: consumed);
      }
      shift += 7;
      if (shift > 35) return null;
    }
    return null;
  }
}
