/// Marques de téléviseurs reconnues lors de la détection réseau.
enum TvBrand {
  samsung,
  lg,
  sony,
  androidTv,
  roku,
  unknown;

  /// Libellé d'affichage de la marque.
  String get displayName {
    switch (this) {
      case TvBrand.samsung:
        return 'Samsung';
      case TvBrand.lg:
        return 'LG';
      case TvBrand.sony:
        return 'Sony';
      case TvBrand.androidTv:
        return 'Android TV';
      case TvBrand.roku:
        return 'Roku';
      case TvBrand.unknown:
        return 'Inconnue';
    }
  }
}

/// Modèle représentant un téléviseur détecté sur le réseau local ou ajouté manuellement.
class DiscoveredTv {
  const DiscoveredTv({
    required this.name,
    required this.ip,
    required this.brand,
    this.port,
    this.location,
    this.extraInfo,
  });

  /// Nom convivial du téléviseur (ex: "Samsung QLED Salon" ou "Android TV").
  final String name;

  /// Adresse IPv4 du téléviseur sur le réseau local.
  final String ip;

  /// Marque identifiée ou "Inconnue".
  final TvBrand brand;

  /// Port de service identifié (si disponible).
  final int? port;

  /// URL du descripteur SSDP / UPnP XML (le cas échéant).
  final String? location;

  /// Informations additionnelles (en-têtes HTTP, clés TXT mDNS, etc.).
  final Map<String, String>? extraInfo;

  /// Crée une copie enrichie avec de nouveaux champs.
  DiscoveredTv copyWith({
    String? name,
    String? ip,
    TvBrand? brand,
    int? port,
    String? location,
    Map<String, String>? extraInfo,
  }) {
    return DiscoveredTv(
      name: name ?? this.name,
      ip: ip ?? this.ip,
      brand: brand ?? this.brand,
      port: port ?? this.port,
      location: location ?? this.location,
      extraInfo: extraInfo ?? this.extraInfo,
    );
  }

  /// Résumé affiché dans le bandeau principal.
  String get summary => '$name ($ip)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredTv && runtimeType == other.runtimeType && ip == other.ip;

  @override
  int get hashCode => ip.hashCode;

  @override
  String toString() => 'DiscoveredTv(name: $name, ip: $ip, brand: ${brand.displayName}, port: $port)';
}
