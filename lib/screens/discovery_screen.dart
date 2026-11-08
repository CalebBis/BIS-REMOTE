import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discovered_tv.dart';
import '../services/android_tv_pairing_service.dart';
import '../services/tv_discovery_provider.dart';
import '../services/tv_discovery_service.dart';

/// Écran de recherche automatique (SSDP / mDNS) et d'ajout manuel des téléviseurs sur le réseau local.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  /// Formate et nettoie le nom affiché d'un téléviseur :
  /// - Évite les doublons comme "Android TV TV" lorsque le nom ou la marque contient déjà "TV"
  /// - Conserve les noms lisibles non génériques (ex: "Mediatek_MTXXXX")
  /// - Si le nom reçu est générique (ex: "Android TV", "Téléviseur"), tente d'extraire un nom d'hôte ou d'instance mDNS plus parlant.
  static String formatTvName(DiscoveredTv tv) {
    String name = tv.name.trim();

    // 1. Élimine les doublons de "TV TV" (insensible à la casse)
    name = name.replaceAll(RegExp(r'\bTV\s+TV\b', caseSensitive: false), 'TV').trim();
    if (RegExp(r'TV\s+TV$', caseSensitive: false).hasMatch(name)) {
      name = name.replaceFirst(RegExp(r'\s+TV$', caseSensitive: false), '').trim();
    }

    // 2. Si le nom est générique ou égal au nom de marque, tente d'extraire un nom d'hôte / modèle
    final isGeneric = name == 'Android TV' ||
        name == 'Téléviseur' ||
        name == tv.brand.displayName ||
        name.startsWith('Android TV (');

    if (isGeneric && tv.extraInfo != null) {
      final domain = tv.extraInfo!['domain'];
      if (domain != null && domain.isNotEmpty) {
        // En mDNS, le format est <NomInstance>._service._tcp.local
        final firstPart = domain.split('._').first;
        final cleanInstance = firstPart.replaceAll(RegExp(r'\.local\.?$'), '').trim();
        if (cleanInstance.isNotEmpty &&
            !cleanInstance.startsWith('_') &&
            cleanInstance.toLowerCase() != 'android tv') {
          return cleanInstance;
        }
      }
      final manufacturer = tv.extraInfo!['Manufacturer'];
      if (manufacturer != null && manufacturer.isNotEmpty) {
        return '$manufacturer ${tv.brand.displayName}';
      }
    }

    return name;
  }

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final List<DiscoveredTv> _discoveredTvs = [];
  StreamSubscription<DiscoveredTv>? _scanSubscription;
  bool _isScanning = false;
  bool _hasScannedOnce = false;
  bool _isWifiActive = true;

  @override
  void initState() {
    super.initState();
    _checkWifiAndAutoScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkWifiAndAutoScan() async {
    final wifi = await TvDiscoveryService.isWifiConnected();
    if (!mounted) return;
    setState(() {
      _isWifiActive = wifi;
    });

    if (wifi) {
      _startScan();
    }
  }

  void _startScan() async {
    final wifi = await TvDiscoveryService.isWifiConnected();
    if (!mounted) return;
    if (!wifi) {
      setState(() {
        _isWifiActive = false;
        _isScanning = false;
      });
      return;
    }

    setState(() {
      _isWifiActive = true;
      _isScanning = true;
      _hasScannedOnce = true;
      _discoveredTvs.clear();
    });

    final discoveryService = ref.read(tvDiscoveryServiceProvider);
    _scanSubscription?.cancel();
    _scanSubscription = discoveryService.scanTvs().listen(
      (tv) {
        if (!mounted) return;
        setState(() {
          final index = _discoveredTvs.indexWhere((item) => item.ip == tv.ip);
          if (index >= 0) {
            _discoveredTvs[index] = tv;
          } else {
            _discoveredTvs.add(tv);
          }
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
        });
      },
    );
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  void _selectTv(DiscoveredTv tv) async {
    HapticFeedback.lightImpact();

    final formattedName = _formatTvName(tv);
    final tvToUse = formattedName != tv.name ? tv.copyWith(name: formattedName) : tv;

    if (tvToUse.brand == TvBrand.androidTv) {
      // Pour une Android TV : vérifier si déjà appairée
      final pairingService = ref.read(androidTvPairingServiceProvider);
      final isPaired = await pairingService.isTvPaired(tvToUse.ip);

      if (!mounted) return;

      ref.read(selectedTvProvider.notifier).selectTv(tvToUse);

      if (isPaired) {
        // Déjà appairée : tester le port 6466 pour le statut
        ref.read(androidTvConnectionStateProvider.notifier).set(
          AndroidTvConnectionState.paired,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tvToUse.name} sélectionnée (appairée)'),
            backgroundColor: const Color(0xFF00525A),
            duration: const Duration(seconds: 2),
          ),
        );
        // Test de connexion en arrière-plan
        pairingService.testRemotePortConnection(tvToUse.ip).then((state) {
          if (mounted) {
            ref.read(androidTvConnectionStateProvider.notifier).set(state);
          }
        });
        Navigator.of(context).pop();
      } else {
        // Pas encore appairée : ouvrir le dialogue d'appairage
        ref.read(androidTvConnectionStateProvider.notifier).set(
          AndroidTvConnectionState.unpaired,
        );
        await _openPairingDialog(tvToUse, pairingService);
      }
    } else {
      ref.read(selectedTvProvider.notifier).selectTv(tvToUse);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Téléviseur sélectionné : ${tvToUse.name}'),
          backgroundColor: const Color(0xFF00525A),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _openPairingDialog(DiscoveredTv tv, AndroidTvPairingService pairingService) async {
    final pinController = TextEditingController();
    PairingStepStatus status = PairingStepStatus.idle;
    String statusMessage = '';
    bool isPinPhase = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> startPairing() async {
              setDialogState(() {
                status = PairingStepStatus.connecting;
                statusMessage = 'Connexion à ${tv.ip}…';
              });
              try {
                await pairingService.startPairing(
                  host: tv.ip,
                  onStatusChanged: (s, msg) {
                    if (!ctx.mounted) return;
                    setDialogState(() {
                      status = s;
                      statusMessage = msg;
                      if (s == PairingStepStatus.waitingForPin) {
                        isPinPhase = true;
                      }
                    });
                  },
                );
              } catch (_) {}
            }

            Future<void> submitPin() async {
              final pin = pinController.text.trim().toUpperCase();
              final success = await pairingService.submitPin(
                host: tv.ip,
                pin: pin,
                onStatusChanged: (s, msg) {
                  if (!ctx.mounted) return;
                  setDialogState(() {
                    status = s;
                    statusMessage = msg;
                  });
                },
              );
              if (!ctx.mounted) return;
              if (success) {
                Navigator.of(ctx).pop(true);
              }
            }

            // Auto-démarrage lors de l'ouverture du dialogue
            if (status == PairingStepStatus.idle) {
              WidgetsBinding.instance.addPostFrameCallback((_) => startPairing());
            }

            final isLoading = status == PairingStepStatus.connecting ||
                status == PairingStepStatus.verifyingPin;

            return AlertDialog(
              backgroundColor: const Color(0xFF1B2223),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.live_tv_rounded, color: Color(0xFF00C8F0), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Appairage Android TV',
                      style: const TextStyle(
                        color: Color(0xFFE3E8E8),
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _formatTvName(tv),
                        style: const TextStyle(
                          color: Color(0xFF8E999A),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tv.ip,
                        style: const TextStyle(
                          color: Color(0xFF555F61),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Statut
                      if (statusMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _statusBgColor(status),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              if (isLoading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C8F0)),
                                  ),
                                )
                              else
                                Icon(_statusIcon(status), size: 16, color: _statusIconColor(status)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  statusMessage,
                                  style: TextStyle(
                                    color: _statusTextColor(status),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Champ PIN (uniquement en phase de saisie)
                      if (isPinPhase) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Code affiché sur votre TV (6 caractères hex)\nexemple : A3F2B1',
                          style: TextStyle(color: Color(0xFF8E999A), fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: pinController,
                          autofocus: true,
                          maxLength: 6,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            color: Color(0xFFE3E8E8),
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                          decoration: InputDecoration(
                            hintText: 'A3F2B1',
                            hintStyle: const TextStyle(
                              color: Color(0xFF555F61),
                              letterSpacing: 4,
                            ),
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFF262D2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            errorText: status == PairingStepStatus.invalidPin
                                ? statusMessage
                                : null,
                            errorMaxLines: 2,
                          ),
                          onSubmitted: (_) => submitPin(),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    pairingService.closePairing();
                    Navigator.of(ctx).pop(false);
                  },
                  child: const Text('Annuler', style: TextStyle(color: Color(0xFF8E999A))),
                ),
                if (isPinPhase && !isLoading)
                  ElevatedButton(
                    onPressed: submitPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C8F0),
                      foregroundColor: const Color(0xFF111418),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                if (status == PairingStepStatus.unreachable || status == PairingStepStatus.error)
                  ElevatedButton(
                    onPressed: startPairing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF262D2E),
                      foregroundColor: const Color(0xFFE3E8E8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Réessayer'),
                  ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result == true) {
      ref.read(androidTvConnectionStateProvider.notifier).set(
        AndroidTvConnectionState.paired,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_formatTvName(tv)} appairée avec succès !'),
          backgroundColor: const Color(0xFF00525A),
          duration: const Duration(seconds: 3),
        ),
      );
      // Test du port 6466 en arrière-plan
      pairingService.testRemotePortConnection(tv.ip).then((state) {
        if (mounted) {
          ref.read(androidTvConnectionStateProvider.notifier).set(state);
        }
      });
      Navigator.of(context).pop();
    }
  }

  static Color _statusBgColor(PairingStepStatus s) => switch (s) {
        PairingStepStatus.success => const Color(0xFF1A3A2F),
        PairingStepStatus.invalidPin ||
        PairingStepStatus.unreachable ||
        PairingStepStatus.error =>
          const Color(0xFF3A1A1A),
        _ => const Color(0xFF262D2E),
      };

  static IconData _statusIcon(PairingStepStatus s) => switch (s) {
        PairingStepStatus.success => Icons.check_circle_rounded,
        PairingStepStatus.invalidPin ||
        PairingStepStatus.unreachable ||
        PairingStepStatus.error =>
          Icons.error_outline_rounded,
        PairingStepStatus.waitingForPin => Icons.lock_outline_rounded,
        _ => Icons.info_outline_rounded,
      };

  static Color _statusIconColor(PairingStepStatus s) => switch (s) {
        PairingStepStatus.success => const Color(0xFF00C87A),
        PairingStepStatus.invalidPin ||
        PairingStepStatus.unreachable ||
        PairingStepStatus.error =>
          const Color(0xFFE53935),
        PairingStepStatus.waitingForPin => const Color(0xFF00C8F0),
        _ => const Color(0xFF8E999A),
      };

  static Color _statusTextColor(PairingStepStatus s) => switch (s) {
        PairingStepStatus.success => const Color(0xFF00C87A),
        PairingStepStatus.invalidPin ||
        PairingStepStatus.unreachable ||
        PairingStepStatus.error =>
          const Color(0xFFE57373),
        PairingStepStatus.waitingForPin => const Color(0xFF00C8F0),
        _ => const Color(0xFF8E999A),
      };

  static String _formatTvName(DiscoveredTv tv) => DiscoveryScreen.formatTvName(tv);

  void _openManualAddDialog() {
    final ipController = TextEditingController();
    final nameController = TextEditingController();
    TvBrand selectedBrand = TvBrand.samsung;
    String? ipError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool validateIp(String ip) {
              final parts = ip.trim().split('.');
              if (parts.length != 4) return false;
              for (final part in parts) {
                final n = int.tryParse(part);
                if (n == null || n < 0 || n > 255) return false;
              }
              return true;
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1B2223),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Ajouter par adresse IP',
                style: TextStyle(
                  color: Color(0xFFE3E8E8),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: ipController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFFE3E8E8)),
                      decoration: InputDecoration(
                        labelText: 'Adresse IP *',
                        hintText: '192.168.1.100',
                        errorText: ipError,
                        labelStyle: const TextStyle(color: Color(0xFF8E999A)),
                        hintStyle: const TextStyle(color: Color(0xFF555F61)),
                        filled: true,
                        fillColor: const Color(0xFF262D2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Color(0xFFE3E8E8)),
                      decoration: InputDecoration(
                        labelText: 'Nom du téléviseur (facultatif)',
                        hintText: 'ex: TV Salon',
                        labelStyle: const TextStyle(color: Color(0xFF8E999A)),
                        hintStyle: const TextStyle(color: Color(0xFF555F61)),
                        filled: true,
                        fillColor: const Color(0xFF262D2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<TvBrand>(
                      initialValue: selectedBrand,
                      dropdownColor: const Color(0xFF262D2E),
                      style: const TextStyle(color: Color(0xFFE3E8E8)),
                      decoration: InputDecoration(
                        labelText: 'Marque',
                        labelStyle: const TextStyle(color: Color(0xFF8E999A)),
                        filled: true,
                        fillColor: const Color(0xFF262D2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: TvBrand.samsung,
                          child: Text('Samsung'),
                        ),
                        DropdownMenuItem(
                          value: TvBrand.lg,
                          child: Text('LG'),
                        ),
                        DropdownMenuItem(
                          value: TvBrand.sony,
                          child: Text('Sony'),
                        ),
                        DropdownMenuItem(
                          value: TvBrand.androidTv,
                          child: Text('Android TV'),
                        ),
                        DropdownMenuItem(
                          value: TvBrand.roku,
                          child: Text('Roku'),
                        ),
                        DropdownMenuItem(
                          value: TvBrand.unknown,
                          child: Text('Autre / Inconnue'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedBrand = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: Color(0xFF8E999A)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final ip = ipController.text.trim();
                    if (!validateIp(ip)) {
                      setDialogState(() {
                        ipError = 'Format IP invalide (ex: 192.168.1.50)';
                      });
                      return;
                    }

                    final brandName = selectedBrand.displayName;
                    final defaultName = brandName.toLowerCase().contains('tv')
                        ? brandName
                        : '$brandName TV';

                    final name = nameController.text.trim().isNotEmpty
                        ? nameController.text.trim()
                        : (selectedBrand != TvBrand.unknown
                            ? defaultName
                            : 'Téléviseur');

                    final manualTv = DiscoveredTv(
                      name: name,
                      ip: ip,
                      brand: selectedBrand,
                    );

                    Navigator.of(dialogContext).pop();
                    _selectTv(manualTv);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C8F0),
                    foregroundColor: const Color(0xFF111418),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Sélectionner'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSelected = ref.watch(selectedTvProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111418),
        elevation: 0,
        title: const Text(
          'Recherche de téléviseurs',
          style: TextStyle(
            color: Color(0xFFE3E8E8),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFE3E8E8)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre de progression du scan
            if (_isScanning)
              const LinearProgressIndicator(
                backgroundColor: Color(0xFF1B2223),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C8F0)),
                minHeight: 3,
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Alerte Wi-Fi non connecté
                  if (!_isWifiActive)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262D2E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE53935), width: 1),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.wifi_off_rounded, color: Color(0xFFE53935), size: 32),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Wi-Fi non connecté',
                                  style: TextStyle(
                                    color: Color(0xFFE3E8E8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Connectez votre smartphone au réseau Wi-Fi de vos téléviseurs pour lancer la recherche.',
                                  style: TextStyle(
                                    color: Color(0xFF8E999A),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Boutons d'action : Scanner et Ajouter par IP
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isScanning ? _stopScan : _startScan,
                          icon: Icon(
                            _isScanning ? Icons.stop_rounded : Icons.search_rounded,
                            size: 20,
                          ),
                          label: Text(
                            _isScanning ? 'Arrêter le scan' : 'Scanner le réseau',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isScanning
                                ? const Color(0xFF262D2E)
                                : const Color(0xFF00C8F0),
                            foregroundColor: _isScanning
                                ? const Color(0xFFE3E8E8)
                                : const Color(0xFF111418),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _openManualAddDialog,
                        icon: const Icon(Icons.add_link_rounded, size: 20),
                        label: const Text('Par IP'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00C8F0),
                          side: const BorderSide(color: Color(0x6600C8F0), width: 1.5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Titre de section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Téléviseurs détectés (${_discoveredTvs.length})',
                        style: const TextStyle(
                          color: Color(0xFF8E999A),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (_isScanning)
                        const Text(
                          'Scan en cours (8s)...',
                          style: TextStyle(
                            color: Color(0xFF00C8F0),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // État vide (aucun téléviseur trouvé après scan)
                  if (!_isScanning && _discoveredTvs.isEmpty && _hasScannedOnce)
                    Container(
                      padding: const EdgeInsets.all(28),
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2223),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.tv_off_rounded,
                            size: 48,
                            color: Color(0xFF555F61),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Aucun téléviseur détecté',
                            style: TextStyle(
                              color: Color(0xFFE3E8E8),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Vérifiez que votre TV est allumée et connectée au même réseau Wi-Fi. Vous pouvez également l\'ajouter avec le bouton "Par IP".',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF8E999A),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Liste des téléviseurs découverts
                  for (final tv in _discoveredTvs)
                    _DiscoveredTvTile(
                      tv: tv,
                      isSelected: currentSelected?.ip == tv.ip,
                      onTap: () => _selectTv(tv),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveredTvTile extends StatelessWidget {
  const _DiscoveredTvTile({
    required this.tv,
    required this.isSelected,
    required this.onTap,
  });

  final DiscoveredTv tv;
  final bool isSelected;
  final VoidCallback onTap;

  IconData _getBrandIcon(TvBrand brand) {
    switch (brand) {
      case TvBrand.samsung:
      case TvBrand.lg:
      case TvBrand.sony:
        return Icons.tv_rounded;
      case TvBrand.androidTv:
        return Icons.live_tv_rounded;
      case TvBrand.roku:
        return Icons.smart_display_rounded;
      case TvBrand.unknown:
        return Icons.devices_other_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2223),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF00C8F0) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF262D2E),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: const Color(0xFF00C8F0), width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    _getBrandIcon(tv.brand),
                    color: isSelected
                        ? const Color(0xFF00C8F0)
                        : const Color(0xFFE3E8E8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DiscoveryScreen.formatTvName(tv),
                        style: const TextStyle(
                          color: Color(0xFFE3E8E8),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            tv.ip,
                            style: const TextStyle(
                              color: Color(0xFF8E999A),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF262D2E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tv.brand.displayName,
                              style: const TextStyle(
                                color: Color(0xFF7FD6DC),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: isSelected
                      ? const Color(0xFF00C8F0)
                      : const Color(0xFF555F61),
                  size: isSelected ? 24 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
