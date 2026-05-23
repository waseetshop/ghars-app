class Garden {
  final String id;
  final String name;
  final String type;    // GARDEN | POT
  final String climate;

  // ── نظام السقي ────────────────────────────────────────────
  final String irrigationType;   // MANUAL | TIMER | SMART_TIMER
  final int?   timerDurationMin;
  final int?   timerTimesPerDay;
  final List<String> timerTimes;
  final int?   timerIntervalDays;

  const Garden({
    required this.id,
    required this.name,
    this.type             = 'GARDEN',
    required this.climate,
    this.irrigationType   = 'MANUAL',
    this.timerDurationMin,
    this.timerTimesPerDay,
    this.timerTimes       = const [],
    this.timerIntervalDays,
  });

  bool get isGarden     => type == 'GARDEN';
  bool get isPot        => type == 'POT';
  bool get hasTimer     => irrigationType == 'TIMER' || irrigationType == 'SMART_TIMER';
  bool get isSmartTimer => irrigationType == 'SMART_TIMER';

  /// أيقونة + تسمية النوع
  String get typeEmoji => isPot ? '🪴' : '🏡';
  String get typeLabel => isPot ? 'أصيص' : 'حديقة';

  factory Garden.fromJson(Map<String, dynamic> json) => Garden(
        id:               json['id']      as String,
        name:             json['name']    as String,
        type:             json['type']    as String?  ?? 'GARDEN',
        climate:          json['climate'] as String,
        irrigationType:   json['irrigationType']    as String?  ?? 'MANUAL',
        timerDurationMin: json['timerDurationMin']  as int?,
        timerTimesPerDay: json['timerTimesPerDay']  as int?,
        timerTimes:       (json['timerTimes']        as List?)
                              ?.map((e) => e as String)
                              .toList() ?? [],
        timerIntervalDays: json['timerIntervalDays'] as int?,
      );
}
