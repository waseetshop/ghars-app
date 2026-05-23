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

  // ── خصائص الأصيص ─────────────────────────────────────────
  /// مادة الأصيص: PLASTIC | TERRACOTTA | CERAMIC | METAL | WOOD | FABRIC | CONCRETE | OTHER
  final String? potMaterial;
  /// حجم الأصيص بالليتر
  final double? potSizeL;

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
    this.potMaterial,
    this.potSizeL,
  });

  bool get isGarden     => type == 'GARDEN';
  bool get isPot        => type == 'POT';
  bool get hasTimer     => irrigationType == 'TIMER' || irrigationType == 'SMART_TIMER';
  bool get isSmartTimer => irrigationType == 'SMART_TIMER';

  /// أيقونة + تسمية النوع
  String get typeEmoji => isPot ? '🪴' : '🏡';
  String get typeLabel => isPot ? 'أصيص' : 'حديقة';

  /// مضاعف السقي بناءً على مسامية مادة الأصيص
  double get wateringMultiplier {
    if (!isPot) return 1.0;
    const m = {
      'TERRACOTTA': 1.35,
      'WOOD':       1.25,
      'FABRIC':     1.40,
      'PLASTIC':    0.85,
      'CERAMIC':    0.85,
      'METAL':      0.85,
      'CONCRETE':   0.90,
      'OTHER':      1.00,
    };
    return m[potMaterial] ?? 1.0;
  }

  /// تسمية المادة بالعربية
  static const materialLabels = {
    'PLASTIC':    'بلاستيك',
    'TERRACOTTA': 'فخار',
    'CERAMIC':    'سيراميك',
    'METAL':      'معدن',
    'WOOD':       'خشب',
    'FABRIC':     'كيس زراعي',
    'CONCRETE':   'إسمنت',
    'OTHER':      'أخرى',
  };

  static const materialEmojis = {
    'PLASTIC':    '🪣',
    'TERRACOTTA': '🏺',
    'CERAMIC':    '🫙',
    'METAL':      '🥫',
    'WOOD':       '🪵',
    'FABRIC':     '🎒',
    'CONCRETE':   '🧱',
    'OTHER':      '🪴',
  };

  String get potMaterialLabel => materialLabels[potMaterial] ?? '';
  String get potMaterialEmoji => materialEmojis[potMaterial] ?? '🪴';

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
        potMaterial:      json['potMaterial'] as String?,
        potSizeL:         (json['potSizeL'] as num?)?.toDouble(),
      );
}
