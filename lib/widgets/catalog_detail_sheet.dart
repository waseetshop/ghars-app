import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../models/catalog_item.dart';

// ── Helpers ───────────────────────────────────────────────────
const _categoryEmoji = {
  'FRUIT_TREE': '🌳',
  'VEGETABLE':  '🥬',
  'HERB':       '🌿',
  'ORNAMENTAL': '🌺',
  'INDOOR':     '🪴',
  'SUCCULENT':  '🌵',
};

const _categoryLabel = {
  'FRUIT_TREE': 'أشجار مثمرة',
  'VEGETABLE':  'خضروات',
  'HERB':       'أعشاب',
  'ORNAMENTAL': 'نباتات زينة',
  'INDOOR':     'نباتات داخلية',
  'SUCCULENT':  'عُصاريات',
};

const _saltLabel = {
  'LOW':       'منخفضة جداً',
  'MEDIUM':    'متوسطة',
  'HIGH':      'عالية',
  'VERY_HIGH': 'عالية جداً',
};

const _fertilizerAdvice = {
  'FRUIT_TREE': 'NPK متوازن كل شهر في موسم النمو، وسماد بوتاسيوم عالٍ قبل الإثمار',
  'VEGETABLE':  'NPK عالي نيتروجين كل أسبوعين، وكالسيوم لمنع تعفّن الطرف',
  'HERB':       'سماد خفيف (نصف جرعة) كل 3 أسابيع، تجنّب الإفراط في النيتروجين',
  'ORNAMENTAL': 'NPK متوازن كل 2-4 أسابيع في موسم النمو',
  'INDOOR':     'سماد مخفّف كل شهر، توقّف كاملاً في الشتاء',
  'SUCCULENT':  'سماد نادر 2-3 مرات/سنة، منخفض نيتروجين',
};

String lightLabel(int min, int max) {
  final avg = (min + max) / 2;
  if (avg < 1000)  return 'ضوء خافت';
  if (avg < 3000)  return 'ضوء منخفض';
  if (avg < 8000)  return 'ضوء متوسط';
  if (avg < 20000) return 'ضوء مباشر جزئي';
  return 'ضوء شمس كامل';
}

String lightEmoji(int min, int max) {
  final avg = (min + max) / 2;
  if (avg < 1000)  return '🌑';
  if (avg < 3000)  return '🌥️';
  if (avg < 8000)  return '⛅';
  if (avg < 20000) return '🌤️';
  return '☀️';
}

// ── Public sheet widget ───────────────────────────────────────
/// Pass [onAdd] to show an "إضافة" button at the bottom.
/// Omit it (null) for read-only reference mode.
class CatalogDetailSheet extends StatelessWidget {
  final CatalogItem item;
  final VoidCallback? onAdd;

  const CatalogDetailSheet({
    super.key,
    required this.item,
    this.onAdd,
  });

  /// Convenience helper — shows this sheet as a modal bottom sheet.
  static void show(
    BuildContext context,
    CatalogItem item, {
    VoidCallback? onAdd,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GharsColors.charcoal800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CatalogDetailSheet(item: item, onAdd: onAdd),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fertAdvice =
        _fertilizerAdvice[item.category] ?? 'سماد متوازن كل شهر';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: GharsColors.charcoal600,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),

            // ── Hero row ────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: GharsColors.charcoal700,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      _categoryEmoji[item.category] ?? '🌱',
                      style: const TextStyle(fontSize: 38),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nameAr,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: GharsColors.textPrimary,
                        ),
                      ),
                      Text(
                        item.nameEn,
                        style: const TextStyle(
                          fontSize: 13,
                          color: GharsColors.textMuted,
                        ),
                      ),
                      if (item.nameLatin != null)
                        Text(
                          item.nameLatin!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: GharsColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: GharsColors.charcoal700,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _categoryLabel[item.category] ?? item.category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: GharsColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Info grid ────────────────────────────────────
            _SectionTitle('احتياجات النبتة'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _InfoCard(
                  emoji: '💧',
                  title: 'ري الصيف',
                  value: 'كل ${item.wateringCycleSummer} أيام',
                  color: const Color(0xFF4FC3F7),
                ),
                _InfoCard(
                  emoji: '❄️',
                  title: 'ري الشتاء',
                  value: 'كل ${item.wateringCycleWinter} أيام',
                  color: const Color(0xFF90CAF9),
                ),
                _InfoCard(
                  emoji: lightEmoji(item.lightMin, item.lightMax),
                  title: 'الإضاءة',
                  value: lightLabel(item.lightMin, item.lightMax),
                  color: GharsColors.gold,
                ),
                _InfoCard(
                  emoji: '🧂',
                  title: 'حساسية الملح',
                  value: _saltLabel[item.saltSensitivity] ??
                      item.saltSensitivity,
                  color: const Color(0xFFCE93D8),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Soil pH ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GharsColors.charcoal800,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GharsColors.charcoal700),
              ),
              child: Row(
                children: [
                  const Text('🌱', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'حموضة التربة (pH)',
                          style: TextStyle(
                            fontSize: 12,
                            color: GharsColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.soilPHMin} – ${item.soilPHMax}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: GharsColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PHBar(min: item.soilPHMin, max: item.soilPHMax),
                ],
              ),
            ),

            // ── Light description ────────────────────────────
            if (item.lightDescription != null &&
                item.lightDescription!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GharsColors.charcoal800,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: GharsColors.charcoal700),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('☀️',
                        style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'متطلبات الإضاءة',
                            style: TextStyle(
                              fontSize: 12,
                              color: GharsColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.lightDescription!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: GharsColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Fertilizer ───────────────────────────────────
            const SizedBox(height: 16),
            _SectionTitle('التسميد والعناية'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GharsColors.green.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: GharsColors.green.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('🧪',
                          style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text(
                        'توصيات التسميد',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: GharsColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fertAdvice,
                    style: const TextStyle(
                      fontSize: 13,
                      color: GharsColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Category tips ────────────────────────────────
            ..._buildCategoryTips(item.category),

            const SizedBox(height: 24),

            // ── Add button (optional) ────────────────────────
            if (onAdd != null)
              SizedBox(
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [GharsColors.goldDim, GharsColors.gold],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: onAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: GharsColors.textPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🌱',
                            style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          'إضافة ${item.nameAr} لحديقتي',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategoryTips(String category) {
    final tips = <(String, String)>[];
    switch (category) {
      case 'VEGETABLE':
        tips.addAll([
          ('🌡️', 'تحتاج درجات حرارة مناسبة للإنتاج المثالي'),
          ('💦', 'انتبه لعدم تعرّض الأوراق للماء لتجنّب الأمراض الفطرية'),
          ('🌿', 'قلّم الأوراق القديمة بانتظام لتحفيز النمو'),
        ]);
      case 'FRUIT_TREE':
        tips.addAll([
          ('✂️', 'تقليم السنوي ضروري للحصول على ثمار جيدة'),
          ('🪲', 'افحص بانتظام للحشرات، خاصة في موسم الإثمار'),
          ('🌍', 'تحتاج تربة جيدة التصريف لتجنّب تعفّن الجذور'),
        ]);
      case 'HERB':
        tips.addAll([
          ('✂️', 'القطف المنتظم يحفّز نمو الأوراق الجديدة'),
          ('🌬️', 'تجنّب الرطوبة الزائدة لمنع العفن'),
          ('☀️', 'معظم الأعشاب تحتاج 6+ ساعات شمس يومياً'),
        ]);
      case 'INDOOR':
        tips.addAll([
          ('🪟', 'ضعها قرب النافذة للحصول على ضوء غير مباشر'),
          ('💨', 'التهوية الجيدة تمنع الحشرات والأمراض الفطرية'),
          ('🌡️', 'تجنّب الأماكن الباردة أو قريبة من مكيّف الهواء'),
        ]);
      case 'SUCCULENT':
        tips.addAll([
          ('🏺', 'وعاء بفتحات تصريف ضروري جداً'),
          ('🔆', 'تحتاج أكثر ضوء مما تتوقع، ضعها في أمشس موضع'),
          ('💧', 'الجذور تتعفّن بسرعة من الإفراط في الري'),
        ]);
      case 'ORNAMENTAL':
        tips.addAll([
          ('🌺', 'أزل الأزهار الذابلة لتحفيز تفتّح زهور جديدة'),
          ('🌿', 'التقليم الخفيف يحافظ على شكل النبتة'),
        ]);
    }
    if (tips.isEmpty) return [];
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GharsColors.charcoal800,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GharsColors.charcoal700),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('💡', style: TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Text(
                  'نصائح العناية',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: GharsColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.$1,
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.$2,
                          style: const TextStyle(
                            fontSize: 12,
                            color: GharsColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    ];
  }
}

// ── Section title ─────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: GharsColors.textSecondary,
        ),
      );
}

// ── Info card ─────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String value;
  final Color color;
  const _InfoCard({
    required this.emoji,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GharsColors.charcoal800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GharsColors.charcoal700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 5),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: GharsColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── pH visual bar (public for reuse) ─────────────────────────
class PHBar extends StatelessWidget {
  final double min;
  final double max;
  const PHBar({super.key, required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    const totalRange = 10.0;
    const barMin = 4.0;
    final startFrac = ((min - barMin) / totalRange).clamp(0.0, 1.0);
    final endFrac   = ((max - barMin) / totalRange).clamp(0.0, 1.0);

    return SizedBox(
      width: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('4',
                  style: const TextStyle(
                      fontSize: 9, color: GharsColors.textMuted)),
              Text('14',
                  style: const TextStyle(
                      fontSize: 9, color: GharsColors.textMuted)),
            ],
          ),
          const SizedBox(height: 3),
          LayoutBuilder(
            builder: (_, constraints) {
              final total = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: GharsColors.charcoal700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Positioned(
                    left: startFrac * total,
                    width: (endFrac - startFrac) * total,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: GharsColors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
