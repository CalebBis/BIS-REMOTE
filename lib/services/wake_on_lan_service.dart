import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service gérant la création et l'émission de paquets magiques Wake-on-LAN (WoL).
class WakeOnLanService {
  const WakeOnLanService();

  /// Ports de diffusion standards pour le Wake-on-LAN.
  static const List<int> defaultPorts = [9, 7];

  /// Nombre de salves émises.
  static const int defaultBursts = 3;

  /// Intervalle entre chaque salve.
  static const Duration burstInterval = Duration(milliseconds: 300);

  /// Valide la syntaxe d'une adresse MAC (6 groupes hexadécimaux séparés par : ou -).
  static bool isValidMac(String mac) {
    final cleaned = mac.trim();
    final regExp = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
    return regExp.hasMatch(cleaned);
  }

  /// Normalise l'adresse MAC en majuscules avec ':' comme séparateur (ex: A1:B2:C3:D4:E5:F6).
  static String? normalizeMac(String mac) {
    if (!isValidMac(mac)) return null;
    final parts = mac.trim().replaceAll('-', ':').split(':');
    return parts.map((p) => p.toUpperCase().padLeft(2, '0')).join(':');
  }

  /// Masque partiellement l'adresse MAC pour les logs (ex : A1:B2:**:**:**:F6).
  static String maskMac(String mac) {
    final parts = mac.trim().replaceAll('-', ':').split(':');
    if (parts.length != 6) return '**:**:**:**:**:**';
    return '${parts[0].toUpperCase()}:${parts[1].toUpperCase()}:**:**:**:${parts[5].toUpperCase()}';
  }

  /// Construit la trame binaire de 102 octets du paquet magique Wake-on-LAN :
  /// 6 octets 0xFF suivis de 16 répétitions des 6 octets de l'adresse MAC.
  static Uint8List buildMagicPacket(String mac) {
    final normalized = normalizeMac(mac);
    if (normalized == null) {
      throw ArgumentError('Adresse MAC invalide : $mac');
    }

    final macBytes = normalized
        .split(':')
        .map((hex) => int.parse(hex, radix: 16))
        .toList();

    final packet = Uint8List(102);
    // 6 octets à 0xFF
    for (int i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }
    // 16 répétitions de l'adresse MAC
    for (int i = 0; i < 16; i++) {
      packet.setRange(6 + i * 6, 6 + (i + 1) * 6, macBytes);
    }
    return packet;
  }

  /// Déduit les adresses de diffusion (broadcast) locales du téléphone :
  /// Sous-réseau /24 déduit de chaque IP locale non loopback + adresse globale 255.255.255.255.
  static Future<List<InternetAddress>> getBroadcastAddresses() async {
    final addresses = <InternetAddress>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ipParts = addr.address.split('.');
          if (ipParts.length == 4) {
            final broadcastIp = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}.255';
            final bAddr = InternetAddress.tryParse(broadcastIp);
            if (bAddr != null && !addresses.any((a) => a.address == broadcastIp)) {
              addresses.add(bAddr);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[WakeOnLan] Erreur lors de la détection des interfaces : $e');
    }

    // Ajoute systématiquement l'adresse de diffusion globale
    final globalBroadcast = InternetAddress.tryParse('255.255.255.255');
    if (globalBroadcast != null && !addresses.any((a) => a.address == '255.255.255.255')) {
      addresses.add(globalBroadcast);
    }

    return addresses;
  }

  /// Envoie le paquet magique Wake-on-LAN en UDP broadcast sur les ports 9 et 7
  /// en 3 salves espacées de 300 ms.
  Future<bool> wakeTv(String macAddress) async {
    final normalized = normalizeMac(macAddress);
    if (normalized == null) {
      debugPrint('[WakeOnLan] Adresse MAC invalide, réveil annulé.');
      return false;
    }

    final masked = maskMac(normalized);
    final Uint8List packet;
    try {
      packet = buildMagicPacket(normalized);
    } catch (e) {
      debugPrint('[WakeOnLan] Erreur construction paquet magique : $e');
      return false;
    }

    final targets = await getBroadcastAddresses();
    final targetIps = targets.map((a) => a.address).join(', ');
    const ports = defaultPorts;
    const bursts = defaultBursts;

    debugPrint('[WakeOnLan] Envoi de paquets magiques vers $masked...');
    debugPrint(
      '[WakeOnLan] Adresses de diffusion : [$targetIps] | Ports : ${ports.join(', ')} | Salves : $bursts',
    );

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      for (int burst = 1; burst <= bursts; burst++) {
        for (final target in targets) {
          for (final port in ports) {
            try {
              socket.send(packet, target, port);
            } catch (err) {
              debugPrint('[WakeOnLan] Erreur envoi UDP vers ${target.address}:$port : $err');
            }
          }
        }
        if (burst < bursts) {
          await Future.delayed(burstInterval);
        }
      }
      debugPrint('[WakeOnLan] 3 salves envoyées avec succès.');
      return true;
    } catch (e) {
      debugPrint('[WakeOnLan] Erreur socket Wake-on-LAN : $e');
      return false;
    } finally {
      try {
        socket?.close();
      } catch (_) {}
    }
  }
}

/// Fournisseur Riverpod pour l'instance de WakeOnLanService.
final wakeOnLanServiceProvider = Provider<WakeOnLanService>((ref) {
  return const WakeOnLanService();
});

