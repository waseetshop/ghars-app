import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../models/garden.dart';
import '../../providers/gardens_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/plant_card.dart';
import '../plant_detail/plant_detail_screen.dart';
import '../add_plant/add_plant_screen.dart';

class PlantsScreen extends ConsumerStatefulWidget {
  final String gardenId;
  final String gardenName;

  const PlantsScreen({
    super.key,
    required this.gardenId,
    required this.gardenName,
  });

  @override
  ConsumerState<PlantsScreen> createState() => _PlantsScreenState();
}

class _PlantsScreenState extends ConsumerState<PlantsScreen> {
  bool _wateringAll = false;

  Future<void> _waterAll() async {
    setState(() => _wateringAll = true);
    try {
      final res = await http.post(
        Uri.parse(
          '${AppConstants.apiBaseUrl}/api/gardens/${widget.gardenId}/water-all',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'currentTempC': 35}),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final count = json['wateredCount'] as int? ?? 0;
        ref.invalidate(plantsProvider(widget.gardenId));
        ref.invalidate(todayTasksProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم ري $count نبتة بنجاح'),
            backgroundColor: GharsColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final err = jsonDecode(res.body)['error'] ?? 'خطأ ${res.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.toString()),
            backgroundColor: GharsColors.diseased,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر الاتصال: $e'),
            backgroundColor: GharsColors.diseased,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _wateringAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantsAsync = ref.watch(plantsProvider(widget.gardenId));
    final gardenAsync = ref.watch(gardenProvider(widget.gardenId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gardenName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: GharsColors.charcoal700),
        ),
      ),
      // الأصيص: لا يُعرض زر + أبداً — يُدار من الصفحة الرئيسية
      floatingActionButton: gardenAsync.whenOrNull(
        data: (garden) {
          if (garden.isPot) return null;
          return FloatingActionButton(
            backgroundColor: GharsColors.gold,
            foregroundColor: GharsColors.textPrimary,
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AddPlantScreen(gardenId: widget.gardenId),
                ),
              );
              if (added == true) {
                ref.invalidate(plantsProvider(widget.gardenId));
              }
            },
            child: const Icon(Icons.add, size: 28),
          );
        },
      ),
      body: plantsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: GharsColors.gold, strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              const Text('خطأ في تحميل النباتات',
                  style: TextStyle(color: GharsColors.textSecondary)),
              const SizedBox(height: 4),
              Text(e.toString(),
                  style: const TextStyle(
                      color: GharsColors.textMuted, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (plants) {
          // جدولة الإشعارات
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.scheduleAll(plants);
          });

          if (plants.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🌱', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('لا توجد نباتات في هذه الحديقة',
                      style: TextStyle(color: GharsColors.textSecondary)),
                ],
              ),
            );
          }

          // ── إحصائيات ──────────────────────────────────────
          final now     = DateTime.now();
          final weekAgo = now.subtract(const Duration(days: 7));
          final healthy = plants.where((p) => p.healthStatus == 'HEALTHY').length;
          final overdue = plants.where((p) =>
              p.nextWatering != null && p.nextWatering!.isBefore(now)).length;
          final wateredWeek = plants.where((p) =>
              p.lastWatered != null && p.lastWatered!.isAfter(weekAgo)).length;
          final healthPct = plants.isEmpty
              ? 0
              : (healthy / plants.length * 100).round();

          return Column(
            children: [
              // ── Stats card ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _StatsCard(
                  total:       plants.length,
                  healthPct:   healthPct,
                  wateredWeek: wateredWeek,
                  overdue:     overdue,
                ),
              ),

              // ── Irrigation banner ──────────────────────────
              gardenAsync.whenOrNull(
                data: (garden) => garden.hasTimer
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: _IrrigationBanner(
                          garden:       garden,
                          wateringAll:  _wateringAll,
                          onWaterAll:   _waterAll,
                          // للمؤقت الذكي: أقرب nextWatering موحّدة
                          nextWatering: garden.isSmartTimer
                              ? plants
                                  .where((p) => p.nextWatering != null)
                                  .map((p) => p.nextWatering!)
                                  .fold<DateTime?>(null, (min, d) =>
                                      min == null || d.isBefore(min) ? d : min)
                              : null,
                        ),
                      )
                    : null,
              ) ?? const SizedBox.shrink(),

              // ── Plants grid ────────────────────────────────
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: plants.length,
                  itemBuilder: (ctx, i) => PlantCard(
                    plants[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlantDetailScreen(
                          plant:    plants[i],
                          gardenId: widget.gardenId,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Stats card ─────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final int total;
  final int healthPct;
  final int wateredWeek;
  final int overdue;

  const _StatsCard({
    required this.total,
    required this.healthPct,
    required this.wateredWeek,
    required this.overdue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GharsColors.charcoal800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GharsColors.charcoal700),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          _StatCell(
            value: '$total',
            label: 'نبتة',
            color: GharsColors.gold,
          ),
          _Divider(),
          _StatCell(
            value: '$healthPct%',
            label: 'بصحة جيدة',
            color: GharsColors.healthy,
          ),
          _Divider(),
          _StatCell(
            value: '$wateredWeek',
            label: 'سُقيت هذا الأسبوع',
            color: GharsColors.green,
          ),
          _Divider(),
          _StatCell(
            value: '$overdue',
            label: 'متأخرة',
            color: overdue > 0 ? GharsColors.critical : GharsColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10, color: GharsColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: GharsColors.charcoal700,
      );
}

// ── Irrigation banner ──────────────────────────────────────────
class _IrrigationBanner extends StatelessWidget {
  final Garden garden;
  final bool wateringAll;
  final VoidCallback onWaterAll;
  /// أقرب nextWatering بين النباتات (للمؤقت الذكي تكون موحّدة)
  final DateTime? nextWatering;

  const _IrrigationBanner({
    required this.garden,
    required this.wateringAll,
    required this.onWaterAll,
    this.nextWatering,
  });

  String get _typeLabel => garden.isSmartTimer ? 'مؤقت ذكي 🤖' : 'مؤقت زراعي ⏱️';
  String get _typeEmoji => garden.isSmartTimer ? '🤖' : '⏱️';

  String get _schedule {
    final days  = garden.timerIntervalDays;
    final times = garden.timerTimesPerDay;
    final dur   = garden.timerDurationMin;
    final t     = garden.timerTimes.join(' و ');
    final parts = <String>[];
    if (days != null) parts.add(days == 1 ? 'يومياً' : 'كل $days أيام');
    if (times != null && times > 1) parts.add('$times× يومياً');
    if (dur != null) parts.add('$dur د لكل جلسة');
    if (t.isNotEmpty) parts.add('الساعة $t');
    return parts.join(' · ');
  }

  /// الوقت المتبقي حتى الري القادم (للمؤقت الذكي)
  String _nextLabel(DateTime next) {
    final diff = next.difference(DateTime.now());
    if (diff.isNegative) return 'حان وقت الري الآن';
    if (diff.inMinutes < 60) return 'خلال ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'الساعة ${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
    return 'بعد ${diff.inDays} ${diff.inDays == 1 ? 'يوم' : 'أيام'}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: garden.isSmartTimer
            ? GharsColors.green.withValues(alpha: 0.08)
            : GharsColors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: GharsColors.green.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_typeEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GharsColors.green,
                      ),
                    ),
                    if (_schedule.isNotEmpty)
                      Text(
                        _schedule,
                        style: const TextStyle(
                          fontSize: 11,
                          color: GharsColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              // زر سقي جماعي
              GestureDetector(
                onTap: wateringAll ? null : onWaterAll,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: GharsColors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: wateringAll
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('💧', style: TextStyle(fontSize: 13)),
                            SizedBox(width: 4),
                            Text(
                              'سقي الكل',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          // ── للمؤقت الذكي: الري القادم الموحّد ───────────────
          if (garden.isSmartTimer && nextWatering != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: GharsColors.charcoal700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 13, color: GharsColors.green),
                  const SizedBox(width: 5),
                  Text(
                    'الري القادم لكل النباتات: ${_nextLabel(nextWatering!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: GharsColors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
