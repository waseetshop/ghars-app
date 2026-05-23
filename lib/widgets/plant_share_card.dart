import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../models/plant.dart';

/// بطاقة المشاركة — تُعرض off-screen ثم تُلتقط كصورة PNG
class PlantShareCard extends StatelessWidget {
  final Plant plant;
  const PlantShareCard({super.key, required this.plant});

  // ── ترجمات ─────────────────────────────────────────────────
  static String _healthLabel(String s) => switch (s) {
        'HEALTHY'    => 'بصحة ممتازة',
        'STRESSED'   => 'متوترة',
        'DISEASED'   => 'مريضة',
        'CRITICAL'   => 'حالة حرجة',
        'RECOVERING' => 'تتعافى',
        _            => s,
      };

  static Color _healthColor(String s) => switch (s) {
        'HEALTHY'    => GharsColors.healthy,
        'STRESSED'   => GharsColors.stressed,
        'DISEASED'   => GharsColors.diseased,
        'CRITICAL'   => GharsColors.critical,
        'RECOVERING' => GharsColors.recovering,
        _            => GharsColors.textMuted,
      };

  static String _locationLabel(String s) => switch (s) {
        'OUTDOOR'    => 'خارجي 🌤️',
        'INDOOR'     => 'داخلي 🏠',
        'GREENHOUSE' => 'بيت محمي 🏡',
        _            => s,
      };

  static String _categoryEmoji(String s) => switch (s) {
        'FRUIT'       => '🍅',
        'VEGETABLE'   => '🥦',
        'HERB'        => '🌿',
        'SUCCULENT'   => '🌵',
        'TREE'        => '🌳',
        'ORNAMENTAL'  => '🌸',
        _             => '🪴',
      };

  static String _wateringLabel(DateTime? next) {
    if (next == null) return '—';
    final diff = next.difference(DateTime.now());
    if (diff.isNegative) return 'حان وقت الري';
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'غداً';
    return 'خلال ${diff.inDays} أيام';
  }

  static String _lastWateredLabel(DateTime? last) {
    if (last == null) return 'لم يُسقَ بعد';
    final diff = DateTime.now().difference(last);
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'أمس';
    return 'منذ ${diff.inDays} أيام';
  }

  @override
  Widget build(BuildContext context) {
    final healthColor = _healthColor(plant.healthStatus);
    final catEmoji    = _categoryEmoji(plant.catalogCategory);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F6),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── رأس البطاقة — خلفية خضراء ──────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2C7D38), Color(0xFF389E48)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  // أيقونة التطبيق / شعار
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('🌱', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'غَرْس',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  // شارة الصحة
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _healthLabel(plant.healthStatus),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ── جسم البطاقة ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // أيقونة الفئة + اسم النبتة
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // دائرة الأيقونة
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: GharsColors.greenFaint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(catEmoji,
                              style: const TextStyle(fontSize: 34)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plant.displayName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: GharsColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            if (plant.nickname != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                plant.catalogNameAr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: GharsColors.textMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            // موقع النبتة
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: GharsColors.charcoal700,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _locationLabel(plant.location),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: GharsColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── شريط الصحة ───────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: healthColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: healthColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: healthColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'الحالة الصحية: ${_healthLabel(plant.healthStatus)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: healthColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── معلومات الري ─────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _InfoChip(
                          emoji: '💧',
                          label: 'الري القادم',
                          value: _wateringLabel(plant.nextWatering),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoChip(
                          emoji: '📅',
                          label: 'آخر ري',
                          value: _lastWateredLabel(plant.lastWatered),
                        ),
                      ),
                    ],
                  ),

                  if (plant.wateringIntervalDays != null) ...[
                    const SizedBox(height: 10),
                    _InfoChip(
                      emoji: '🔄',
                      label: 'دورة الري',
                      value: 'كل ${plant.wateringIntervalDays} أيام',
                    ),
                  ],

                  // ── تذييل ────────────────────────────────
                  const SizedBox(height: 18),
                  Container(
                    height: 1,
                    color: GharsColors.charcoal500,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🌿',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'شاركها من تطبيق غَرْس',
                        style: TextStyle(
                          fontSize: 12,
                          color: GharsColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── شريحة معلومة صغيرة ────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _InfoChip({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: GharsColors.charcoal700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: GharsColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GharsColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
