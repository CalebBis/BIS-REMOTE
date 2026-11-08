import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discovered_tv.dart';
import '../services/tv_discovery_provider.dart';
import '../services/tv_discovery_service.dart';

/// Écran de recherche automatique (SSDP / mDNS) et d'ajout manuel des téléviseurs sur le réseau local.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

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

  void _selectTv(DiscoveredTv tv) {
    HapticFeedback.lightImpact();
    ref.read(selectedTvProvider.notifier).selectTv(tv);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Téléviseur sélectionné : ${tv.name}'),
        backgroundColor: const Color(0xFF00525A),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

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

                    final name = nameController.text.trim().isNotEmpty
                        ? nameController.text.trim()
                        : (selectedBrand != TvBrand.unknown
                            ? '${selectedBrand.displayName} TV'
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
                        tv.name,
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
