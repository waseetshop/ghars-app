import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:timeago/timeago.dart' as timeago;
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../models/plant.dart';
import '../../widgets/plant_share_card.dart';
import '../../models/health_log.dart';
import '../../providers/gardens_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/health_badge.dart';
import '../../widgets/catalog_detail_sheet.dart';

class PlantDetailScreen extends ConsumerStatefulWidget {
  final Plant plant;
  final String gardenId;

  const PlantDetailScreen({
    super.key,
    required this.plant,
    required this.gardenId,
  });

  @override
  ConsumerState<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends ConsumerState<PlantDetailScreen> {
  bool _diagnosing = false;
  Map<String, dynamic>? _diagnosisResult;
  String? _diagnosisError;

  bool _watering = false;
  bool _wateredJustNow = false;

  bool _sharing = false;

  // ── Diagnose via camera or gallery ──────────────────────────
  Future<void> _startDiagnosis(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() {
      _diagnosing = true;
      _diagnosisResult = null;
      _diagnosisError = null;
    });

    try {
      // Read image bytes and encode to base64 (API expects JSON, not multipart)
      final bytes = await File(picked.path).readAsBytes();
      final base64Str = base64Encode(bytes);

      final ext = picked.path.split('.').last.toLowerCase();
      final mediaType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      final response = await http.post(
        Uri.parse(
          '${AppConstants.apiBaseUrl}/api/gardens/${widget.gardenId}/plants/${widget.plant.id}/diagnose',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'images': [
            {
              'data': base64Str,
              'mediaType': mediaType,
              'angle': 'AFFECTED_LEAF',
            }
          ],
          'currentTempC':    35,
          'humidity':        40,
          'lastWateredDays': 2,
        }),
      ).timeout(const Duration(seconds: 90));

      if (!mounted) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      setState(() {
        _diagnosisResult = json;
        _diagnosing = false;
      });

      // Refresh plant data after auto-applied diagnosis
      if (json['decision'] == 'AUTO_APPLIED') {
        ref.invalidate(plantsProvider(widget.gardenId));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _diagnosisError = e.toString();
        _diagnosing = false;
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GharsColors.charcoal800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: GharsColors.charcoal600,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const Text(
                'اختر مصدر الصورة',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: GharsColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'الكاميرا',
                onTap: () {
                  Navigator.pop(context);
                  _startDiagnosis(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: 'معرض الصور',
                onTap: () {
                  Navigator.pop(context);
                  _startDiagnosis(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Record watering done ────────────────────────────────────
  Future<void> _recordWatering() async {
    setState(() => _watering = true);
    try {
      final res = await http.post(
        Uri.parse(
          '${AppConstants.apiBaseUrl}/api/gardens/${widget.gardenId}/plants/${widget.plant.id}/water',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'currentTempC': 35}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final nextDue = json['nextDueAt'] as String?;
        final days    = (json['intervalDays'] as num?)?.round();

        // Cancel old notification, then reschedule when plants reload
        await NotificationService.cancelForPlant(widget.plant.id);

        setState(() => _wateredJustNow = true);

        // Refresh plants list to get updated schedule
        ref.invalidate(plantsProvider(widget.gardenId));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                nextDue != null && days != null
                    ? '✅ تم الري! الري القادم خلال $days أيام'
                    : '✅ تم تسجيل الري',
              ),
              backgroundColor: GharsColors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
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
      if (mounted) setState(() => _watering = false);
    }
  }

  // ── Delete plant ────────────────────────────────────────
  Future<void> _deletePlant() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GharsColors.charcoal800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'حذف النبتة',
          style: TextStyle(color: GharsColors.textPrimary, fontSize: 17),
        ),
        content: Text(
          'هل أنت متأكد من حذف "${widget.plant.displayName}"؟ لا يمكن التراجع.',
          style: const TextStyle(color: GharsColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء',
                style: TextStyle(color: GharsColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف',
                style: TextStyle(
                    color: GharsColors.diseased, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await http.delete(
        Uri.parse(
          '${AppConstants.apiBaseUrl}/api/gardens/${widget.gardenId}/plants/${widget.plant.id}',
        ),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200) {
        ref.invalidate(plantsProvider(widget.gardenId));
        ref.invalidate(gardenPlantCountProvider(widget.gardenId));
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ تم حذف "${widget.plant.displayName}"'),
            backgroundColor: const Color.fromRGBO(199, 109, 89, 1),
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
    }
  }

  // ── Schedule override sheet ───────────────────────────────
  void _showScheduleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GharsColors.charcoal800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ScheduleOverrideSheet(
        plant:    widget.plant,
        gardenId: widget.gardenId,
        onSaved: () {
          ref.invalidate(plantsProvider(widget.gardenId));
          ref.invalidate(todayTasksProvider);
        },
      ),
    );
  }

  // ── Edit plant sheet ─────────────────────────────────────
  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GharsColors.charcoal800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditPlantSheet(
        plant: widget.plant,
        gardenId: widget.gardenId,
        onSaved: () {
          ref.invalidate(plantsProvider(widget.gardenId));
          Navigator.pop(context); // pop back to garden after edit
        },
      ),
    );
  }

  // ── Share plant as image ─────────────────────────────────────
  Future<void> _sharePlant() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      // أنشئ المفتاح والـ overlay entry
      final cardKey = GlobalKey();
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (_) => Positioned(
          top: -5000,
          left: 0,
          child: RepaintBoundary(
            key: cardKey,
            child: PlantShareCard(plant: widget.plant),
          ),
        ),
      );

      Overlay.of(context).insert(entry);

      // ننتظر frame واحد حتى يُرسم الـ widget
      await Future.delayed(const Duration(milliseconds: 120));

      // التقاط الصورة
      final boundary =
          cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      entry.remove();

      if (!mounted || byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'ghars_${widget.plant.id}.png',
      );

      await Share.shareXFiles(
        [xFile],
        text: 'نبتتي "${widget.plant.displayName}" 🌱 — من تطبيق غَرْس',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّرت المشاركة: $e'),
            backgroundColor: GharsColors.diseased,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: GharsColors.charcoal800,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // ── زر المشاركة ───────────────────────────────
              IconButton(
                onPressed: _sharing ? null : _sharePlant,
                tooltip: 'مشاركة النبتة',
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: GharsColors.textMuted,
                        ),
                      )
                    : const Icon(Icons.ios_share_rounded,
                        color: GharsColors.textMuted, size: 22),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: GharsColors.textMuted),
                color: GharsColors.charcoal700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (value) {
                  if (value == 'edit') _showEditSheet();
                  if (value == 'delete') _deletePlant();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: GharsColors.textSecondary),
                        SizedBox(width: 10),
                        Text('تعديل',
                            style: TextStyle(color: GharsColors.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: GharsColors.diseased),
                        SizedBox(width: 10),
                        Text('حذف',
                            style: TextStyle(color: GharsColors.diseased)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _PlantHeader(plant: plant),
            ),
          ),

          // ── Body ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // name + health
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plant.displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: GharsColors.textPrimary,
                            ),
                          ),
                          if (plant.nickname != null)
                            Text(
                              plant.catalogNameAr,
                              style: const TextStyle(
                                fontSize: 13,
                                color: GharsColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    HealthBadge(plant.healthStatus),
                  ],
                ),
                const SizedBox(height: 20),

                // info grid
                _InfoGrid(plant: plant),
                const SizedBox(height: 24),

                // watering done button
                _WaterButton(
                  onTap:       _recordWatering,
                  isLoading:   _watering,
                  isDone:      _wateredJustNow,
                  isOverdue:   plant.nextWatering != null &&
                               plant.nextWatering!.isBefore(DateTime.now()),
                ),
                const SizedBox(height: 8),

                // schedule override button
                _ScheduleChip(
                  intervalDays:     plant.wateringIntervalDays,
                  isManualOverride: plant.isManualOverride,
                  onTap:            () => _showScheduleSheet(),
                ),
                const SizedBox(height: 10),

                // plant info button
                if (plant.catalogDetails != null)
                  _PlantInfoButton(
                    onTap: () => CatalogDetailSheet.show(
                      context,
                      plant.catalogDetails!,
                    ),
                  ),
                if (plant.catalogDetails != null)
                  const SizedBox(height: 10),

                // diagnose button
                _DiagnoseButton(
                  onTap: _showImageSourceSheet,
                  isLoading: _diagnosing,
                ),
                const SizedBox(height: 16),

                // diagnosis result
                if (_diagnosing) ...[
                  const _DiagnosisLoading(),
                  const SizedBox(height: 16),
                ],
                if (_diagnosisResult != null) ...[
                  _DiagnosisResult(data: _diagnosisResult!),
                  const SizedBox(height: 16),
                ],
                if (_diagnosisError != null) ...[
                  _DiagnosisError(message: _diagnosisError!),
                  const SizedBox(height: 16),
                ],

                // ── Health log section ────────────────────────
                const SizedBox(height: 8),
                _HealthLogSection(
                  plantId:  plant.id,
                  gardenId: widget.gardenId,
                ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plant header ─────────────────────────────────────────────
class _PlantHeader extends StatelessWidget {
  final Plant plant;
  const _PlantHeader({required this.plant});

  static const _categoryEmoji = {
    'FRUIT_TREE': '🌳',
    'VEGETABLE':  '🥬',
    'HERB':       '🌿',
    'ORNAMENTAL': '🌺',
    'INDOOR':     '🪴',
    'SUCCULENT':  '🌵',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GharsColors.charcoal800,
      child: Center(
        child: Text(
          _categoryEmoji[plant.catalogCategory] ?? '🌱',
          style: const TextStyle(fontSize: 80),
        ),
      ),
    );
  }
}

// ── Info grid ────────────────────────────────────────────────
class _InfoGrid extends StatelessWidget {
  final Plant plant;
  const _InfoGrid({required this.plant});

  static const _locationLabel = {
    'INDOOR':     'داخلي',
    'OUTDOOR':    'خارجي',
    'BALCONY':    'شرفة',
    'GREENHOUSE': 'بيت زجاجي',
  };

  String get _wateringLabel {
    final due = plant.nextWatering;
    if (due == null) return '—';
    final diff = due.difference(DateTime.now());
    if (diff.isNegative) return 'متأخر!';
    if (diff.inHours < 24) return '${diff.inHours} ساعة';
    return '${diff.inDays} يوم';
  }

  bool get _isOverdue =>
      plant.nextWatering != null &&
      plant.nextWatering!.isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.5,
      children: [
        _InfoTile(
          icon: Icons.location_on_outlined,
          label: 'الموقع',
          value: _locationLabel[plant.location] ?? plant.location,
        ),
        _InfoTile(
          icon: Icons.water_drop_outlined,
          label: 'الري القادم',
          value: _wateringLabel,
          valueColor: _isOverdue ? GharsColors.critical : GharsColors.gold,
        ),
        _InfoTile(
          icon: Icons.health_and_safety_outlined,
          label: 'الحالة',
          value: _healthLabel(plant.healthStatus),
          valueColor: _healthColor(plant.healthStatus),
        ),
        _InfoTile(
          icon: Icons.category_outlined,
          label: 'النوع',
          value: plant.catalogNameAr,
        ),
      ],
    );
  }

  String _healthLabel(String s) => const {
        'HEALTHY':    'بصحة جيدة',
        'STRESSED':   'متوتر',
        'DISEASED':   'مريض',
        'RECOVERING': 'في التعافي',
        'CRITICAL':   'حرج',
      }[s] ??
      s;

  Color _healthColor(String s) => const {
        'HEALTHY':    GharsColors.healthy,
        'STRESSED':   GharsColors.stressed,
        'DISEASED':   GharsColors.diseased,
        'RECOVERING': GharsColors.gold,
        'CRITICAL':   GharsColors.critical,
      }[s] ??
      GharsColors.textSecondary;
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GharsColors.charcoal800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GharsColors.charcoal700),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: GharsColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: GharsColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? GharsColors.textPrimary,
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

// ── Plant Info button ─────────────────────────────────────────
class _PlantInfoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlantInfoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: GharsColors.charcoal800,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GharsColors.charcoal700),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📖', style: TextStyle(fontSize: 17)),
            SizedBox(width: 8),
            Text(
              'معلومات النبتة واحتياجاتها',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GharsColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Water Done button ────────────────────────────────────────
class _WaterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;
  final bool isDone;
  final bool isOverdue;

  const _WaterButton({
    required this.onTap,
    required this.isLoading,
    required this.isDone,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg     = isDone
        ? GharsColors.green.withValues(alpha: 0.12)
        : isOverdue
            ? GharsColors.green
            : GharsColors.greenFaint;
    final Color border = isDone
        ? GharsColors.green
        : isOverdue
            ? GharsColors.green
            : GharsColors.charcoal700;
    final Color text   = isDone || isOverdue
        ? (isDone ? GharsColors.green : Colors.white)
        : GharsColors.textSecondary;

    return GestureDetector(
      onTap: (isLoading || isDone) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: isDone || isOverdue ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  color: text, strokeWidth: 2,
                ),
              )
            else
              Text(
                isDone ? '✅' : '💧',
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(width: 10),
            Text(
              isLoading
                  ? 'جاري التسجيل...'
                  : isDone
                      ? 'تم الري ✓'
                      : isOverdue
                          ? 'تم الري — سقِ الآن!'
                          : 'تم الري',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Diagnose button ──────────────────────────────────────────
class _DiagnoseButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;
  const _DiagnoseButton({required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [GharsColors.goldDim, GharsColors.gold],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  color: GharsColors.textPrimary,
                  strokeWidth: 2,
                ),
              )
            else
              const Text('🔬', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              isLoading ? 'جاري التحليل...' : 'تشخيص بالذكاء الاصطناعي',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: GharsColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Diagnosis loading ────────────────────────────────────────
class _DiagnosisLoading extends StatelessWidget {
  const _DiagnosisLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GharsColors.charcoal800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GharsColors.charcoal700),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              color: GharsColors.gold,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'الذكاء الاصطناعي يحلل الصورة...',
            style: TextStyle(color: GharsColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Diagnosis result ─────────────────────────────────────────
class _DiagnosisResult extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DiagnosisResult({required this.data});

  @override
  Widget build(BuildContext context) {
    // API response shape:
    //   AUTO_APPLIED    → { decision, diagnosis: { nameAr, confidence, ... },
    //                       impact: { userMessage, ... }, recommendedActions? }
    //   NEEDS_CONFIRMATION → { decision, diagnosis, recommendedActions, impact }
    //   NEEDS_BETTER_PHOTO → { decision, guidance, confidence }
    //   error            → { error: "..." }

    final decision   = data['decision'] as String? ?? '';
    final errorMsg   = data['error'] as String?;

    final diagnosis  = data['diagnosis'] as Map<String, dynamic>?;
    final confidence = diagnosis?['confidence'] as num?;
    final nameAr     = diagnosis?['nameAr'] as String?;
    final severity   = diagnosis?['severity'] as String?;

    final impact      = data['impact'] as Map<String, dynamic>?;
    final userMessage = impact?['userMessage'] as String?;
    final guidance    = data['guidance'] as String?;

    final recommendedActions = (data['recommendedActions'] as List?)
        ?.map((e) => e.toString())
        .toList();

    // ── Choose styling by decision ───────────────────────────
    Color borderColor;
    String icon;
    String statusLabel;

    if (errorMsg != null) {
      borderColor = GharsColors.diseased;
      icon        = '❌';
      statusLabel = 'خطأ في التشخيص';
    } else if (decision == 'AUTO_APPLIED') {
      borderColor = GharsColors.healthy;
      icon        = '✅';
      statusLabel = 'تم تطبيق التشخيص تلقائياً';
    } else if (decision == 'NEEDS_CONFIRMATION') {
      borderColor = GharsColors.stressed;
      icon        = '⚠️';
      statusLabel = 'يحتاج تأكيدك';
    } else if (decision == 'NEEDS_BETTER_PHOTO') {
      borderColor = GharsColors.gold;
      icon        = '📷';
      statusLabel = 'يحتاج صورة أوضح';
    } else {
      borderColor = GharsColors.textMuted;
      icon        = '🔬';
      statusLabel = 'نتيجة التحليل';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GharsColors.charcoal800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: borderColor,
                  ),
                ),
              ),
              if (confidence != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(confidence * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: borderColor,
                    ),
                  ),
                ),
            ],
          ),

          // ── Diagnosis name ───────────────────────────────────
          if (nameAr != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    nameAr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GharsColors.textPrimary,
                    ),
                  ),
                ),
                if (severity != null)
                  _SeverityBadge(severity),
              ],
            ),
          ],

          // ── Error message ────────────────────────────────────
          if (errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMsg,
              style: const TextStyle(
                fontSize: 12,
                color: GharsColors.textSecondary,
              ),
            ),
          ],

          // ── User message / impact ────────────────────────────
          if (userMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              userMessage,
              style: const TextStyle(
                fontSize: 13,
                color: GharsColors.textSecondary,
              ),
            ),
          ],

          // ── Guidance for better photo ────────────────────────
          if (guidance != null) ...[
            const SizedBox(height: 6),
            Text(
              guidance,
              style: const TextStyle(
                fontSize: 13,
                color: GharsColors.textSecondary,
              ),
            ),
          ],

          // ── Recommended actions ──────────────────────────────
          if (recommendedActions != null && recommendedActions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'الإجراءات الموصى بها:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: GharsColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ...recommendedActions.take(4).map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: GharsColors.green,
                            fontWeight: FontWeight.w700)),
                    Expanded(
                      child: Text(
                        a,
                        style: const TextStyle(
                          fontSize: 12,
                          color: GharsColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge(this.severity);

  static const _labels = {
    'LOW':      'خفيف',
    'MEDIUM':   'متوسط',
    'HIGH':     'شديد',
    'CRITICAL': 'حرج',
  };

  static const _colors = {
    'LOW':      GharsColors.stressed,
    'MEDIUM':   GharsColors.stressed,
    'HIGH':     GharsColors.diseased,
    'CRITICAL': GharsColors.critical,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[severity] ?? severity;
    final color = _colors[severity] ?? GharsColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Diagnosis error ───────────────────────────────────────────
class _DiagnosisError extends StatelessWidget {
  final String message;
  const _DiagnosisError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GharsColors.charcoal800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GharsColors.diseased),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'خطأ في الاتصال: $message',
              style: const TextStyle(
                fontSize: 12,
                color: GharsColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Health log section ────────────────────────────────────────
class _HealthLogSection extends ConsumerWidget {
  final String plantId;
  final String gardenId;
  const _HealthLogSection({
    required this.plantId,
    required this.gardenId,
  });

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GharsColors.charcoal800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddHealthLogSheet(
        plantId:  plantId,
        gardenId: gardenId,
        onSaved: () {
          ref.invalidate(healthLogsProvider(plantId));
          ref.invalidate(plantsProvider(gardenId));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(healthLogsProvider(plantId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header (always visible) ──────────────────
        Row(
          children: [
            const Text('📋', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'سجل الصحة',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: GharsColors.textPrimary,
                ),
              ),
            ),
            // زر إضافة سجل يدوي
            GestureDetector(
              onTap: () => _showAddSheet(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: GharsColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: GharsColors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: GharsColors.green),
                    SizedBox(width: 3),
                    Text(
                      'تسجيل',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: GharsColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Log items ─────────────────────────────────────────
        logsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (logs) {
            if (logs.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: const Text(
                  'لا توجد سجلات صحية بعد — اضغط "تسجيل" للبدء',
                  style: TextStyle(
                    fontSize: 12,
                    color: GharsColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return Column(
              children: logs
                  .map((log) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _HealthLogTile(log: log),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Add Health Log sheet ───────────────────────────────────────
class _AddHealthLogSheet extends StatefulWidget {
  final String plantId;
  final String gardenId;
  final VoidCallback onSaved;

  const _AddHealthLogSheet({
    required this.plantId,
    required this.gardenId,
    required this.onSaved,
  });

  @override
  State<_AddHealthLogSheet> createState() => _AddHealthLogSheetState();
}

class _AddHealthLogSheetState extends State<_AddHealthLogSheet> {
  String _status  = 'HEALTHY';
  final _notesCtrl = TextEditingController();
  bool _loading   = false;
  String? _error;

  static const _statuses = [
    ('HEALTHY',    'بصحة جيدة',  '✅', GharsColors.healthy),
    ('STRESSED',   'متوتر',       '⚠️', GharsColors.stressed),
    ('DISEASED',   'مريض',        '🤒', GharsColors.diseased),
    ('RECOVERING', 'في التعافي', '💚', GharsColors.gold),
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });

    try {
      final res = await http.post(
        Uri.parse(
          '${AppConstants.apiBaseUrl}/api/gardens/${widget.gardenId}/plants/${widget.plantId}/health-log',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'healthStatus': _status,
          if (_notesCtrl.text.trim().isNotEmpty)
            'notes': _notesCtrl.text.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تسجيل حالة النبتة'),
            backgroundColor: GharsColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() =>
            _error = body['error']?.toString() ?? 'خطأ ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'تعذّر الاتصال: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16, left: 20, right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: GharsColors.charcoal600,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // title
          const Row(
            children: [
              Text('🌿', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'تسجيل حالة النبتة',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: GharsColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // label
          const Text(
            'الحالة الصحية',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: GharsColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // status 2×2 grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3.2,
            children: _statuses.map((s) {
              final (key, label, emoji, color) = s;
              final selected = _status == key;
              return GestureDetector(
                onTap: () => setState(() => _status = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.12)
                        : GharsColors.charcoal700,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected
                              ? color
                              : GharsColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // notes
          const Text(
            'ملاحظات (اختياري)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: GharsColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: const TextStyle(
                color: GharsColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'مثال: اصفرار في الأطراف، تربة جافة...',
              hintStyle: const TextStyle(
                  color: GharsColors.textMuted, fontSize: 12),
              filled: true,
              fillColor: GharsColors.charcoal700,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: GharsColors.green, width: 1.5),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                  color: GharsColors.diseased, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: GharsColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
                      'حفظ',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthLogTile extends StatelessWidget {
  final HealthLog log;
  const _HealthLogTile({required this.log});

  static const _categoryEmoji = {
    'FUNGAL_DISEASE':        '🍄',
    'BACTERIAL_DISEASE':     '🦠',
    'SPIDER_MITE':           '🕷️',
    'SCALE_INSECT':          '🐛',
    'MEALYBUG':              '🐜',
    'SALT_BURN':             '🧂',
    'ROOT_ROT':              '🌿',
    'NUTRIENT_DEF_NITROGEN': '🌿',
    'NUTRIENT_DEF_IRON':     '⚙️',
    'NUTRIENT_DEF_CALCIUM':  '🦴',
    'HEAT_STRESS':           '☀️',
    'OVERWATERING':          '💧',
    'UNDERWATERING':         '🏜️',
    'PRUNING_RECOVERY':      '✂️',
  };

  static const _severityColor = {
    'LOW':      GharsColors.stressed,
    'MEDIUM':   GharsColors.stressed,
    'HIGH':     GharsColors.diseased,
    'CRITICAL': GharsColors.critical,
  };

  static const _severityLabel = {
    'LOW':      'خفيف',
    'MEDIUM':   'متوسط',
    'HIGH':     'شديد',
    'CRITICAL': 'حرج',
  };

  @override
  Widget build(BuildContext context) {
    final color = _severityColor[log.severity] ?? GharsColors.textMuted;
    final emoji = _categoryEmoji[log.diagnosisCategory] ?? '🔬';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GharsColors.charcoal800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: log.isResolved
              ? GharsColors.charcoal700
              : color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // emoji
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: log.isResolved
                  ? GharsColors.charcoal700
                  : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // diagnosis name + severity
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.diagnosis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: log.isResolved
                              ? GharsColors.textSecondary
                              : GharsColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: log.isResolved
                            ? GharsColors.charcoal700
                            : color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        log.isResolved
                            ? '✓ تعافى'
                            : (_severityLabel[log.severity] ?? log.severity),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: log.isResolved ? GharsColors.green : color,
                        ),
                      ),
                    ),
                  ],
                ),

                // treatment
                if (log.treatment != null && log.treatment!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    log.treatment!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: GharsColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // date
                const SizedBox(height: 4),
                Text(
                  timeago.format(log.createdAt, locale: 'ar'),
                  style: const TextStyle(
                    fontSize: 10,
                    color: GharsColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit Plant bottom sheet ───────────────────────────────────
class _EditPlantSheet extends StatefulWidget {
  final Plant plant;
  final String gardenId;
  final VoidCallback onSaved;
  const _EditPlantSheet({
    required this.plant,
    required this.gardenId,
    required this.onSaved,
  });

  @override
  State<_EditPlantSheet> createState() => _EditPlantSheetState();
}

class _EditPlantSheetState extends State<_EditPlantSheet> {
  late final TextEditingController _nicknameCtrl;
  late String _location;
  bool _loading = false;
  String? _error;

  static const _locations = [
    ('INDOOR',     'داخلي',     '🏠'),
    ('OUTDOOR',    'خارجي',     '🌳'),
    ('BALCONY',    'شرفة',      '🏢'),
    ('GREENHOUSE', 'بيت زجاجي', '🌿'),
  ];

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController(text: widget.plant.nickname ?? '');
    _location = widget.plant.location;
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });

    try {
      final nickname = _nicknameCtrl.text.trim();
      final res = await http.patch(
        Uri.parse(
          '${AppConstants.apiBaseUrl}/api/gardens/${widget.gardenId}/plants/${widget.plant.id}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nickname': nickname.isEmpty ? null : nickname,
          'location': _location,
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200) {
        Navigator.pop(context); // close sheet
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ التعديلات'),
            backgroundColor: GharsColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _error = body['error']?.toString() ?? 'خطأ ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'تعذّر الاتصال: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16, left: 20, right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: GharsColors.charcoal600,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // title
          Row(
            children: [
              const Text('✏️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'تعديل — ${widget.plant.catalogNameAr}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: GharsColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // nickname field
          const Text(
            'الاسم المخصص (اختياري)',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: GharsColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nicknameCtrl,
            style: const TextStyle(color: GharsColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'مثال: وردة الشرفة، نعناع المطبخ',
              hintStyle:
                  const TextStyle(color: GharsColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: GharsColors.charcoal700,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: GharsColors.green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // location label
          const Text(
            'الموقع',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: GharsColors.textSecondary),
          ),
          const SizedBox(height: 8),

          // location chips
          Row(
            children: _locations.map((loc) {
              final (key, label, emoji) = loc;
              final selected = _location == key;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _location = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? GharsColors.green.withValues(alpha: 0.12)
                            : GharsColors.charcoal700,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              selected ? GharsColors.green : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 3),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selected
                                  ? GharsColors.green
                                  : GharsColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // error
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: GharsColors.diseased, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          // save button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: GharsColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white,
                      ),
                    )
                  : const Text(
                      'حفظ التعديلات',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Schedule chip ─────────────────────────────────────────────
class _ScheduleChip extends StatelessWidget {
  final int? intervalDays;
  final bool isManualOverride;
  final VoidCallback onTap;

  const _ScheduleChip({
    required this.intervalDays,
    required this.isManualOverride,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (intervalDays == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: GharsColors.charcoal800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isManualOverride
                ? GharsColors.gold.withValues(alpha: 0.5)
                : GharsColors.charcoal700,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isManualOverride
                  ? Icons.tune_rounded
                  : Icons.auto_awesome_rounded,
              size: 15,
              color: isManualOverride
                  ? GharsColors.gold
                  : GharsColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              isManualOverride
                  ? 'جدول يدوي: كل $intervalDays أيام'
                  : 'جدول تلقائي: كل $intervalDays أيام',
              style: TextStyle(
                fontSize: 12,
                color: isManualOverride
                    ? GharsColors.gold
                    : GharsColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              'تعديل',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isManualOverride
                    ? GharsColors.gold
                    : GharsColors.textMuted,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_left,
              size: 16,
              color: isManualOverride
                  ? GharsColors.gold
                  : GharsColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Schedule Override sheet ────────────────────────────────────
class _ScheduleOverrideSheet extends StatefulWidget {
  final Plant plant;
  final String gardenId;
  final VoidCallback onSaved;

  const _ScheduleOverrideSheet({
    required this.plant,
    required this.gardenId,
    required this.onSaved,
  });

  @override
  State<_ScheduleOverrideSheet> createState() =>
      _ScheduleOverrideSheetState();
}

class _ScheduleOverrideSheetState
    extends State<_ScheduleOverrideSheet> {
  late double _days;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _days = (widget.plant.wateringIntervalDays ?? 3).toDouble();
  }

  Future<void> _save({bool reset = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final body = reset
          ? {'reset': true}
          : {'intervalDays': _days.round()};

      final res = await http.patch(
        Uri.parse(
          '${AppConstants.apiBaseUrl}/api/gardens/${widget.gardenId}/plants/${widget.plant.id}/schedule',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reset
                ? '🔄 تم إعادة الجدول للحساب التلقائي'
                : '✅ تم ضبط جدول السقي: كل ${_days.round()} أيام'),
            backgroundColor: GharsColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() =>
            _error = b['error']?.toString() ?? 'خطأ ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'تعذّر الاتصال: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16, left: 20, right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: GharsColors.charcoal600,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // title
          Row(
            children: [
              const Text('⚙️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ضبط جدول السقي',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: GharsColors.textPrimary,
                  ),
                ),
              ),
              if (widget.plant.isManualOverride)
                TextButton(
                  onPressed: _loading ? null : () => _save(reset: true),
                  child: const Text(
                    'تلقائي',
                    style: TextStyle(
                      fontSize: 12,
                      color: GharsColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'الحديقة: ${widget.plant.catalogNameAr}',
            style: const TextStyle(
                fontSize: 12, color: GharsColors.textMuted),
          ),
          const SizedBox(height: 24),

          // slider
          Center(
            child: Text(
              'كل ${_days.round()} أيام',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: GharsColors.green,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   GharsColors.green,
              inactiveTrackColor: GharsColors.charcoal700,
              thumbColor:         GharsColors.green,
              overlayColor:
                  GharsColors.green.withValues(alpha: 0.1),
              valueIndicatorColor: GharsColors.green,
            ),
            child: Slider(
              value: _days,
              min: 1,
              max: 30,
              divisions: 29,
              label: '${_days.round()} أيام',
              onChanged: (v) => setState(() => _days = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('يوم', style: TextStyle(fontSize: 11, color: GharsColors.textMuted)),
              Text('30 يوم', style: TextStyle(fontSize: 11, color: GharsColors.textMuted)),
            ],
          ),
          const SizedBox(height: 6),

          // quick presets
          Wrap(
            spacing: 8,
            children: [2, 3, 5, 7, 10, 14].map((d) {
              final sel = _days.round() == d;
              return GestureDetector(
                onTap: () => setState(() => _days = d.toDouble()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel
                        ? GharsColors.green.withValues(alpha: 0.12)
                        : GharsColors.charcoal700,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          sel ? GharsColors.green : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '$d',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? GharsColors.green
                          : GharsColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    color: GharsColors.diseased, fontSize: 12),
                textAlign: TextAlign.center),
          ],

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _save(),
              style: ElevatedButton.styleFrom(
                backgroundColor: GharsColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white,
                      ),
                    )
                  : Text(
                      'حفظ — كل ${_days.round()} أيام',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image source tile ─────────────────────────────────────────
class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: GharsColors.charcoal700,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: GharsColors.gold, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: GharsColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
