import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/garden.dart';
import '../models/plant.dart';
import '../models/catalog_item.dart';
import '../models/health_log.dart';
import '../models/today_task.dart';

SupabaseClient get _db => Supabase.instance.client;

/// معرّف المستخدم الحالي
String get _userId {
  final id = _db.auth.currentUser?.id;
  if (id == null) throw Exception('المستخدم غير مسجّل الدخول');
  return id;
}

// ── Gardens list ──────────────────────────────────────────────
final gardensProvider = FutureProvider<List<Garden>>((ref) async {
  final rows = await _db
      .from('Garden')
      .select(
        'id, name, type, climate, irrigationType, '
        'timerDurationMin, timerTimesPerDay, timerTimes, timerIntervalDays, '
        'potMaterial, potSizeL',
      )
      .eq('userId', _userId)
      .order('createdAt');
  return (rows as List)
      .map((r) => Garden.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Single garden detail ──────────────────────────────────────
final gardenProvider =
    FutureProvider.family<Garden, String>((ref, gardenId) async {
  final row = await _db
      .from('Garden')
      .select(
        'id, name, type, climate, irrigationType, '
        'timerDurationMin, timerTimesPerDay, timerTimes, timerIntervalDays, '
        'potMaterial, potSizeL',
      )
      .eq('id', gardenId)
      .single();
  return Garden.fromJson(row);
});

// ── Plant count per garden (for home screen card) ─────────────
final gardenPlantCountProvider =
    FutureProvider.family<int, String>((ref, gardenId) async {
  final rows = await _db
      .from('Plant')
      .select('id')
      .eq('gardenId', gardenId);
  return (rows as List).length;
});

// ── Plant Catalog ─────────────────────────────────────────────
final catalogProvider = FutureProvider<List<CatalogItem>>((ref) async {
  final rows = await _db
      .from('PlantCatalog')
      .select('id, nameAr, nameEn, nameLatin, category, wateringCycleSummer, wateringCycleWinter, lightMin, lightMax, lightDescription, saltSensitivity, soilPH_min, soilPH_max')
      .order('nameAr');
  return (rows as List)
      .map((r) => CatalogItem.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Health logs for a plant ───────────────────────────────────
final healthLogsProvider =
    FutureProvider.family<List<HealthLog>, String>((ref, plantId) async {
  final rows = await _db
      .from('HealthLog')
      .select('id, diagnosis, diagnosisCategory, treatment, severity, resolvedAt, createdAt')
      .eq('plantId', plantId)
      .order('createdAt', ascending: false)
      .limit(20);
  return (rows as List)
      .map((r) => HealthLog.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Today tasks: plants due within 24h across all gardens ─────
final todayTasksProvider = FutureProvider<List<TodayTask>>((ref) async {
  final gardens = await ref.watch(gardensProvider.future);
  final now     = DateTime.now();
  final cutoff  = now.add(const Duration(hours: 24));

  final tasks = <TodayTask>[];
  for (final garden in gardens) {
    try {
      final plants = await ref.watch(plantsProvider(garden.id).future);
      for (final plant in plants) {
        final due = plant.nextWatering;
        if (due != null && due.isBefore(cutoff)) {
          tasks.add(TodayTask(
            plant:      plant,
            gardenId:   garden.id,
            gardenName: garden.name,
          ));
        }
      }
    } catch (_) {
      // تجاهل الحدائق التي تفشل في التحميل
    }
  }

  // متأخر أولاً، ثم ترتيب زمني
  tasks.sort((a, b) =>
      a.plant.nextWatering!.compareTo(b.plant.nextWatering!));
  return tasks;
});

// ── Plants in a garden ────────────────────────────────────────
final plantsProvider =
    FutureProvider.family<List<Plant>, String>((ref, gardenId) async {
  final rows = await _db.from('Plant').select(
    'id, nickname, healthStatus, location, gardenId, '
    'PlantCatalog(id, nameAr, nameEn, nameLatin, category, '
    'wateringCycleSummer, wateringCycleWinter, '
    'lightMin, lightMax, lightDescription, '
    'saltSensitivity, soilPH_min, soilPH_max), '
    'Schedule(type, nextDueAt, isActive, '
    'lastCompletedAt, adjustedIntervalDays, isManualOverride)',
  ).eq('gardenId', gardenId).order('createdAt');

  return (rows as List)
      .map((r) => Plant.fromJson(r as Map<String, dynamic>))
      .toList();
});
