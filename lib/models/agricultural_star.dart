class AgriculturalStar {
  final int    id;
  final String nameAr;
  final String season;
  final int    seasonOrder;
  final int    startMonth;
  final int    startDay;
  final int    durationDays;
  final int    orderInYear;
  final String weatherDescription;
  final String plantingAdvice;
  final String? generalAdvice;
  final int    daysRemaining;
  final int    daysIntoStar;

  const AgriculturalStar({
    required this.id,
    required this.nameAr,
    required this.season,
    required this.seasonOrder,
    required this.startMonth,
    required this.startDay,
    required this.durationDays,
    required this.orderInYear,
    required this.weatherDescription,
    required this.plantingAdvice,
    this.generalAdvice,
    required this.daysRemaining,
    required this.daysIntoStar,
  });

  factory AgriculturalStar.fromJson(Map<String, dynamic> json) =>
      AgriculturalStar(
        id:                 json['id']           as int,
        nameAr:             json['nameAr']        as String,
        season:             json['season']        as String,
        seasonOrder:        json['seasonOrder']   as int,
        startMonth:         json['startMonth']    as int,
        startDay:           json['startDay']      as int,
        durationDays:       json['durationDays']  as int,
        orderInYear:        json['orderInYear']   as int,
        weatherDescription: json['weatherDescription'] as String,
        plantingAdvice:     json['plantingAdvice']     as String,
        generalAdvice:      json['generalAdvice']      as String?,
        daysRemaining:      json['daysRemaining'] as int,
        daysIntoStar:       json['daysIntoStar']  as int,
      );

  /// رمز الفصل
  String get seasonEmoji => switch (seasonOrder) {
    1 => '❄️',
    2 => '🌸',
    3 => '☀️',
    4 => '🍂',
    _ => '🌟',
  };
}
