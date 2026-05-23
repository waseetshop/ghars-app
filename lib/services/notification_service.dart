import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../core/colors.dart';
import '../models/plant.dart';

/// Service for scheduling and cancelling local watering reminders.
/// All public methods are safe to call multiple times.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Android notification channel ────────────────────────────
  static const _channelId    = 'ghars_watering';
  static const _channelName  = 'تذكيرات الري';
  static const _channelDesc  = 'إشعارات مواعيد ري النباتات في تطبيق غَرْس';

  // ── Init ────────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database and set device local zone
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fallback: leave as UTC — notifications will still fire
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    // Request runtime notification permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ── Derive a stable int ID from the plant's string ID ───────
  static int _notifId(String plantId) =>
      plantId.hashCode.abs() & 0x7FFFFFFF;

  // ── Schedule a single watering reminder ────────────────────
  static Future<void> scheduleWatering(Plant plant) async {
    if (!_initialized) return;
    final due = plant.nextWatering;
    if (due == null) return;

    // Don't schedule reminders in the past
    final now = DateTime.now();
    if (due.isBefore(now)) return;

    final notifId = _notifId(plant.id);
    final name    = plant.displayName;

    // Notify 15 minutes before the due time, or at due time if < 15 min away
    final alertAt = due.subtract(const Duration(minutes: 15));
    final target  = alertAt.isBefore(now) ? due : alertAt;

    await _plugin.zonedSchedule(
      id:               notifId,
      scheduledDate:    tz.TZDateTime.from(target, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance:         Importance.high,
          priority:           Priority.high,
          color:              GharsColors.green,
          enableVibration:    true,
          styleInformation: BigTextStyleInformation(
            'نبتتك "$name" تحتاج إلى الري الآن. لا تتأخر، الماء حياة! 💧🌿',
            contentTitle: '💧 وقت الري — $name',
          ),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: '💧 وقت الري',
      body:  '"$name" تحتاج إلى الري الآن 🌿',
    );
  }

  // ── Schedule reminders for a list of plants ─────────────────
  static Future<void> scheduleAll(List<Plant> plants) async {
    for (final plant in plants) {
      await scheduleWatering(plant);
    }
  }

  // ── Cancel the reminder for a specific plant ─────────────────
  static Future<void> cancelForPlant(String plantId) async {
    await _plugin.cancel(id: _notifId(plantId));
  }

  // ── Cancel all reminders ─────────────────────────────────────
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Show an immediate overdue alert ──────────────────────────
  static Future<void> showOverdueAlert(Plant plant) async {
    if (!_initialized) return;
    final name = plant.displayName;
    await _plugin.show(
      id:    _notifId('overdue_${plant.id}'),
      title: '⚠️ ري متأخر!',
      body:  '"$name" لم تُسقَ منذ فترة — تحقّق منها الآن',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority:   Priority.high,
          color:      GharsColors.diseased,
        ),
      ),
    );
  }
}
