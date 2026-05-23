import 'catalog_item.dart';

class Plant {
  final String id;
  final String gardenId;
  final String? nickname;
  final String catalogNameAr;
  final String catalogCategory;
  final String healthStatus;
  final String location;
  final DateTime? nextWatering;
  final DateTime? lastWatered;          // آخر ري
  final int? wateringIntervalDays;      // الفترة الحالية بالأيام
  final bool isManualOverride;          // هل الضبط يدوي؟
  final CatalogItem? catalogDetails;

  const Plant({
    required this.id,
    required this.gardenId,
    this.nickname,
    required this.catalogNameAr,
    required this.catalogCategory,
    required this.healthStatus,
    required this.location,
    this.nextWatering,
    this.lastWatered,
    this.wateringIntervalDays,
    this.isManualOverride = false,
    this.catalogDetails,
  });

  String get displayName => nickname ?? catalogNameAr;

  factory Plant.fromJson(Map<String, dynamic> json) {
    final catalog   = json['PlantCatalog'] as Map<String, dynamic>?;
    final schedules = json['Schedule'] as List<dynamic>?;

    DateTime? nextWatering;
    DateTime? lastWatered;
    int?      wateringIntervalDays;
    bool      isManualOverride = false;
    if (schedules != null) {
      for (final s in schedules) {
        final m = s as Map<String, dynamic>;
        if (m['type'] == 'WATERING' && m['isActive'] == true) {
          final rawNext = m['nextDueAt']        as String?;
          final rawLast = m['lastCompletedAt']  as String?;
          if (rawNext != null) nextWatering = DateTime.tryParse(rawNext);
          if (rawLast != null) lastWatered  = DateTime.tryParse(rawLast);
          wateringIntervalDays = m['adjustedIntervalDays'] as int?;
          isManualOverride     = m['isManualOverride'] as bool? ?? false;
          break;
        }
      }
    }

    CatalogItem? catalogDetails;
    if (catalog != null) {
      try {
        catalogDetails = CatalogItem.fromJson(catalog);
      } catch (_) {
        // catalog fields might be partial — ignore
      }
    }

    return Plant(
      id:                   json['id'] as String,
      gardenId:             json['gardenId'] as String,
      nickname:             json['nickname'] as String?,
      catalogNameAr:        catalog?['nameAr'] as String? ?? '',
      catalogCategory:      catalog?['category'] as String? ?? 'ORNAMENTAL',
      healthStatus:         json['healthStatus'] as String? ?? 'HEALTHY',
      location:             json['location'] as String? ?? 'OUTDOOR',
      nextWatering:         nextWatering,
      lastWatered:          lastWatered,
      wateringIntervalDays: wateringIntervalDays,
      isManualOverride:     isManualOverride,
      catalogDetails:       catalogDetails,
    );
  }
}
