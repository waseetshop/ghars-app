import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../models/garden.dart';
import '../../models/plant.dart';
import '../../providers/gardens_provider.dart';
import '../../providers/agricultural_star_provider.dart';
import '../../widgets/health_badge.dart';
import '../plant_detail/plant_detail_screen.dart';
import '../add_plant/add_plant_screen.dart';

const _irrigationTypes = [
  ('MANUAL',       'يدوي',         '🤲', 'تسقي بنفسك'),
  ('TIMER',        'مؤقت زراعي',  '⏱️', 'مؤقت بدون ذكاء'),
  ('SMART_TIMER',  'مؤقت ذكي',    '🤖', 'يدير الكل تلقائياً'),
];

const _climates = [
  ('HOT_ARID',      'حار جاف',   '☀️'),
  ('MEDITERRANEAN', 'متوسطي',    '🌊'),
  ('TROPICAL',      'استوائي',   '🌴'),
  ('TEMPERATE',     'معتدل',     '🌤️'),
];

const _durations = [5, 10, 15, 20, 30, 45, 60];

const _climateLabel = {
  'HOT_ARID':      'حار جاف',
  'MEDITERRANEAN': 'متوسطي',
  'TROPICAL':      'استوائي',
  'TEMPERATE':     'معتدل',
};

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showCreateGardenSheet(BuildContext context, WidgetRef ref,
      {String type = 'GARDEN'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GharsColors.charcoal800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateGardenSheet(
        initialType: type,
        onCreated: (gardenId) {
          ref.invalidate(gardensProvider);

          // الأصيص: انتقل مباشرة لإضافة النبتة بعد إغلاق الـ sheet
          if (type == 'POT') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddPlantScreen(gardenId: gardenId),
                  ),
                ).then((_) => ref.invalidate(plantsProvider(gardenId)));
              }
            });
          }
        },
      ),
    );
  }

  void _pickCreateType(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GharsColors.charcoal800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: GharsColors.charcoal600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ماذا تريد أن تُضيف؟',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: GharsColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _TypeTile(
                    emoji: '🏡',
                    title: 'حديقة',
                    subtitle: 'نباتات متعددة',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCreateGardenSheet(context, ref, type: 'GARDEN');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeTile(
                    emoji: '🪴',
                    title: 'أصيص / حوض',
                    subtitle: 'نبتة واحدة',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCreateGardenSheet(context, ref, type: 'POT');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gardensAsync = ref.watch(gardensProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickCreateType(context, ref),
        backgroundColor: GharsColors.gold,
        foregroundColor: GharsColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'إضافة حديقة',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: GharsColors.charcoal900,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 32,
                  width: 32,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                const Text(
                  'غَرْس',
                  style: TextStyle(
                    color: GharsColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: GharsColors.textMuted, size: 20),
                tooltip: 'تسجيل الخروج',
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  // GoRouter redirect يتكفّل بالانتقال لشاشة الدخول تلقائياً
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: GharsColors.charcoal700),
            ),
          ),

          // ── Star widget ──────────────────────────────────────
          const SliverToBoxAdapter(child: _TodayStarCard()),

          // ── Content ──────────────────────────────────────────
          gardensAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: GharsColors.gold,
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 8),
                    const Text(
                      'خطأ في تحميل البيانات',
                      style: TextStyle(color: GharsColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.toString(),
                      style: const TextStyle(
                        color: GharsColors.textMuted,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            data: (gardens) {
              if (gardens.isEmpty) {
                return const SliverFillRemaining(child: _EmptyState());
              }
              final gardenList = gardens.where((g) => g.isGarden).toList();
              final potList    = gardens.where((g) => g.isPot).toList();
              return _GardenSections(
                gardens: gardenList,
                pots:    potList,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Garden card ───────────────────────────────────────────────
class _GardenCard extends ConsumerWidget {
  final Garden garden;
  const _GardenCard({required this.garden});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GharsColors.charcoal800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الحديقة',
            style: TextStyle(color: GharsColors.textPrimary, fontSize: 17)),
        content: Text(
          'سيُحذف "${garden.name}" مع جميع نباتاتها. لا يمكن التراجع.',
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
                    color: GharsColors.diseased,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final res = await http.delete(
      Uri.parse('${AppConstants.apiBaseUrl}/api/gardens/${garden.id}'),
      headers: {
        'Content-Type': 'application/json',
        'x-user-id': userId,
      },
    ).timeout(const Duration(seconds: 15));

    if (!context.mounted) return;
    if (res.statusCode == 200) {
      ref.invalidate(gardensProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🗑️ تم حذف "${garden.name}"'),
        backgroundColor: const Color.fromRGBO(199, 109, 89, 1),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('فشل الحذف، حاول مجدداً'),
        backgroundColor: const Color.fromRGBO(199, 109, 89, 1),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _edit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GharsColors.charcoal800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditGardenSheet(
        garden: garden,
        onUpdated: () => ref.invalidate(gardensProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(gardenPlantCountProvider(garden.id));

    // badge لنوع السقي
    Widget? irrigationBadge;
    if (garden.hasTimer) {
      irrigationBadge = _Chip(
        garden.isSmartTimer ? '🤖 ذكي' : '⏱️ مؤقت',
        color: GharsColors.green,
      );
    }

    return GestureDetector(
      onTap: () => context.push(
        '/garden/${garden.id}?name=${Uri.encodeComponent(garden.name)}',
      ),
      child: Container(
        decoration: BoxDecoration(
          color: GharsColors.charcoal800,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GharsColors.charcoal700),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: GharsColors.charcoal700,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🏡', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 12),

            // info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    garden.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: GharsColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Chip(_climateLabel[garden.climate] ?? garden.climate),
                      const SizedBox(width: 6),
                      countAsync.when(
                        data: (n) => _Chip('$n نبتة', color: GharsColors.gold),
                        loading: () => const SizedBox.shrink(),
                        error: (e, s) => const SizedBox.shrink(),
                      ),
                      if (irrigationBadge != null) ...[
                        const SizedBox(width: 6),
                        irrigationBadge,
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // popup menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: GharsColors.textMuted, size: 20),
              color: GharsColors.charcoal700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'edit')   _edit(context, ref);
                if (v == 'delete') _delete(context, ref);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined,
                        size: 16, color: GharsColors.textSecondary),
                    SizedBox(width: 8),
                    Text('تعديل',
                        style: TextStyle(
                            color: GharsColors.textPrimary, fontSize: 13)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 16, color: GharsColors.diseased),
                    SizedBox(width: 8),
                    Text('حذف',
                        style: TextStyle(
                            color: GharsColors.diseased, fontSize: 13)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  const _Chip(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: GharsColors.charcoal700,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color ?? GharsColors.textSecondary,
          fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Text('🌱', style: TextStyle(fontSize: 56)),
        SizedBox(height: 12),
        Text(
          'لا توجد حدائق بعد',
          style: TextStyle(
            color: GharsColors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'أضف حديقتك الأولى للبدء',
          style: TextStyle(color: GharsColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}

// ── Create Garden bottom sheet ────────────────────────────────
class _CreateGardenSheet extends StatefulWidget {
  final void Function(String gardenId) onCreated;
  final String initialType;   // 'GARDEN' | 'POT'
  const _CreateGardenSheet({
    required this.onCreated,
    this.initialType = 'GARDEN',
  });

  @override
  State<_CreateGardenSheet> createState() => _CreateGardenSheetState();
}

class _CreateGardenSheetState extends State<_CreateGardenSheet> {
  // ── Step 0: basic info ─────────────────────────────────────
  final _nameCtrl = TextEditingController();
  String _climate = 'HOT_ARID';

  // ── Step 1: irrigation ─────────────────────────────────────
  String _irrigationType    = 'MANUAL';
  int    _timerDurationMin  = 10;
  int    _timerTimesPerDay  = 1;
  int    _timerIntervalDays = 1;
  final List<TimeOfDay> _timerTimes = [const TimeOfDay(hour: 7, minute: 0)];

  int    _step    = 0;
  bool   _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timerTimes[index],
    );
    if (picked != null) {
      setState(() => _timerTimes[index] = picked);
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'يرجى إدخال اسم الحديقة');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final isPot = widget.initialType == 'POT';
      final body = <String, dynamic>{
        'name':            name,
        'type':            widget.initialType,
        'climate':         _climate,
        'irrigationType':  isPot ? 'MANUAL' : _irrigationType,
      };

      if (!isPot && _irrigationType != 'MANUAL') {
        body['timerDurationMin']  = _timerDurationMin;
        body['timerTimesPerDay']  = _timerTimesPerDay;
        body['timerIntervalDays'] = _timerIntervalDays;
        body['timerTimes']        = _timerTimes
            .take(_timerTimesPerDay)
            .map(_formatTime)
            .toList();
      }

      final res = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/gardens'),
        headers: {'Content-Type': 'application/json', 'x-user-id': userId},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 201) {
        final respBody = jsonDecode(res.body) as Map<String, dynamic>;
        final gardenId =
            (respBody['data'] as Map<String, dynamic>)['id'] as String;
        widget.onCreated(gardenId);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialType == 'POT'
                ? '🪴 تمت إضافة الأصيص "$name" — أضف نبتتك الآن'
                : '🌱 تمت إضافة الحديقة "$name" بنجاح'),
            backgroundColor: GharsColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _error = b['error']?.toString() ?? 'خطأ ${res.statusCode}');
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: GharsColors.charcoal600,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),

            // step indicator
            Row(
              children: [
                _StepDot(
                  active: _step == 0,
                  done: _step > 0,
                  label: 'معلومات',
                  onTap: _step > 0 ? () => setState(() => _step = 0) : null,
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(height: 1, color: GharsColors.charcoal700),
                      if (_step > 0)
                        Container(height: 1, color: GharsColors.green),
                    ],
                  ),
                ),
                _StepDot(
                  active: _step == 1,
                  done: false,
                  label: 'نظام السقي',
                  onTap: _nameCtrl.text.trim().isNotEmpty
                      ? () => setState(() => _step = 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Step 0: Basic info ──────────────────────────
            if (_step == 0) ...[
              Text(
                widget.initialType == 'POT' ? '🪴 أصيص جديد' : '🏡 حديقة جديدة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: GharsColors.textPrimary,
                ),
              ),
              const SizedBox(height: 18),

              // name
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                style: const TextStyle(
                    color: GharsColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'مثال: حديقة المنزل، شرفة الطابق الثالث',
                  hintStyle: const TextStyle(
                      color: GharsColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.local_florist_outlined,
                      color: GharsColors.textMuted, size: 20),
                  filled: true,
                  fillColor: GharsColors.charcoal700,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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
              const SizedBox(height: 16),

              // climate
              const Text(
                'نوع المناخ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: GharsColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _climates.map((c) {
                  final (key, label, emoji) = c;
                  final selected = _climate == key;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _climate = key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? GharsColors.green.withValues(alpha: 0.12)
                                : GharsColors.charcoal700,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? GharsColors.green
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(emoji,
                                  style: const TextStyle(fontSize: 18)),
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
              const SizedBox(height: 20),

              // next / create button (POT skips irrigation step)
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (_nameCtrl.text.trim().isEmpty) {
                      setState(() => _error = 'يرجى إدخال اسم');
                      return;
                    }
                    if (widget.initialType == 'POT') {
                      _create(); // أصيص: يُنشأ مباشرة بدون خطوة السقي
                    } else {
                      setState(() { _step = 1; _error = null; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GharsColors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: widget.initialType == 'POT'
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('إضافة الأصيص',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('التالي: نظام السقي',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          ],
                        ),
                ),
              ),
            ],

            // ── Step 1: Irrigation ──────────────────────────
            if (_step == 1) ...[
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _step = 0),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_rounded,
                            size: 14, color: GharsColors.textMuted),
                        SizedBox(width: 2),
                        Text('رجوع',
                            style: TextStyle(
                                fontSize: 12,
                                color: GharsColors.textMuted)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '💧 نظام السقي',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GharsColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'كيف تروي هذه الحديقة؟',
                style: TextStyle(
                    fontSize: 13, color: GharsColors.textMuted),
                textAlign: TextAlign.end,
              ),
              const SizedBox(height: 16),

              // irrigation type cards
              ...(_irrigationTypes.map((t) {
                final (key, label, emoji, desc) = t;
                final selected = _irrigationType == key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _irrigationType = key;
                      // ضبط عدد الأوقات حسب timerTimesPerDay
                      while (_timerTimes.length < _timerTimesPerDay) {
                        _timerTimes.add(const TimeOfDay(hour: 18, minute: 0));
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? GharsColors.green.withValues(alpha: 0.08)
                            : GharsColors.charcoal700,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? GharsColors.green
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(emoji,
                              style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? GharsColors.green
                                        : GharsColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: GharsColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                color: GharsColors.green, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              })),

              // timer details (if TIMER or SMART_TIMER)
              if (_irrigationType != 'MANUAL') ...[
                const SizedBox(height: 12),
                const Divider(color: GharsColors.charcoal700),
                const SizedBox(height: 12),

                // duration
                _SettingRow(
                  label: 'مدة كل جلسة',
                  child: Wrap(
                    spacing: 6,
                    children: _durations.map((d) {
                      final sel = _timerDurationMin == d;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _timerDurationMin = d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel
                                ? GharsColors.gold.withValues(alpha: 0.15)
                                : GharsColors.charcoal700,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel
                                  ? GharsColors.gold
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '$d د',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: sel
                                  ? GharsColors.gold
                                  : GharsColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // times per day
                _SettingRow(
                  label: 'مرات في اليوم',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [1, 2, 3].map((n) {
                      final sel = _timerTimesPerDay == n;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _timerTimesPerDay = n;
                              while (_timerTimes.length < n) {
                                _timerTimes.add(
                                    const TimeOfDay(hour: 18, minute: 0));
                              }
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sel
                                  ? GharsColors.green
                                      .withValues(alpha: 0.15)
                                  : GharsColors.charcoal700,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? GharsColors.green
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              '$n×',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: sel
                                    ? GharsColors.green
                                    : GharsColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // watering times
                _SettingRow(
                  label: 'أوقات السقي',
                  child: Wrap(
                    spacing: 8,
                    children: List.generate(
                      _timerTimesPerDay,
                      (i) {
                        final t = _timerTimes.length > i
                            ? _timerTimes[i]
                            : const TimeOfDay(hour: 7, minute: 0);
                        return GestureDetector(
                          onTap: () => _pickTime(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: GharsColors.green
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: GharsColors.green
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 14,
                                    color: GharsColors.green),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(t),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: GharsColors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // interval days
                _SettingRow(
                  label: 'كل كم يوم',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [1, 2, 3, 4].map((d) {
                      final sel = _timerIntervalDays == d;
                      final lbl = d == 1 ? 'يومياً' : 'كل $d أيام';
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _timerIntervalDays = d),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel
                                  ? GharsColors.gold
                                      .withValues(alpha: 0.12)
                                  : GharsColors.charcoal700,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: sel
                                    ? GharsColors.gold
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              lbl,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: sel
                                    ? GharsColors.gold
                                    : GharsColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

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

              // submit button
              SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [GharsColors.goldDim, GharsColors.gold],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: GharsColors.textPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: GharsColors.textPrimary,
                            ),
                          )
                        : const Text(
                            'إضافة الحديقة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Edit Garden bottom sheet ──────────────────────────────────
class _EditGardenSheet extends StatefulWidget {
  final Garden garden;
  final VoidCallback onUpdated;
  const _EditGardenSheet({required this.garden, required this.onUpdated});

  @override
  State<_EditGardenSheet> createState() => _EditGardenSheetState();
}

class _EditGardenSheetState extends State<_EditGardenSheet> {
  late final TextEditingController _nameCtrl;
  late String _climate;
  late String _irrigationType;
  late int    _timerDurationMin;
  late int    _timerTimesPerDay;
  late int    _timerIntervalDays;
  late final List<TimeOfDay> _timerTimes;

  bool   _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final g = widget.garden;
    _nameCtrl        = TextEditingController(text: g.name);
    _climate         = g.climate;
    _irrigationType  = g.irrigationType;
    _timerDurationMin  = g.timerDurationMin  ?? 10;
    _timerTimesPerDay  = g.timerTimesPerDay  ?? 1;
    _timerIntervalDays = g.timerIntervalDays ?? 1;
    _timerTimes = g.timerTimes.map((t) {
      final parts = t.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }).toList();
    if (_timerTimes.isEmpty) {
      _timerTimes.add(const TimeOfDay(hour: 7, minute: 0));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timerTimes.length > index
          ? _timerTimes[index]
          : const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null) setState(() => _timerTimes[index] = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'يرجى إدخال اسم الحديقة');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final body = <String, dynamic>{
        'name':          name,
        'climate':       _climate,
        'irrigationType': _irrigationType,
      };
      if (_irrigationType != 'MANUAL') {
        body['timerDurationMin']  = _timerDurationMin;
        body['timerTimesPerDay']  = _timerTimesPerDay;
        body['timerIntervalDays'] = _timerIntervalDays;
        body['timerTimes']        = _timerTimes
            .take(_timerTimesPerDay)
            .map(_formatTime)
            .toList();
      } else {
        body['timerDurationMin']  = null;
        body['timerTimesPerDay']  = null;
        body['timerIntervalDays'] = null;
        body['timerTimes']        = <String>[];
      }

      final res = await http.patch(
        Uri.parse('${AppConstants.apiBaseUrl}/api/gardens/${widget.garden.id}'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (res.statusCode == 200) {
        widget.onUpdated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ تم تحديث "$name"'),
          backgroundColor: GharsColors.green,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _error = b['error']?.toString() ?? 'خطأ ${res.statusCode}');
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: GharsColors.charcoal600,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Text('✏️ تعديل الحديقة',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GharsColors.textPrimary)),
            const SizedBox(height: 18),

            // الاسم
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: GharsColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'اسم الحديقة',
                hintStyle: const TextStyle(color: GharsColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.local_florist_outlined,
                    color: GharsColors.textMuted, size: 20),
                filled: true,
                fillColor: GharsColors.charcoal700,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
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
            const SizedBox(height: 16),

            // المناخ
            const Text('نوع المناخ',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: GharsColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: _climates.map((c) {
                final (key, label, emoji) = c;
                final selected = _climate == key;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _climate = key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? GharsColors.green.withValues(alpha: 0.12)
                              : GharsColors.charcoal700,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? GharsColors.green
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(emoji,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 3),
                            Text(label,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: selected
                                        ? GharsColors.green
                                        : GharsColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // نظام السقي
            const Divider(color: GharsColors.charcoal700),
            const SizedBox(height: 12),
            const Text('💧 نظام السقي',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GharsColors.textPrimary)),
            const SizedBox(height: 12),
            ...(_irrigationTypes.map((t) {
              final (key, label, emoji, desc) = t;
              final selected = _irrigationType == key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _irrigationType = key;
                    while (_timerTimes.length < _timerTimesPerDay) {
                      _timerTimes.add(const TimeOfDay(hour: 18, minute: 0));
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? GharsColors.green.withValues(alpha: 0.08)
                          : GharsColors.charcoal700,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? GharsColors.green
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? GharsColors.green
                                          : GharsColors.textPrimary)),
                              Text(desc,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: GharsColors.textMuted)),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle_rounded,
                              color: GharsColors.green, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            })),

            // timer details
            if (_irrigationType != 'MANUAL') ...[
              const SizedBox(height: 12),
              const Divider(color: GharsColors.charcoal700),
              const SizedBox(height: 12),
              _SettingRow(
                label: 'مدة كل جلسة',
                child: Wrap(
                  spacing: 6,
                  children: _durations.map((d) {
                    final sel = _timerDurationMin == d;
                    return GestureDetector(
                      onTap: () => setState(() => _timerDurationMin = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel
                              ? GharsColors.gold.withValues(alpha: 0.15)
                              : GharsColors.charcoal700,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? GharsColors.gold : Colors.transparent,
                          ),
                        ),
                        child: Text('$d د',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: sel
                                    ? GharsColors.gold
                                    : GharsColors.textSecondary)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              _SettingRow(
                label: 'مرات في اليوم',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [1, 2, 3].map((n) {
                    final sel = _timerTimesPerDay == n;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _timerTimesPerDay = n;
                            while (_timerTimes.length < n) {
                              _timerTimes
                                  .add(const TimeOfDay(hour: 18, minute: 0));
                            }
                          });
                        },
                        child: Container(
                          width: 40, height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel
                                ? GharsColors.green.withValues(alpha: 0.15)
                                : GharsColors.charcoal700,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel
                                  ? GharsColors.green
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text('$n×',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: sel
                                      ? GharsColors.green
                                      : GharsColors.textSecondary)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              _SettingRow(
                label: 'أوقات السقي',
                child: Wrap(
                  spacing: 8,
                  children: List.generate(_timerTimesPerDay, (i) {
                    final t = _timerTimes.length > i
                        ? _timerTimes[i]
                        : const TimeOfDay(hour: 7, minute: 0);
                    return GestureDetector(
                      onTap: () => _pickTime(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color:
                              GharsColors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: GharsColors.green
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 14, color: GharsColors.green),
                            const SizedBox(width: 4),
                            Text(_formatTime(t),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: GharsColors.green)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              _SettingRow(
                label: 'كل كم يوم',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [1, 2, 3, 4].map((d) {
                    final sel = _timerIntervalDays == d;
                    final lbl = d == 1 ? 'يومياً' : 'كل $d أيام';
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _timerIntervalDays = d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? GharsColors.gold.withValues(alpha: 0.12)
                                : GharsColors.charcoal700,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel
                                  ? GharsColors.gold
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(lbl,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: sel
                                      ? GharsColors.gold
                                      : GharsColors.textSecondary)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      color: GharsColors.diseased, fontSize: 12),
                  textAlign: TextAlign.center),
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
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('حفظ التغييرات',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step dot indicator ─────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final bool active;
  final bool done;
  final String label;
  final VoidCallback? onTap;
  const _StepDot({
    required this.active,
    required this.done,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? GharsColors.green
        : done
            ? GharsColors.green
            : GharsColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: (active || done)
                  ? GharsColors.green.withValues(alpha: 0.15)
                  : GharsColors.charcoal700,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, size: 14, color: GharsColors.green)
                  : Icon(
                      active ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: color,
                    ),
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

// ── Setting row ────────────────────────────────────────────────
class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _SettingRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: GharsColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// 🌟  Today Star Card — الروزنامة الزراعية الفلكية
// ══════════════════════════════════════════════════════════════════
class _TodayStarCard extends ConsumerStatefulWidget {
  const _TodayStarCard();

  @override
  ConsumerState<_TodayStarCard> createState() => _TodayStarCardState();
}

class _TodayStarCardState extends ConsumerState<_TodayStarCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final starAsync = ref.watch(todayStarProvider);

    return starAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (e, _) => const SizedBox.shrink(),
      data: (star) {
        if (star == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _seasonColor(star.seasonOrder).withValues(alpha: 0.18),
                    GharsColors.charcoal800,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _seasonColor(star.seasonOrder).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  // ── Header row ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text(star.seasonEmoji,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '🌟 نجم اليوم: ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: GharsColors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    star.nameAr,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _seasonColor(star.seasonOrder),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _seasonColor(star.seasonOrder)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      star.season,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _seasonColor(star.seasonOrder),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _StarProgressBar(
                                daysInto:     star.daysIntoStar,
                                durationDays: star.durationDays,
                                color:        _seasonColor(star.seasonOrder),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            Text(
                              '${star.daysRemaining + 1}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _seasonColor(star.seasonOrder),
                              ),
                            ),
                            const Text(
                              'يوم',
                              style: TextStyle(
                                fontSize: 10,
                                color: GharsColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: GharsColors.textMuted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),

                  // ── Expanded detail ───────────────────────────
                  if (_expanded) ...[
                    Divider(
                      height: 1,
                      color: _seasonColor(star.seasonOrder).withValues(alpha: 0.2),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StarSection(
                            icon: '🌤️',
                            title: 'الطقس',
                            text: star.weatherDescription,
                          ),
                          const SizedBox(height: 10),
                          _StarSection(
                            icon: '🌱',
                            title: 'نصيحة الزراعة',
                            text: star.plantingAdvice,
                          ),
                          if (star.generalAdvice != null) ...[
                            const SizedBox(height: 10),
                            _StarSection(
                              icon: '💡',
                              title: 'ملاحظة عامة',
                              text: star.generalAdvice!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _seasonColor(int order) => switch (order) {
    1 => const Color(0xFF64B5F6), // أزرق — شتاء
    2 => const Color(0xFFA5D6A7), // أخضر — ربيع
    3 => const Color(0xFFFFB74D), // برتقالي — صيف
    4 => const Color(0xFFFF8A65), // برتقالي داكن — خريف
    _ => GharsColors.gold,
  };
}

class _StarProgressBar extends StatelessWidget {
  final int   daysInto;
  final int   durationDays;
  final Color color;
  const _StarProgressBar({
    required this.daysInto,
    required this.durationDays,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (daysInto + 1) / durationDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'اليوم ${daysInto + 1} من $durationDays',
          style: const TextStyle(
            fontSize: 10,
            color: GharsColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _StarSection extends StatelessWidget {
  final String icon;
  final String title;
  final String text;
  const _StarSection({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: GharsColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: GharsColors.textPrimary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}


// ══════════════════════════════════════════════════════════════════
// قسما الشاشة الرئيسية: حدائق + أصايص
// ══════════════════════════════════════════════════════════════════
class _GardenSections extends ConsumerWidget {
  final List<Garden> gardens;
  final List<Garden> pots;
  const _GardenSections({required this.gardens, required this.pots});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (gardens.isNotEmpty) ...[
            _SectionHeader(emoji: '🏡', title: 'حدائقي', count: gardens.length),
            const SizedBox(height: 8),
            ...gardens.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GardenCard(garden: g),
            )),
            if (pots.isNotEmpty) const SizedBox(height: 8),
          ],
          if (pots.isNotEmpty) ...[
            _SectionHeader(emoji: '🪴', title: 'أصاصيصي', count: pots.length),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   2,
                crossAxisSpacing: 12,
                mainAxisSpacing:  12,
                childAspectRatio: 0.85,
              ),
              itemCount: pots.length,
              itemBuilder: (_, i) => _PotCard(garden: pots[i]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── عنوان القسم ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final int    count;
  const _SectionHeader({
    required this.emoji,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: GharsColors.textSecondary)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
              color: GharsColors.charcoal700,
              borderRadius: BorderRadius.circular(20)),
          child: Text(
            '$count',
            style: const TextStyle(
                fontSize: 11,
                color: GharsColors.textMuted,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── بطاقة أصيص — تعرض النبتة مباشرة ──────────────────────────────
class _PotCard extends ConsumerWidget {
  final Garden garden;
  const _PotCard({required this.garden});

  static String _wateringLabel(DateTime? next) {
    if (next == null) return '—';
    final diff = next.difference(DateTime.now());
    if (diff.isNegative) return 'حان الري';
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'غداً';
    return 'خلال ${diff.inDays}د';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantsAsync = ref.watch(plantsProvider(garden.id));

    return plantsAsync.when(
      loading: () => _shell(
        context, ref, null,
        body: const Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: GharsColors.gold),
          ),
        ),
      ),
      error: (e, _) => _shell(context, ref, null, body: _emptyBody()),
      data: (plants) {
        final plant = plants.isEmpty ? null : plants.first;
        return _shell(
          context, ref, plant,
          body: plant != null ? _plantBody(plant) : _emptyBody(),
        );
      },
    );
  }

  // ── القشرة الخارجية للبطاقة ──────────────────────────────────
  Widget _shell(BuildContext context, WidgetRef ref, Plant? plant,
      {required Widget body}) {
    return GestureDetector(
      onTap: () async {
        if (plant != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PlantDetailScreen(plant: plant, gardenId: garden.id),
            ),
          );
          ref.invalidate(plantsProvider(garden.id));
        } else {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddPlantScreen(gardenId: garden.id),
            ),
          );
          if (added == true) ref.invalidate(plantsProvider(garden.id));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: GharsColors.charcoal800,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GharsColors.charcoal700),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── رأس: أيقونة + اسم الأصيص + قائمة ─────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('🪴', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    garden.name,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GharsColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _GardenPopupMenu(garden: garden),
              ],
            ),
            const SizedBox(height: 8),
            // ── فاصل ─────────────────────────────────────────
            Container(height: 1, color: GharsColors.charcoal700),
            const SizedBox(height: 8),
            // ── جسم البطاقة (نبتة أو فارغة) ──────────────────
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  // ── جسم: عندما توجد نبتة ──────────────────────────────────────
  Widget _plantBody(Plant plant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plant.displayName,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: GharsColors.textPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        HealthBadge(plant.healthStatus),
        const Spacer(),
        // موعد الري
        Row(
          children: [
            const Text('💧', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _wateringLabel(plant.nextWatering),
                style: const TextStyle(
                    fontSize: 11,
                    color: GharsColors.textSecondary,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── جسم: عندما لا توجد نبتة ───────────────────────────────────
  Widget _emptyBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: GharsColors.greenFaint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 13, color: GharsColors.green),
              SizedBox(width: 4),
              Text('أضف نبتة',
                  style: TextStyle(
                      fontSize: 11,
                      color: GharsColors.green,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── قائمة popup مشتركة ─────────────────────────────────────────────
class _GardenPopupMenu extends ConsumerWidget {
  final Garden garden;
  const _GardenPopupMenu({required this.garden});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          color: GharsColors.textMuted, size: 18),
      color: GharsColors.charcoal700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) async {
        if (v == 'edit') {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: GharsColors.charcoal800,
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => _EditGardenSheet(
                garden:    garden,
                onUpdated: () => ref.invalidate(gardensProvider)),
          );
        } else if (v == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: GharsColors.charcoal800,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('حذف ${garden.typeLabel}',
                  style: const TextStyle(
                      color: GharsColors.textPrimary, fontSize: 17)),
              content: Text(
                  'سيُحذف "${garden.name}" مع جميع نباتاته. لا يمكن التراجع.',
                  style: const TextStyle(
                      color: GharsColors.textSecondary, fontSize: 13)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء',
                        style: TextStyle(color: GharsColors.textMuted))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('حذف',
                        style: TextStyle(
                            color: GharsColors.diseased,
                            fontWeight: FontWeight.w700))),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          final userId = Supabase.instance.client.auth.currentUser!.id;
          final res = await http.delete(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/api/gardens/${garden.id}'),
            headers: {
              'Content-Type': 'application/json',
              'x-user-id': userId,
            },
          ).timeout(const Duration(seconds: 15));
          if (context.mounted && res.statusCode == 200) {
            ref.invalidate(gardensProvider);
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            const Icon(Icons.edit_rounded,
                color: GharsColors.textSecondary, size: 16),
            const SizedBox(width: 8),
            const Text('تعديل',
                style: TextStyle(
                    color: GharsColors.textPrimary, fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline_rounded,
                color: GharsColors.diseased, size: 16),
            const SizedBox(width: 8),
            const Text('حذف',
                style:
                    TextStyle(color: GharsColors.diseased, fontSize: 13)),
          ]),
        ),
      ],
    );
  }
}

// ── بطاقة اختيار نوع الإنشاء ─────────────────────────────────────
class _TypeTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _TypeTile({
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: GharsColors.charcoal700,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GharsColors.charcoal600),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: GharsColors.textPrimary)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: GharsColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
