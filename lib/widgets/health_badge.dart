import 'package:flutter/material.dart';
import '../core/colors.dart';

class HealthBadge extends StatelessWidget {
  final String status;
  const HealthBadge(this.status, {super.key});

  static const _labels = {
    'HEALTHY':    'بصحة جيدة',
    'STRESSED':   'متوتر',
    'DISEASED':   'مريض',
    'RECOVERING': 'في التعافي',
    'CRITICAL':   'حرج',
  };

  static const _colors = {
    'HEALTHY':    GharsColors.healthy,
    'STRESSED':   GharsColors.stressed,
    'DISEASED':   GharsColors.diseased,
    'RECOVERING': GharsColors.gold,
    'CRITICAL':   GharsColors.critical,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[status] ?? status;
    final color = _colors[status] ?? GharsColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
