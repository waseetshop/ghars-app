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
  // المرتفعات: عسير، جازان
  if (lat >= 17 && lat <= 21 && lon >= 42 && lon <= 44) return 'TEMPERATE';
  // الشمال الغربي: تبوك، حائل
  if (lat >= 27 && lon <= 44) return 'TEMPERATE';
  // ساحل البحر الأحمر الجنوبي: جدة، مكة
  if (lon >= 38 && lon <= 40.5 && lat >= 19 && lat <= 23) return 'TROPICAL';
  // ساحل الخليج: الدمام، الجبيل
  if (lon >= 49 && lat >= 25 && lat <= 28) return 'TROPICAL';
  // شمال غرب: أقرب من البحر الأبيض المتوسط
  if (lat >= 30 && lon <= 36) return 'MEDITERRANEAN';
  // باقي المنطقة: حار جاف
  return 'HOT_ARID';
}

// ── اسم المدينة من الإحداثيات ────────────────────────────────
String cityFromCoords(double lat, double lon) {
  const cities = [
    (24.688, 46.722, 'الرياض'),
    (21.543, 39.172, 'جدة'),
    (24.469, 39.614, 'المدينة المنورة'),
    (21.389, 39.857, 'مكة المكرمة'),
    (26.392, 50.088, 'الدمام'),
    (18.216, 42.505, 'أبها'),
    (28.396, 36.478, 'تبوك'),
    (21.270, 40.415, 'الطائف'),
    (25.354, 49.588, 'الخبر'),
    (20.289, 41.685, 'بيشة'),
    (27.522, 41.722, 'حائل'),
    (17.572, 44.177, 'جازان'),
    (24.069, 47.576, 'الخرج'),
    (29.974, 40.205, 'العُلا'),
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
  // فقط إذا كانت المسافة أقل من ~150كم
  return minDist < 1.5 ? closest : 'موقعك الحالي';
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
