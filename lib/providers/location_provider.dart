import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kLocationDoneKey    = 'location_done';
const kLocationClimateKey = 'location_climate';
const kLocationLabelKey   = 'location_label';
const kLocationLatKey     = 'location_lat';
const kLocationLonKey     = 'location_lon';

// ── نموذج بيانات الموقع ───────────────────────────────────────
class LocationData {
  final String climate;  // HOT_ARID | MEDITERRANEAN | TROPICAL | TEMPERATE
  final String label;    // اسم المدينة أو "موقعك الحالي"
  final double? lat;
  final double? lon;

  const LocationData({
    required this.climate,
    required this.label,
    this.lat,
    this.lon,
  });

  static const _climateLabels = {
    'HOT_ARID':      'حار جاف',
    'MEDITERRANEAN': 'متوسطي',
    'TROPICAL':      'استوائي',
    'TEMPERATE':     'معتدل',
  };

  static const _climateEmojis = {
    'HOT_ARID':      '☀️',
    'MEDITERRANEAN': '🌊',
    'TROPICAL':      '🌴',
    'TEMPERATE':     '🌤️',
  };

  String get climateLabel => _climateLabels[climate] ?? climate;
  String get climateEmoji => _climateEmojis[climate] ?? '🌡️';
}

// ── Provider يقرأ من SharedPreferences ────────────────────────
final locationDataProvider = FutureProvider<LocationData?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final done  = prefs.getBool(kLocationDoneKey) ?? false;
  if (!done) return null;

  return LocationData(
    climate: prefs.getString(kLocationClimateKey) ?? 'HOT_ARID',
    label:   prefs.getString(kLocationLabelKey)   ?? 'موقعك الحالي',
    lat:     prefs.getDouble(kLocationLatKey),
    lon:     prefs.getDouble(kLocationLonKey),
  );
});

// ── تحديد المناخ من الإحداثيات (تقريبي لشبه الجزيرة العربية) ─
String climateFromCoords(double lat, double lon) {
  // المرتفعات: عسير، جازان الجبلية
  if (lat >= 17 && lat <= 21 && lon >= 42 && lon <= 44) return 'TEMPERATE';
  // الشمال الغربي: تبوك، حائل
  if (lat >= 27 && lon <= 44) return 'TEMPERATE';
  // ساحل البحر الأحمر الجنوبي: جدة، مكة (ساحلي رطب)
  if (lon >= 38 && lon <= 40.5 && lat >= 19 && lat <= 23) return 'TROPICAL';
  // ساحل الخليج الفعلي: الدمام، الخبر، الجبيل (lon > 49.8 = ساحلي فعلاً)
  // الأحساء والهفوف داخلية (lon ~49.6) → تبقى حار جاف
  if (lon >= 49.8 && lat >= 24 && lat <= 28) return 'TROPICAL';
  // شمال غرب: قريبة من البحر الأبيض المتوسط
  if (lat >= 30 && lon <= 36) return 'MEDITERRANEAN';
  // باقي المنطقة (بما فيها الأحساء الداخلية): حار جاف
  return 'HOT_ARID';
}

// ── اسم المدينة من الإحداثيات ────────────────────────────────
String cityFromCoords(double lat, double lon) {
  const cities = [
    // نجد والوسط
    (24.688, 46.722, 'الرياض'),
    (24.069, 47.576, 'الخرج'),
    (26.326, 43.975, 'بريدة'),
    (26.084, 44.993, 'عنيزة'),
    (28.394, 45.962, 'حفر الباطن'),
    // الحجاز
    (21.543, 39.172, 'جدة'),
    (24.469, 39.614, 'المدينة المنورة'),
    (21.389, 39.857, 'مكة المكرمة'),
    (21.270, 40.415, 'الطائف'),
    // الجنوب والسراة
    (18.216, 42.505, 'أبها'),
    (17.572, 44.177, 'جازان'),
    (20.289, 41.685, 'بيشة'),
    (19.992, 41.459, 'النماص'),
    // الشمال
    (28.396, 36.478, 'تبوك'),
    (27.522, 41.722, 'حائل'),
    (29.974, 40.205, 'العُلا'),
    (30.981, 41.083, 'سكاكا'),
    // الشرقية — الساحل الفعلي
    (26.392, 50.088, 'الدمام'),
    (26.217, 50.197, 'الخبر'),
    (26.957, 49.620, 'الجبيل'),
    (27.011, 49.659, 'القطيف'),
    // الشرقية — داخلية
    (25.383, 49.586, 'الهفوف - الأحساء'),
    (25.028, 49.080, 'الأحساء'),
    (24.556, 48.783, 'حرض'),
  ];

  double minDist = double.infinity;
  String closest = 'موقعك الحالي';

  for (final (clat, clon, name) in cities) {
    final dist = (lat - clat).abs() + (lon - clon).abs();
    if (dist < minDist) {
      minDist = dist;
      closest = name;
    }
  }
  // فقط إذا كانت المسافة أقل من ~270كم (2.5 درجة)
  return minDist < 2.5 ? closest : 'موقعك الحالي';
}

// ── حفظ بيانات الموقع ────────────────────────────────────────
Future<void> saveLocation({
  required String climate,
  required String label,
  double? lat,
  double? lon,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kLocationDoneKey, true);
  await prefs.setString(kLocationClimateKey, climate);
  await prefs.setString(kLocationLabelKey, label);
  if (lat != null) await prefs.setDouble(kLocationLatKey, lat);
  if (lon != null) await prefs.setDouble(kLocationLonKey, lon);
}
