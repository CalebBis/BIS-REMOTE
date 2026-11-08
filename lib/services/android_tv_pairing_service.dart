import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Statuts du processus d'appairage Android TV.
enum PairingStepStatus {
  idle,
  connecting,
  waitingForPin,
  verifyingPin,
  invalidPin,
  unreachable,
  success,
  error,
}

/// Statuts de liaison avec une Android TV.
enum AndroidTvConnectionState {
  unpaired,
  paired,
  connecting,
  connected,
  offline,
}

/// Service gérant la génération de certificats X.509, le protocole d'appairage POLO
/// sur le port 6467, la validation cryptographique du code PIN et le test de connexion sur le port 6466.
class AndroidTvPairingService {
  AndroidTvPairingService({FlutterSecureStorage? secureStorage})
      : _storage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _certKey = 'android_tv_client_cert_pem';
  static const String _privKeyKey = 'android_tv_client_key_pem';
  static const String _pairedPrefix = 'android_tv_paired_';

  static const int pairingPort = 6467;
  static const int remotePort = 6466;
  static const String serviceName = 'atvremote';
  static const String clientName = 'BisRemote';

  String? _clientCertPem;
  String? _clientKeyPem;
  RSAPublicKey? _clientPublicKey;

  SecureSocket? _pairingSocket;
  RSAPublicKey? _serverPublicKey;

  Completer<bool>? _onPinReadyCompleter;
  Completer<bool>? _onSecretAckCompleter;

  final List<int> _receiveBuffer = <int>[];
  StreamSubscription<Uint8List>? _socketSub;

  /// Vérifie si une TV avec cette adresse IP a déjà été appairée.
  Future<bool> isTvPaired(String ip) async {
    try {
      final value = await _storage.read(key: '$_pairedPrefix$ip');
      return value == 'true';
    } catch (e) {
      debugPrint('[AndroidTv] Erreur lecture stockage sécurisé: $e');
      return false;
    }
  }

  /// Enregistre l'état d'appairage pour une adresse IP.
  Future<void> setTvPaired(String ip, bool paired) async {
    try {
      if (paired) {
        await _storage.write(key: '$_pairedPrefix$ip', value: 'true');
      } else {
        await _storage.delete(key: '$_pairedPrefix$ip');
      }
    } catch (e) {
      debugPrint('[AndroidTv] Erreur écriture stockage sécurisé: $e');
    }
  }

  /// Charge le certificat client et sa clé privée depuis le stockage sécurisé,
  /// ou les génère s'ils n'existent pas encore.
  Future<void> initializeCredentials() async {
    if (_clientCertPem != null && _clientKeyPem != null && _clientPublicKey != null) {
      return;
    }

    debugPrint('[AndroidTv] Initialisation des identifiants client X.509...');
    String? cert = await _storage.read(key: _certKey);
    String? privKey = await _storage.read(key: _privKeyKey);

    if (cert == null || privKey == null) {
      debugPrint('[AndroidTv] Aucun certificat trouvé. Génération d\'une nouvelle paire de clés RSA (2048 bits)...');
      final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
      final rsaPriv = keyPair.privateKey as RSAPrivateKey;
      final rsaPub = keyPair.publicKey as RSAPublicKey;

      privKey = CryptoUtils.encodeRSAPrivateKeyToPem(rsaPriv);
      final csrPem = X509Utils.generateRsaCsrPem(
        {'CN': serviceName, 'O': clientName},
        rsaPriv,
        rsaPub,
      );
      cert = X509Utils.generateSelfSignedCertificate(
        rsaPriv,
        csrPem,
        3650, // 10 ans
      );

      await _storage.write(key: _certKey, value: cert);
      await _storage.write(key: _privKeyKey, value: privKey);
      debugPrint('[AndroidTv] Certificat X.509 et clé privée sauvegardés dans le stockage sécurisé.');
      _clientPublicKey = rsaPub;
    } else {
      debugPrint('[AndroidTv] Certificat X.509 et clé privée chargés avec succès depuis le stockage sécurisé.');
      final certData = X509Utils.x509CertificateFromPem(cert);
      final bytesString = certData.tbsCertificate!.subjectPublicKeyInfo.bytes!;
      final rsaBytes = _hexToBytes(bytesString);
      _clientPublicKey = CryptoUtils.rsaPublicKeyFromDERBytes(rsaBytes);
    }

    _clientCertPem = cert;
    _clientKeyPem = privKey;
  }

  /// Construit un `SecurityContext` configuré avec le certificat et la clé client.
  SecurityContext _buildSecurityContext() {
    final context = SecurityContext(withTrustedRoots: false);
    context.setClientAuthoritiesBytes(utf8.encode(_clientCertPem!));
    context.useCertificateChainBytes(utf8.encode(_clientCertPem!));
    context.usePrivateKeyBytes(utf8.encode(_clientKeyPem!));
    return context;
  }

  /// Initialise les identifiants si nécessaire et retourne un `SecurityContext` TLS configuré.
  Future<SecurityContext> createSecurityContext() async {
    await initializeCredentials();
    return _buildSecurityContext();
  }

  /// Démarre le processus d'appairage avec la TV sur le port 6467.
  /// Notifie les changements d'étape via [onStatusChanged].
  Future<void> startPairing({
    required String host,
    required void Function(PairingStepStatus status, String message) onStatusChanged,
  }) async {
    await closePairing();
    await initializeCredentials();

    onStatusChanged(PairingStepStatus.connecting, 'Connexion à la TV ($host:$pairingPort)...');
    debugPrint('[AndroidTv] Tentative de connexion TLS vers $host:$pairingPort...');

    try {
      final context = _buildSecurityContext();
      _pairingSocket = await SecureSocket.connect(
        host,
        pairingPort,
        context: context,
        onBadCertificate: (X509Certificate cert) => true, // TV utilise un certificat auto-signé
        timeout: const Duration(seconds: 8),
      );
      debugPrint('[AndroidTv] Connexion TLS établie sur le port $pairingPort.');

      // Récupération de la clé publique du serveur TV
      final peerCert = _pairingSocket!.peerCertificate;
      if (peerCert == null) {
        throw Exception('Le téléviseur n\'a pas fourni de certificat TLS.');
      }
      _serverPublicKey = _extractPublicKeyFromDer(peerCert.der);
      debugPrint('[AndroidTv] Clé publique du serveur TV extraite avec succès.');

      _onPinReadyCompleter = Completer<bool>();
      _receiveBuffer.clear();

      _socketSub = _pairingSocket!.listen(
        _onSocketData,
        onError: (err) {
          debugPrint('[AndroidTv] Erreur socket appairage: $err');
          _cleanupCompletersWithError('Erreur réseau lors de l\'appairage.');
        },
        onDone: () {
          debugPrint('[AndroidTv] Connexion socket appairage fermée par la TV.');
          _cleanupCompletersWithError('Connexion fermée prématurément par la TV.');
        },
      );

      // Envoi du message initial PairingRequest
      debugPrint('[AndroidTv] Envoi de PairingRequest (service: $serviceName, client: $clientName)...');
      _sendMessage(_buildPairingRequest(clientName: clientName, serviceName: serviceName));

      onStatusChanged(PairingStepStatus.waitingForPin, 'En attente du code affiché sur la TV…');

      // Attente que la TV soit prête et affiche le code PIN
      await _onPinReadyCompleter!.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('Délai d\'attente dépassé pour l\'affichage du PIN sur la TV.'),
      );

      debugPrint('[AndroidTv] La TV affiche actuellement le code d\'appairage sur son écran.');
    } on SocketException catch (e) {
      debugPrint('[AndroidTv] Échec de connexion vers $host:$pairingPort : $e');
      await closePairing();
      onStatusChanged(PairingStepStatus.unreachable, 'TV injoignable sur le réseau local.');
      rethrow;
    } on TimeoutException catch (e) {
      debugPrint('[AndroidTv] Timeout appairage vers $host:$pairingPort : $e');
      await closePairing();
      onStatusChanged(PairingStepStatus.unreachable, 'TV injoignable (délai dépassé).');
      rethrow;
    } catch (e) {
      debugPrint('[AndroidTv] Erreur inattendue lors de l\'appairage: $e');
      await closePairing();
      onStatusChanged(PairingStepStatus.error, 'Erreur: $e');
      rethrow;
    }
  }

  /// Soumet le code PIN (6 caractères hexadécimaux) saisi par l'utilisateur.
  Future<bool> submitPin({
    required String host,
    required String pin,
    required void Function(PairingStepStatus status, String message) onStatusChanged,
  }) async {
    final cleanPin = pin.trim().toUpperCase();
    if (cleanPin.length != 6) {
      debugPrint('[AndroidTv] Longueur du code invalide (${cleanPin.length} caractères au lieu de 6).');
      onStatusChanged(PairingStepStatus.invalidPin, 'Le code doit comporter 6 caractères.');
      return false;
    }

    final isHex = RegExp(r'^[0-9A-F]{6}$').hasMatch(cleanPin);
    if (!isHex) {
      debugPrint('[AndroidTv] Format du code invalide (caractères non hexadécimaux).');
      onStatusChanged(PairingStepStatus.invalidPin, 'Le code doit être hexadécimal (0-9, A-F).');
      return false;
    }

    if (_pairingSocket == null || _serverPublicKey == null || _clientPublicKey == null) {
      debugPrint('[AndroidTv] Session d\'appairage non active.');
      onStatusChanged(PairingStepStatus.error, 'Session d\'appairage expirée ou non active.');
      return false;
    }

    onStatusChanged(PairingStepStatus.verifyingPin, 'Vérification du code PIN en cours...');
    debugPrint('[AndroidTv] Vérification cryptographique locale du PIN...');

    // Calcul du challenge SHA-256
    final hashResult = computeSecretHash(
      clientModulus: _clientPublicKey!.modulus!,
      clientExponent: _clientPublicKey!.exponent!,
      serverModulus: _serverPublicKey!.modulus!,
      serverExponent: _serverPublicKey!.exponent!,
      pin: cleanPin,
    );

    // Vérification du premier octet (checksum)
    final expectedFirstByte = int.parse(cleanPin.substring(0, 2), radix: 16);
    if (hashResult[0] != expectedFirstByte) {
      debugPrint('[AndroidTv] Le premier octet du hash ne correspond pas au PIN. Code incorrect.');
      onStatusChanged(PairingStepStatus.invalidPin, 'Code incorrect. Veuillez réessayer.');
      return false;
    }

    debugPrint('[AndroidTv] Checksum locale validée. Envoi du PairingSecret au téléviseur...');
    _onSecretAckCompleter = Completer<bool>();
    _sendMessage(_buildSecretMessage(hashResult));

    try {
      final success = await _onSecretAckCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Délai d\'attente dépassé pour la confirmation SecretAck.'),
      );

      if (success) {
        debugPrint('[AndroidTv] Appairage validé avec succès par la TV !');
        await setTvPaired(host, true);
        onStatusChanged(PairingStepStatus.success, 'Appairage réussi !');
        await closePairing();
        return true;
      } else {
        debugPrint('[AndroidTv] La TV a refusé le secret d\'appairage.');
        onStatusChanged(PairingStepStatus.invalidPin, 'Code incorrect ou refusé par la TV.');
        return false;
      }
    } catch (e) {
      debugPrint('[AndroidTv] Erreur validation secret: $e');
      onStatusChanged(PairingStepStatus.invalidPin, 'Code incorrect ou non validé.');
      return false;
    }
  }

  /// Teste la connexion TLS sur le port 6466 après appairage pour vérifier si la TV est connectée.
  Future<AndroidTvConnectionState> testRemotePortConnection(String host) async {
    debugPrint('[AndroidTv] Test de connexion TLS sur le port $remotePort ($host:$remotePort)...');
    try {
      await initializeCredentials();
      final context = _buildSecurityContext();
      final socket = await SecureSocket.connect(
        host,
        remotePort,
        context: context,
        onBadCertificate: (cert) => true,
        timeout: const Duration(seconds: 5),
      );
      debugPrint('[AndroidTv] Connexion au port $remotePort réussie ! Statut: connectée.');
      await socket.close();
      socket.destroy();
      return AndroidTvConnectionState.connected;
    } on SocketException catch (e) {
      debugPrint('[AndroidTv] Port $remotePort inaccessible : $e. Statut: hors ligne.');
      return AndroidTvConnectionState.offline;
    } on TimeoutException catch (e) {
      debugPrint('[AndroidTv] Timeout sur le port $remotePort : $e. Statut: hors ligne.');
      return AndroidTvConnectionState.offline;
    } catch (e) {
      debugPrint('[AndroidTv] Erreur test connexion port $remotePort : $e. Statut: hors ligne.');
      return AndroidTvConnectionState.offline;
    }
  }

  /// Ferme proprement la socket d'appairage.
  Future<void> closePairing() async {
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _pairingSocket?.close();
    } catch (_) {}
    _pairingSocket?.destroy();
    _pairingSocket = null;
    _receiveBuffer.clear();
    _cleanupCompletersWithError('Annulé');
  }

  void _cleanupCompletersWithError(String message) {
    if (_onPinReadyCompleter != null && !_onPinReadyCompleter!.isCompleted) {
      _onPinReadyCompleter!.completeError(Exception(message));
    }
    if (_onSecretAckCompleter != null && !_onSecretAckCompleter!.isCompleted) {
      _onSecretAckCompleter!.completeError(Exception(message));
    }
  }

  // --- Gestion des données entrantes de la socket ---

  void _onSocketData(Uint8List data) {
    _receiveBuffer.addAll(data);

    while (_receiveBuffer.isNotEmpty) {
      final lengthResult = _decodeVarint(_receiveBuffer, 0);
      if (lengthResult == null) {
        // Varint incomplet
        return;
      }

      final msgLength = lengthResult.value;
      final varintLen = lengthResult.bytesConsumed;
      final totalExpected = varintLen + msgLength;

      if (_receiveBuffer.length < totalExpected) {
        // Message pas encore entièrement reçu
        return;
      }

      final rawMessage = Uint8List.fromList(_receiveBuffer.sublist(varintLen, totalExpected));
      _receiveBuffer.removeRange(0, totalExpected);

      _handleReceivedMessage(rawMessage);
    }
  }

  void _handleReceivedMessage(Uint8List rawMessage) {
    final fields = _parseProtobufFields(rawMessage);
    final status = fields[2] as int? ?? 200;

    if (status != 200) {
      debugPrint('[AndroidTv] Message reçu avec statut d\'erreur: $status');
      _cleanupCompletersWithError('Erreur statut reçu: $status');
      return;
    }

    if (fields.containsKey(11)) {
      // pairing_request_ack
      debugPrint('[AndroidTv] Reçu PairingRequestAck. Envoi de Options...');
      _sendMessage(_buildOptionsMessage());
    } else if (fields.containsKey(20)) {
      // options
      debugPrint('[AndroidTv] Reçu Options. Envoi de Configuration...');
      _sendMessage(_buildConfigurationMessage());
    } else if (fields.containsKey(31)) {
      // configuration_ack
      debugPrint('[AndroidTv] Reçu ConfigurationAck ! La TV affiche le PIN à l\'écran.');
      if (_onPinReadyCompleter != null && !_onPinReadyCompleter!.isCompleted) {
        _onPinReadyCompleter!.complete(true);
      }
    } else if (fields.containsKey(41)) {
      // secret_ack
      debugPrint('[AndroidTv] Reçu SecretAck ! Code validé avec succès.');
      if (_onSecretAckCompleter != null && !_onSecretAckCompleter!.isCompleted) {
        _onSecretAckCompleter!.complete(true);
      }
    } else {
      debugPrint('[AndroidTv] Message reçu non géré.');
    }
  }

  void _sendMessage(Uint8List messageBytes) {
    if (_pairingSocket == null) return;
    final lengthVarint = _encodeVarint(messageBytes.length);
    _pairingSocket!.add(Uint8List.fromList([...lengthVarint, ...messageBytes]));
  }

  // --- Cryptographie et calcul du hash ---

  /// Calcule le hash SHA-256 du secret d'appairage selon l'algorithme officiel POLO / Google TV.
  static Uint8List computeSecretHash({
    required BigInt clientModulus,
    required BigInt clientExponent,
    required BigInt serverModulus,
    required BigInt serverExponent,
    required String pin,
  }) {
    String modToHex(BigInt n) {
      var h = n.toRadixString(16).toUpperCase();
      if (h.length % 2 != 0) h = '0$h';
      return h;
    }

    String expToHex(BigInt e) {
      var h = '0${e.toRadixString(16).toUpperCase()}';
      if (h.length % 2 != 0) h = '0$h';
      return h;
    }

    final payload = <int>[
      ..._hexToBytes(modToHex(clientModulus)),
      ..._hexToBytes(expToHex(clientExponent)),
      ..._hexToBytes(modToHex(serverModulus)),
      ..._hexToBytes(expToHex(serverExponent)),
      ..._hexToBytes(pin.substring(2)),
    ];

    final digest = crypto.sha256.convert(payload);
    return Uint8List.fromList(digest.bytes);
  }

  RSAPublicKey _extractPublicKeyFromDer(Uint8List certDer) {
    final pem = '-----BEGIN CERTIFICATE-----\n${base64.encode(certDer)}\n-----END CERTIFICATE-----';
    final certData = X509Utils.x509CertificateFromPem(pem);
    final bytesString = certData.tbsCertificate!.subjectPublicKeyInfo.bytes!;
    final rsaBytes = _hexToBytes(bytesString);
    return CryptoUtils.rsaPublicKeyFromDERBytes(rsaBytes);
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.replaceAll(' ', '').toUpperCase();
    final bytes = <int>[];
    for (int i = 0; i < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  // --- Encodage Protobuf minimal pour le protocole POLO ---

  static Uint8List _buildPairingRequest({required String clientName, required String serviceName}) {
    // OuterMessage:
    // field 1 (uint32): protocol_version = 2
    // field 2 (enum): status = 200
    // field 10 (PairingRequest):
    //   field 1 (string): service_name = "atvremote"
    //   field 2 (string): client_name = "BisRemote"
    final serviceBytes = utf8.encode(serviceName);
    final clientBytes = utf8.encode(clientName);

    final reqInner = <int>[
      ..._fieldTag(1, 2),
      ..._encodeVarint(serviceBytes.length),
      ...serviceBytes,
      ..._fieldTag(2, 2),
      ..._encodeVarint(clientBytes.length),
      ...clientBytes,
    ];

    return Uint8List.fromList([
      ..._fieldTag(1, 0),
      ..._encodeVarint(2), // protocol_version = 2
      ..._fieldTag(2, 0),
      ..._encodeVarint(200), // STATUS_OK = 200
      ..._fieldTag(10, 2),
      ..._encodeVarint(reqInner.length),
      ...reqInner,
    ]);
  }

  static Uint8List _buildOptionsMessage() {
    // OuterMessage:
    // field 1: protocol_version = 2
    // field 2: status = 200
    // field 20 (Options):
    //   field 1 (Encoding):
    //     field 1 (EncodingType): 3 (ENCODING_TYPE_HEXADECIMAL)
    //     field 2 (symbol_length): 6
    //   field 3 (preferred_role): 1 (ROLE_TYPE_INPUT)
    final encodingInner = <int>[
      ..._fieldTag(1, 0),
      ..._encodeVarint(3),
      ..._fieldTag(2, 0),
      ..._encodeVarint(6),
    ];

    final optionsInner = <int>[
      ..._fieldTag(1, 2),
      ..._encodeVarint(encodingInner.length),
      ...encodingInner,
      ..._fieldTag(3, 0),
      ..._encodeVarint(1),
    ];

    return Uint8List.fromList([
      ..._fieldTag(1, 0),
      ..._encodeVarint(2),
      ..._fieldTag(2, 0),
      ..._encodeVarint(200),
      ..._fieldTag(20, 2),
      ..._encodeVarint(optionsInner.length),
      ...optionsInner,
    ]);
  }

  static Uint8List _buildConfigurationMessage() {
    // OuterMessage:
    // field 1: protocol_version = 2
    // field 2: status = 200
    // field 30 (Configuration):
    //   field 1 (Encoding):
    //     field 1: 3
    //     field 2: 6
    //   field 2 (client_role): 1 (ROLE_TYPE_INPUT)
    final encodingInner = <int>[
      ..._fieldTag(1, 0),
      ..._encodeVarint(3),
      ..._fieldTag(2, 0),
      ..._encodeVarint(6),
    ];

    final configInner = <int>[
      ..._fieldTag(1, 2),
      ..._encodeVarint(encodingInner.length),
      ...encodingInner,
      ..._fieldTag(2, 0),
      ..._encodeVarint(1),
    ];

    return Uint8List.fromList([
      ..._fieldTag(1, 0),
      ..._encodeVarint(2),
      ..._fieldTag(2, 0),
      ..._encodeVarint(200),
      ..._fieldTag(30, 2),
      ..._encodeVarint(configInner.length),
      ...configInner,
    ]);
  }

  static Uint8List _buildSecretMessage(Uint8List hash) {
    // OuterMessage:
    // field 1: protocol_version = 2
    // field 2: status = 200
    // field 40 (Secret):
    //   field 1: bytes secret
    final secretInner = <int>[
      ..._fieldTag(1, 2),
      ..._encodeVarint(hash.length),
      ...hash,
    ];

    return Uint8List.fromList([
      ..._fieldTag(1, 0),
      ..._encodeVarint(2),
      ..._fieldTag(2, 0),
      ..._encodeVarint(200),
      ..._fieldTag(40, 2),
      ..._encodeVarint(secretInner.length),
      ...secretInner,
    ]);
  }

  static List<int> _fieldTag(int fieldNumber, int wireType) {
    return _encodeVarint((fieldNumber << 3) | wireType);
  }

  static List<int> _encodeVarint(int value) {
    final bytes = <int>[];
    int v = value;
    while (v > 127) {
      bytes.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
    bytes.add(v & 0x7F);
    return bytes;
  }

  static _VarintResult? _decodeVarint(List<int> bytes, int offset) {
    int result = 0;
    int shift = 0;
    int i = offset;
    while (i < bytes.length) {
      final b = bytes[i++];
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) {
        return _VarintResult(value: result, bytesConsumed: i - offset);
      }
      shift += 7;
      if (shift >= 64) {
        return null;
      }
    }
    return null;
  }

  static Map<int, dynamic> _parseProtobufFields(Uint8List bytes) {
    final fields = <int, dynamic>{};
    int offset = 0;

    while (offset < bytes.length) {
      final tagResult = _decodeVarint(bytes, offset);
      if (tagResult == null) break;
      offset += tagResult.bytesConsumed;

      final tag = tagResult.value;
      final fieldNumber = tag >> 3;
      final wireType = tag & 0x07;

      if (wireType == 0) {
        // Varint
        final valResult = _decodeVarint(bytes, offset);
        if (valResult == null) break;
        offset += valResult.bytesConsumed;
        fields[fieldNumber] = valResult.value;
      } else if (wireType == 2) {
        // Length-delimited
        final lenResult = _decodeVarint(bytes, offset);
        if (lenResult == null) break;
        offset += lenResult.bytesConsumed;
        final length = lenResult.value;
        if (offset + length > bytes.length) break;
        fields[fieldNumber] = bytes.sublist(offset, offset + length);
        offset += length;
      } else {
        // Type non supporté dans POLO
        break;
      }
    }

    return fields;
  }
}

class _VarintResult {
  const _VarintResult({required this.value, required this.bytesConsumed});
  final int value;
  final int bytesConsumed;
}
