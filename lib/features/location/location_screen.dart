import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/colors.dart';
import '../../providers/location_provider.dart';

const _climates = [
  ('HOT_ARID',      '☀️',  'حار جاف',    'الرياض، القصيم، حفر الباطن'),
  ('TROPICAL',      '🌴',  'استوائي',    'جدة، مكة، الدمام، الخليج'),
  ('TEMPERATE',     '🌤️', 'معتدل',      'أبها، الطائف، تبوك، هضبة نجد'),
  ('MEDITERRANEAN', '🌊',  'متوسطي',    'المناطق ذات الشتاء الممطر'),
];

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  bool _loading = false;

  // ── طلب الموقع من GPS ────────────────────────────────────────
  Future<void> _requestLocation() async {
    setState(() => _loading = true);

    try {
      // تحقق من الخدمة
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showManualSheet();
        return;
      }

      // تحقق من الأذونات
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) _showManualSheet();
        return;
      }

      // الحصول على الموقع
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.reduced, // دقة منخفضة تكفي للمناخ
          timeLimit: Duration(seconds: 10),
        ),
      );

      final climate = climateFromCoords(pos.latitude, pos.longitude);
      final label   = cityFromCoords(pos.latitude, pos.longitude);

      await saveLocation(
        climate: climate,
        label:   label,
        lat:     pos.latitude,
        lon:     pos.longitude,
      );

      ref.invalidate(locationDataProvider);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) _showManualSheet();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── اختيار يدوي للمناخ ───────────────────────────────────────
  void _showManualSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GharsColors.charcoal800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ManualClimateSheet(
        onSelected: (climate, label) async {
          Navigator.pop(context);
          await saveLocation(climate: climate, label: label);
          ref.invalidate(locationDataProvider);
          if (mounted) context.go('/');
        },
      ),
    );
  }

  // ── تخطّي الإعداد (HOT_ARID افتراضي) ────────────────────────
  Future<void> _skip() async {
    await saveLocation(climate: 'HOT_ARID', label: 'موقعك الحالي');
    ref.invalidate(locationDataProvider);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: GharsColors.charcoal900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── رأس الصفحة ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  children: [
                    // زر تخطّي
                    const Spacer(),
                    TextButton(
                      onPressed: _loading ? null : _skip,
                      child: const Text(
                        'تخطّي',
                        style: TextStyle(
                          color: GharsColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── عنوان رئيسي ─────────────────────────────────
              const Text(
                'أين أنت ونباتاتك؟',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: GharsColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'سيُستخدم موقعك فقط لـ:',
                style: TextStyle(
                  fontSize: 15,
                  color: GharsColors.textSecondary,
                ),
              ),

              const SizedBox(height: 36),

              // ── قائمة الفوائد ────────────────────────────────
              _BenefitRow(
                icon: Icons.location_on_outlined,
                text: 'اقتراح نباتات مناسبة لمنطقتك',
              ),
              const SizedBox(height: 24),
              _BenefitRow(
                icon: Icons.wb_sunny_outlined,
                text: 'ضبط جداول الري حسب الطقس المحلي',
              ),
              const SizedBox(height: 24),
              _BenefitRow(
                icon: Icons.thermostat_outlined,
                text: 'تنبيهات الحرارة الشديدة وتغيّر الطقس',
              ),
              const SizedBox(height: 24),
              _BenefitRow(
                icon: Icons.grain_outlined,
                text: 'تحديد نجوم الأنواء وتوصيات الموسم',
              ),

              const Spacer(),

              // ── زر المتابعة ─────────────────────────────────
              Padding(
                padding: EdgeInsets.only(bottom: bottom + 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _requestLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GharsColors.greenDark,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          GharsColors.greenDark.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'تحديد موقعي تلقائياً',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── صف فائدة ─────────────────────────────────────────────────
class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: GharsColors.charcoal700,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: GharsColors.textSecondary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: GharsColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sheet: اختيار يدوي للمناخ ─────────────────────────────────
class _ManualClimateSheet extends StatelessWidget {
  final void Function(String climate, String label) onSelected;
  const _ManualClimateSheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مقبض
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: GharsColors.charcoal600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'اختر مناخ منطقتك',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: GharsColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'يساعد التطبيق في ضبط جداول الري المناسبة',
            style: TextStyle(
              fontSize: 13,
              color: GharsColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          // خيارات المناخ
          ..._climates.map((c) => _ClimateOption(
            emoji:    c.$1 == 'TEMPERATE' ? '🌤️' : c.$2,
            title:    c.$3,
            subtitle: c.$4,
            onTap:    () => onSelected(c.$1, c.$3),
          )),
        ],
      ),
    );
  }
}

class _ClimateOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ClimateOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: GharsColors.charcoal700,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: GharsColors.textPrimary)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11,
                          color: GharsColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: GharsColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
