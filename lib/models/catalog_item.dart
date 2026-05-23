class CatalogItem {
  final String id;
  final String nameAr;
  final String nameEn;
  final String? nameLatin;
  final String category;
  final int wateringCycleSummer;
  final int wateringCycleWinter;
  final int lightMin;
  final int lightMax;
  final String? lightDescription;
  final String saltSensitivity;
  final double soilPHMin;
  final double soilPHMax;

  const CatalogItem({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.nameLatin,
    required this.category,
    required this.wateringCycleSummer,
    required this.wateringCycleWinter,
    required this.lightMin,
    required this.lightMax,
    this.lightDescription,
    required this.saltSensitivity,
    required this.soilPHMin,
    required this.soilPHMax,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
        id:                   json['id'] as String,
        nameAr:               json['nameAr'] as String,
        nameEn:               json['nameEn'] as String,
        nameLatin:            json['nameLatin'] as String?,
        category:             json['category'] as String,
        wateringCycleSummer:  json['wateringCycleSummer'] as int? ?? 3,
        wateringCycleWinter:  json['wateringCycleWinter'] as int? ?? 7,
        lightMin:             json['lightMin'] as int? ?? 2000,
        lightMax:             json['lightMax'] as int? ?? 10000,
        lightDescription:     json['lightDescription'] as String?,
        saltSensitivity:      json['saltSensitivity'] as String? ?? 'MEDIUM',
        soilPHMin:            (json['soilPH_min'] as num?)?.toDouble() ?? 6.0,
        soilPHMax:            (json['soilPH_max'] as num?)?.toDouble() ?? 7.0,
      );
}
