import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../models/today_task.dart';
import '../../providers/gardens_provider.dart';
import '../../services/notification_service.dart';
import '../plant_detail/plant_detail_screen.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _watering = <String>{};  // plantIds جاري الري
  final _watered  = <String>{};  // plantIds سُقيت في هذه الجلسة

  // ── تحية حسب الوقت ──────────────────────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير 🌤️';
    if (h < 17) return 'مساء الخير 🌿';
    return 'مساء النور 🌙';
  }

  // ── التاريخ بالعربية ─────────────────────────────────────────
  String get _arabicDate {
    final now = DateTime.now();
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${now.day} ${months[now.month]} ${now.year}';
  }

  // ── تسجيل الري ───────────────────────────────────────────────
  Future<void> _water(TodayTask task) async {
    final plantId = task.plant.id;
    setState(() => _watering.add(plantId));

    try {
      final res = await http.post(
        Uri.parse(
          '${AppConstants.apiBaseUrl}/api/gardens/${task.gardenId}/plants/$plantId/water',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'currentTempC': 35}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final days = (json['intervalDays'] as num?)?.round();

        // إلغاء الإشعار القديم
        await NotificationService.cancelForPlant(plantId);

        setState(() => _watered.add(plantId));

        // تحديث المزود
        ref.invalidate(plantsProvider(task.gardenId));
        ref.invalidate(todayTasksProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                days != null
                    ? '✅ تم ري "${task.plant.displayName}" — القادم خلال $days أيام'
                    : '✅ تم تسجيل الري',
              ),
              backgroundColor: GharsColors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final err = jsonDecode(res.body)['error'] ?? 'خطأ ${res.statusCode}';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString()),
              backgroundColor: GharsColors.diseased,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
      if (mounted) setState(() => _watering.remove(plantId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(todayTasksProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ───────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: GharsColors.charcoal900,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'اليوم',
              style: TextStyle(
                color: GharsColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: GharsColors.charcoal700),
            ),
          ),

          // ── تحية + تاريخ ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: GharsColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _arabicDate,
                    style: const TextStyle(
                      fontSize: 13,
                      color: GharsColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── المحتوى ───────────────────────────────────────────
          tasksAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: GharsColors.green,
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (e, _) => const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('⚠️', style: TextStyle(fontSize: 36)),
                    SizedBox(height: 8),
                    Text(
                      'خطأ في تحميل البيانات',
                      style: TextStyle(color: GharsColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            data: (tasks) {
              // جدولة الإشعارات بعد التحميل
              WidgetsBinding.instance.addPostFrameCallback((_) {
                NotificationService.scheduleAll(
                    tasks.map((t) => t.plant).toList());
              });

              // استبعاد النباتات التي سُقيت في هذه الجلسة
              final pending = tasks
                  .where((t) => !_watered.contains(t.plant.id))
                  .toList();

              if (pending.isEmpty) {
                return const SliverFillRemaining(child: _EmptyState());
              }

              final overdue = pending
                  .where((t) =>
                      t.plant.nextWatering!.isBefore(DateTime.now()))
                  .length;

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // إحصاء
                    _StatsRow(total: pending.length, overdue: overdue),
                    const SizedBox(height: 14),

                    // بطاقات المهام
                    ...pending.map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TaskCard(
                          task: task,
                          isWatering:
                              _watering.contains(task.plant.id),
                          onWater: () => _water(task),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlantDetailScreen(
                                plant:    task.plant,
                                gardenId: task.gardenId,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Stats row ──────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total;
  final int overdue;
  const _StatsRow({required this.total, required this.overdue});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _StatChip(
          emoji: '💧',
          label: '$total تحتاج ري',
          color: GharsColors.green,
        ),
        if (overdue > 0)
          _StatChip(
            emoji: '⚠️',
            label: '$overdue متأخر',
            color: GharsColors.critical,
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  const _StatChip({
    required this.emoji,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Task card ──────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final TodayTask task;
  final bool isWatering;
  final VoidCallback onWater;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.isWatering,
    required this.onWater,
    required this.onTap,
  });

  static const _categoryEmoji = {
    'FRUIT_TREE': '🌳',
    'VEGETABLE':  '🥬',
    'HERB':       '🌿',
    'ORNAMENTAL': '🌺',
    'INDOOR':     '🪴',
    'SUCCULENT':  '🌵',
  };

  bool get _isOverdue =>
      task.plant.nextWatering!.isBefore(DateTime.now());

  String get _timeLabel {
    final due  = task.plant.nextWatering!;
    final diff = due.difference(DateTime.now());
    if (diff.isNegative) {
      final ago = diff.abs();
      if (ago.inHours < 1)  return 'متأخر منذ دقائق';
      if (ago.inHours < 24) return 'متأخر ${ago.inHours} ساعة';
      return 'متأخر ${ago.inDays} يوم';
    }
    if (diff.inHours < 1) return 'خلال أقل من ساعة';
    return 'خلال ${diff.inHours} ساعة';
  }

  @override
  Widget build(BuildContext context) {
    final plant   = task.plant;
    final emoji   = _categoryEmoji[plant.catalogCategory] ?? '🌱';
    final overdue = _isOverdue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: GharsColors.charcoal800,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: overdue
                ? GharsColors.critical.withValues(alpha: 0.35)
                : GharsColors.charcoal700,
            width: overdue ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // أيقونة النبتة
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: overdue
                    ? GharsColors.critical.withValues(alpha: 0.08)
                    : GharsColors.greenFaint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 12),

            // معلومات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: GharsColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // اسم الحديقة
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: GharsColors.charcoal700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.gardenName,
                          style: const TextStyle(
                            fontSize: 10,
                            color: GharsColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // توقيت
                      Text(
                        _timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: overdue
                              ? GharsColors.critical
                              : GharsColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // زر الري
            GestureDetector(
              onTap: isWatering ? null : onWater,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: overdue ? GharsColors.green : GharsColors.greenFaint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GharsColors.green, width: 1.2),
                ),
                child: isWatering
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: overdue
                              ? Colors.white
                              : GharsColors.greenDark,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💧',
                              style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            'تم',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: overdue
                                  ? Colors.white
                                  : GharsColors.greenDark,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🌿', style: TextStyle(fontSize: 64)),
        SizedBox(height: 16),
        Text(
          'كل نباتاتك بخير اليوم',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: GharsColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'لا توجد نباتات تحتاج ري خلال الـ 24 ساعة القادمة',
            style: TextStyle(
              fontSize: 13,
              color: GharsColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
