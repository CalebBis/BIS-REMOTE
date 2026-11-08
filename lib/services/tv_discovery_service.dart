import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/discovered_tv.dart';

/// Service de découverte des téléviseurs sur le réseau Wi-Fi local via SSDP et mDNS.
class TvDiscoveryService {
  static const MethodChannel _multicastChannel =
      MethodChannel('com.bis.bis_remote/multicast');

  static const String _ssdpAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;

  static const List<String> _ssdpTargets = [
    'ssdp:all',
    'urn:dial-multiscreen-org:service:dial:1',
    'roku:ecp',
  ];

  static const List<String> _mdnsServices = [
    '_androidtvremote2._tcp.local',
    '_googlecast._tcp.local',
  ];

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  /// Vérifie si l'appareil dispose d'une connexion Wi-Fi / IP locale active (IPv4 non loopback).
  static Future<bool> isWifiConnected() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      return interfaces.any((interface) => interface.addresses.isNotEmpty);
    } catch (e) {
      debugPrint('[TvDiscovery] Erreur lors de la vérification réseau : $e');
      return false;
    }
  }

  /// Active le verrou Multicast Android pour permettre la réception des paquets UDP.
  Future<void> _acquireMulticastLock() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _multicastChannel.invokeMethod('acquireMulticastLock');
      debugPrint('[TvDiscovery] MulticastLock Android activé');
    } catch (e) {
      debugPrint('[TvDiscovery] Attention : impossible d\'activer MulticastLock : $e');
    }
  }

  /// Désactive le verrou Multicast Android pour économiser la batterie.
  Future<void> _releaseMulticastLock() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _multicastChannel.invokeMethod('releaseMulticastLock');
      debugPrint('[TvDiscovery] MulticastLock Android relâché');
    } catch (e) {
      debugPrint('[TvDiscovery] Attention : impossible de relâcher MulticastLock : $e');
    }
  }

  /// Démarre un scan de 8 secondes (annulable) et émet les téléviseurs découverts sans doublon.
  Stream<DiscoveredTv> scanTvs({
    Duration duration = const Duration(seconds: 8),
  }) {
    final controller = StreamController<DiscoveredTv>.broadcast();
    final discoveredMap = <String, DiscoveredTv>{};
    RawDatagramSocket? ssdpSocket;
    MDnsClient? mdnsClient;
    Timer? timeoutTimer;

    void emitOrUpdate(DiscoveredTv tv) {
      final existing = discoveredMap[tv.ip];
      if (existing == null) {
        discoveredMap[tv.ip] = tv;
        debugPrint(
          '[TvDiscovery] NOUVEAU TÉLÉVISEUR DÉTECTÉ : "${tv.name}" | IP: ${tv.ip} | Marque: ${tv.brand.displayName}',
        );
        controller.add(tv);
      } else {
        // Enrichissement si nouvelle marque connue ou meilleur nom
        final shouldUpdateBrand =
            existing.brand == TvBrand.unknown && tv.brand != TvBrand.unknown;
        final shouldUpdateName =
            (existing.name.startsWith('TV ') || existing.name == 'Téléviseur') &&
            tv.name != existing.name;

        if (shouldUpdateBrand || shouldUpdateName || existing.port == null && tv.port != null) {
          final updated = existing.copyWith(
            name: shouldUpdateName ? tv.name : existing.name,
            brand: shouldUpdateBrand ? tv.brand : existing.brand,
            port: tv.port ?? existing.port,
            location: tv.location ?? existing.location,
            extraInfo: {...?existing.extraInfo, ...?tv.extraInfo},
          );
          discoveredMap[tv.ip] = updated;
          debugPrint(
            '[TvDiscovery] TÉLÉVISEUR ENRICHI : "${updated.name}" | IP: ${updated.ip} | Marque: ${updated.brand.displayName}',
          );
          controller.add(updated);
        }
      }
    }

    Future<void> stopScan() async {
      if (!_isScanning) return;
      _isScanning = false;
      timeoutTimer?.cancel();
      try {
        ssdpSocket?.close();
      } catch (_) {}
      try {
        mdnsClient?.stop();
      } catch (_) {}
      await _releaseMulticastLock();
      if (!controller.isClosed) {
        await controller.close();
      }
      debugPrint('[TvDiscovery] Scan terminé.');
    }

    controller.onCancel = () {
      stopScan();
    };

    _startScanning(
      emitOrUpdate: emitOrUpdate,
      onSsdpSocketReady: (socket) => ssdpSocket = socket,
      onMdnsClientReady: (client) => mdnsClient = client,
    ).then((_) {
      timeoutTimer = Timer(duration, () {
        stopScan();
      });
    }).catchError((error) {
      debugPrint('[TvDiscovery] Erreur pendant le scan : $error');
      stopScan();
    });

    return controller.stream;
  }

  Future<void> _startScanning({
    required void Function(DiscoveredTv tv) emitOrUpdate,
    required void Function(RawDatagramSocket socket) onSsdpSocketReady,
    required void Function(MDnsClient client) onMdnsClientReady,
  }) async {
    _isScanning = true;
    debugPrint('[TvDiscovery] Démarrage du scan local (durée 8s)...');
    await _acquireMulticastLock();

    // 1. Scan SSDP (UDP Multicast)
    _startSsdpScan(emitOrUpdate, onSsdpSocketReady);

    // 2. Scan mDNS
    _startMdnsScan(emitOrUpdate, onMdnsClientReady);
  }

  Future<void> _startSsdpScan(
    void Function(DiscoveredTv tv) emitOrUpdate,
    void Function(RawDatagramSocket socket) onSsdpSocketReady,
  ) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      onSsdpSocketReady(socket);
      socket.broadcastEnabled = true;
      socket.multicastLoopback = false;

      // Écoute des réponses SSDP
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final response = utf8.decode(datagram.data, allowMalformed: true);
            final senderIp = datagram.address.address;
            _parseSsdpResponse(response, senderIp, emitOrUpdate);
          }
        }
      });

      // Envoi des requêtes M-SEARCH pour chaque cible ST
      final multicastAddress = InternetAddress(_ssdpAddress);
      for (final st in _ssdpTargets) {
        final query =
            'M-SEARCH * HTTP/1.1\r\n'
            'HOST: $_ssdpAddress:$_ssdpPort\r\n'
            'MAN: "ssdp:discover"\r\n'
            'MX: 3\r\n'
            'ST: $st\r\n'
            '\r\n';
        final data = utf8.encode(query);
        socket.send(data, multicastAddress, _ssdpPort);
        debugPrint('[TvDiscovery][SSDP] Requête M-SEARCH envoyée pour ST: $st');
      }
    } catch (e) {
      debugPrint('[TvDiscovery][SSDP] Erreur initialisation socket SSDP : $e');
    }
  }

  void _parseSsdpResponse(
    String rawResponse,
    String senderIp,
    void Function(DiscoveredTv tv) emitOrUpdate,
  ) {
    debugPrint('[TvDiscovery][SSDP] Réponse brute reçue de $senderIp:\n$rawResponse');

    final lines = rawResponse.split('\r\n');
    final headers = <String, String>{};

    for (final line in lines) {
      final separatorIndex = line.indexOf(':');
      if (separatorIndex > 0) {
        final key = line.substring(0, separatorIndex).trim().toUpperCase();
        final value = line.substring(separatorIndex + 1).trim();
        headers[key] = value;
      }
    }

    final server = headers['SERVER'];
    final st = headers['ST'];
    final usn = headers['USN'];
    final location = headers['LOCATION'];

    var brand = _deduceBrand(
      server: server,
      st: st,
      usn: usn,
      location: location,
    );

    int? port;
    if (location != null) {
      try {
        final uri = Uri.parse(location);
        port = uri.port > 0 ? uri.port : null;
      } catch (_) {}
    }

    String defaultName = brand != TvBrand.unknown
        ? '${brand.displayName} TV'
        : 'Téléviseur';

    final initialTv = DiscoveredTv(
      name: defaultName,
      ip: senderIp,
      brand: brand,
      port: port,
      location: location,
      extraInfo: {
        if (server != null) 'SERVER': server,
        if (st != null) 'ST': st,
        if (usn != null) 'USN': usn,
      },
    );

    emitOrUpdate(initialTv);

    // Tentative de récupération du Friendly Name et de la marque via XML de description
    if (location != null && location.startsWith('http')) {
      _fetchXmlDescription(location, senderIp).then((xmlInfo) {
        if (xmlInfo != null) {
          final friendlyName = xmlInfo['friendlyName'];
          final manufacturer = xmlInfo['manufacturer'];
          final enrichedBrand = _deduceBrand(
            server: server,
            st: st,
            usn: usn,
            location: location,
            friendlyName: friendlyName,
            manufacturer: manufacturer,
          );

          emitOrUpdate(
            DiscoveredTv(
              name: friendlyName ?? defaultName,
              ip: senderIp,
              brand: enrichedBrand != TvBrand.unknown ? enrichedBrand : brand,
              port: port,
              location: location,
              extraInfo: {
                if (server != null) 'SERVER': server,
                if (manufacturer != null) 'Manufacturer': manufacturer,
              },
            ),
          );
        }
      });
    }
  }

  Future<Map<String, String>?> _fetchXmlDescription(
    String locationUrl,
    String ip,
  ) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(Uri.parse(locationUrl));
      final response =
          await request.close().timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final friendlyName = _extractXmlTag(content, 'friendlyName');
        final manufacturer = _extractXmlTag(content, 'manufacturer');
        debugPrint(
          '[TvDiscovery][UPnP XML] $ip -> friendlyName: "$friendlyName", manufacturer: "$manufacturer"',
        );
        return {
          if (friendlyName != null) 'friendlyName': friendlyName,
          if (manufacturer != null) 'manufacturer': manufacturer,
        };
      }
    } catch (e) {
      debugPrint('[TvDiscovery][UPnP XML] Échec récupération XML ($locationUrl) : $e');
    }
    return null;
  }

  String? _extractXmlTag(String xml, String tagName) {
    final regex = RegExp('<$tagName[^>]*>(.*?)</$tagName>', caseSensitive: false);
    final match = regex.firstMatch(xml);
    return match?.group(1)?.trim();
  }

  Future<void> _startMdnsScan(
    void Function(DiscoveredTv tv) emitOrUpdate,
    void Function(MDnsClient client) onMdnsClientReady,
  ) async {
    try {
      final mdns = MDnsClient();
      onMdnsClientReady(mdns);
      await mdns.start();

      for (final serviceName in _mdnsServices) {
        debugPrint('[TvDiscovery][mDNS] Recherche service: $serviceName');
        mdns
            .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(serviceName),
            )
            .listen((ptr) async {
          debugPrint('[TvDiscovery][mDNS] PTR trouvé : ${ptr.domainName}');
          final domain = ptr.domainName;

          // Recherche SRV pour connaître le port et la cible hôte
          await for (final srv in mdns.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(domain),
          )) {
            final target = srv.target;
            final port = srv.port;

            // Recherche IP pour la cible
            await for (final ip in mdns.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(target),
            )) {
              final ipAddress = ip.address.address;
              TvBrand brand = TvBrand.androidTv;
              if (domain.toLowerCase().contains('bravia')) {
                brand = TvBrand.sony;
              }

              // Lecture éventuelle des clés TXT (ex: fn = Friendly Name)
              String tvName = 'Android TV ($ipAddress)';
              try {
                await for (final txt in mdns.lookup<TxtResourceRecord>(
                  ResourceRecordQuery.text(domain),
                )) {
                  final textData = txt.text;
                  debugPrint('[TvDiscovery][mDNS TXT] $domain -> $textData');
                  for (final item in textData.split('\n')) {
                    if (item.toLowerCase().startsWith('fn=')) {
                      tvName = item.substring(3).trim();
                      break;
                    }
                  }
                }
              } catch (_) {}

              emitOrUpdate(
                DiscoveredTv(
                  name: tvName,
                  ip: ipAddress,
                  brand: brand,
                  port: port,
                  extraInfo: {'mDNS_service': serviceName, 'domain': domain},
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[TvDiscovery][mDNS] Erreur scan mDNS : $e');
    }
  }

  TvBrand _deduceBrand({
    String? server,
    String? st,
    String? usn,
    String? location,
    String? friendlyName,
    String? manufacturer,
  }) {
    final text = [
      server,
      st,
      usn,
      location,
      friendlyName,
      manufacturer,
    ].where((e) => e != null).join(' ').toLowerCase();

    if (text.contains('samsung') ||
        text.contains('tizen') ||
        text.contains('sec_hhp_') ||
        text.contains('samsung electronics')) {
      return TvBrand.samsung;
    }
    if (text.contains('webos') ||
        text.contains('netcast') ||
        text.contains('lg electronics') ||
        text.contains('lg_tv') ||
        text.contains('lgtv')) {
      return TvBrand.lg;
    }
    if (text.contains('bravia') || text.contains('sony')) {
      return TvBrand.sony;
    }
    if (text.contains('roku')) {
      return TvBrand.roku;
    }
    if (text.contains('androidtv') ||
        text.contains('android tv') ||
        text.contains('googlecast') ||
        text.contains('google cast') ||
        text.contains('chromecast')) {
      return TvBrand.androidTv;
    }
    return TvBrand.unknown;
  }
}
