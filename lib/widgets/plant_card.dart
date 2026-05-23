import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../models/plant.dart';
import 'health_badge.dart';

const _categoryEmoji = {
  'FRUIT_TREE': '🌳',
  'VEGETABLE':  '🥬',
  'HERB':       '🌿',
  'ORNAMENTAL': '🌺',
  'INDOOR':     '🪴',
  'SUCCULENT':  '🌵',
};

const _locationLabel = {
  'INDOOR':     'داخلي',
  'OUTDOOR':    'خارجي',
  'BALCONY':    'شرفة',
  'GREENHOUSE': 'بيت زجاجي',
};

class PlantCard extends StatelessWidget {
  final Plant plant;
  final VoidCallback? onTap;

  const PlantCard(this.plant, {super.key, this.onTap});

  String get _wateringLabel {
    final due = plant.nextWatering;
    if (due == null) return '—';
    final diff = due.difference(DateTime.now());
    if (diff.isNegative) return 'متأخر!';
    if (diff.inHours < 24) return '${diff.inHours} ساعة';
    return '${diff.inDays} يوم';
  }

  bool get _isOverdue {
    final due = plant.nextWatering;
    return due != null && due.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: GharsColors.charcoal800,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GharsColors.charcoal700),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // emoji + health
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _categoryEmoji[plant.catalogCategory] ?? '🌱',
                  style: const TextStyle(fontSize: 28),
                ),
                HealthBadge(plant.healthStatus),
              ],
            ),
            const SizedBox(height: 8),

            // name
            Text(
              plant.displayName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: GharsColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (plant.nickname != null)
              Text(
                plant.catalogNameAr,
                style: const TextStyle(
                  fontSize: 11,
                  color: GharsColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            const Spacer(),

            // footer divider
            const Divider(color: GharsColors.charcoal700, height: 12),

            // location + watering
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _locationLabel[plant.location] ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: GharsColors.textSecondary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💧', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 2),
                    Text(
                      _wateringLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isOverdue
                            ? GharsColors.critical
                            : GharsColors.gold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
