import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../models/catalog_item.dart';
import '../../providers/gardens_provider.dart';
import '../../widgets/catalog_detail_sheet.dart';

// ── Categories ────────────────────────────────────────────────
const _categories = [
  ('ALL',        'الكل',       '🌿'),
  ('INDOOR',     'داخلية',     '🪴'),
  ('SUCCULENT',  'عُصاريات',   '🌵'),
  ('ORNAMENTAL', 'زينة',       '🌺'),
  ('HERB',       'أعشاب',      '🌿'),
  ('VEGETABLE',  'خضروات',     '🥬'),
  ('FRUIT_TREE', 'أشجار',      '🌳'),
];

const _categoryEmoji = {
  'FRUIT_TREE': '🌳',
  'VEGETABLE':  '🥬',
  'HERB':       '🌿',
  'ORNAMENTAL': '🌺',
  'INDOOR':     '🪴',
  'SUCCULENT':  '🌵',
};

// ── Location / PotSize options ────────────────────────────────
const _locations = [
  ('OUTDOOR',     'خارجي',      Icons.wb_sunny_outlined),
  ('INDOOR',      'داخلي',      Icons.home_outlined),
  ('BALCONY',     'شرفة',       Icons.balcony_outlined),
  ('GREENHOUSE',  'بيت زجاجي',  Icons.grass_outlined),
];

const _potSizes = [
  ('SMALL',  'صغير'),
  ('MEDIUM', 'وسط'),
  ('LARGE',  'كبير'),
  ('XLARGE', 'كبير جداً'),
];

// ═══════════════════════════════════════════════════════════════
class AddPlantScreen extends ConsumerStatefulWidget {
  final String gardenId;
  const AddPlantScreen({super.key, required this.gardenId});

  @override
  ConsumerState<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends ConsumerState<AddPlantScreen> {
  int _step = 0; // 0 = catalog, 1 = details

  CatalogItem? _selected;
  String _search      = '';
  String _filterCat   = 'ALL';
  String _location    = 'OUTDOOR';
  String _potSize     = 'MEDIUM';
  final _nicknameCtrl = TextEditingController();
  bool _saving        = false;

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _saving = true);

    try {
      final res = await http.post(
        Uri.parse(
          '${AppConstants.apiBaseUrl}/api/gardens/${widget.gardenId}/plants',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'catalogId': _selected!.id,
          'location':  _location,
          'potSize':   _potSize,
          'soilType':  'MIXED',
          'nickname':  _nicknameCtrl.text.trim().isEmpty
              ? null
              : _nicknameCtrl.text.trim(),
          'plantedAt': DateTime.now().toIso8601String(),
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        ref.invalidate(plantsProvider(widget.gardenId));
        ref.invalidate(gardenPlantCountProvider(widget.gardenId));
        Navigator.pop(context, true);
      } else {
        String errorMsg;
        try {
          final errBody = jsonDecode(res.body) as Map<String, dynamic>;
          errorMsg = errBody['error']?.toString() ?? 'خطأ ${res.statusCode}';
        } catch (_) {
          errorMsg = 'خطأ ${res.statusCode}';
        }
        _showError(errorMsg);
      }
    } catch (e) {
      _showError('تعذّر الاتصال: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('خطأ في إضافة النبتة',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: GharsColors.textPrimary)),
        content: Text(msg,
            style: const TextStyle(color: GharsColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً',
                style: TextStyle(color: GharsColors.green)),
          ),
        ],
        backgroundColor: GharsColors.charcoal800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _openDetailSheet(CatalogItem item) {
    CatalogDetailSheet.show(
      context,
      item,
      onAdd: () {
        Navigator.pop(context); // close sheet
        setState(() {
          _selected = item;
          _step     = 1;
        });
      },
    );
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GharsColors.charcoal900,
      appBar: AppBar(
        backgroundColor: GharsColors.charcoal900,
        surfaceTintColor: Colors.transparent,
        title: Text(_step == 0 ? 'اختر النبتة' : 'تفاصيل النبتة'),
        leading: IconButton(
          icon: Icon(
            _step == 0 ? Icons.close : Icons.arrow_back_ios,
            size: 20,
          ),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: GharsColors.charcoal700),
        ),
      ),
      body: _step == 0
          ? _CatalogStep(
              search:    _search,
              filterCat: _filterCat,
              onSearch:  (v) => setState(() => _search = v),
              onFilter:  (v) => setState(() => _filterCat = v),
              onTap:     _openDetailSheet,
            )
          : _DetailsStep(
              selected:     _selected!,
              location:     _location,
              potSize:      _potSize,
              nicknameCtrl: _nicknameCtrl,
              saving:       _saving,
              onLocation:   (v) => setState(() => _location = v),
              onPotSize:    (v) => setState(() => _potSize = v),
              onSave:       _save,
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STEP 1 — Catalog with category filter
// ══════════════════════════════════════════════════════════════
class _CatalogStep extends ConsumerWidget {
  final String search;
  final String filterCat;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;
  final ValueChanged<CatalogItem> onTap;

  const _CatalogStep({
    required this.search,
    required this.filterCat,
    required this.onSearch,
    required this.onFilter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: onSearch,
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: GharsColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث عن نبتة...',
              hintStyle: const TextStyle(color: GharsColors.textMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: GharsColors.textMuted, size: 20),
              filled: true,
              fillColor: GharsColors.charcoal800,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: GharsColors.charcoal700),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: GharsColors.charcoal700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: GharsColors.gold),
              ),
            ),
          ),
        ),

        // ── Category filter chips ───────────────────────────
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final (key, label, emoji) = _categories[i];
              final selected = filterCat == key;
              return Padding(
                padding: EdgeInsets.only(left: i < _categories.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => onFilter(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? GharsColors.green.withValues(alpha: 0.15)
                          : GharsColors.charcoal800,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: selected ? GharsColors.green : GharsColors.charcoal700,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                            color: selected ? GharsColors.green : GharsColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // ── Grid ───────────────────────────────────────────
        Expanded(
          child: catalogAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: GharsColors.gold, strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: Text('خطأ: $e',
                  style: const TextStyle(color: GharsColors.textMuted)),
            ),
            data: (items) {
              final filtered = items.where((i) {
                final matchesCat    = filterCat == 'ALL' || i.category == filterCat;
                final matchesSearch = search.isEmpty ||
                    i.nameAr.contains(search) ||
                    i.nameEn.toLowerCase().contains(search.toLowerCase());
                return matchesCat && matchesSearch;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🔍', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 8),
                      Text('لا توجد نتائج',
                          style: TextStyle(color: GharsColors.textMuted)),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) =>
                    _CatalogCard(item: filtered[i], onTap: () => onTap(filtered[i])),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CatalogCard extends StatelessWidget {
  final CatalogItem item;
  final VoidCallback onTap;
  const _CatalogCard({required this.item, required this.onTap});

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_categoryEmoji[item.category] ?? '🌱',
                style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Text(
              item.nameAr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: GharsColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              item.nameEn,
              style: const TextStyle(fontSize: 10, color: GharsColors.textMuted),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💧', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 2),
                Text(
                  '${item.wateringCycleSummer} أيام',
                  style: const TextStyle(fontSize: 10, color: GharsColors.gold),
                ),
                const SizedBox(width: 8),
                Text(lightEmoji(item.lightMin, item.lightMax),
                    style: const TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STEP 2 — Details (location, pot size, nickname)
// ══════════════════════════════════════════════════════════════
class _DetailsStep extends StatelessWidget {
  final CatalogItem selected;
  final String location;
  final String potSize;
  final TextEditingController nicknameCtrl;
  final bool saving;
  final ValueChanged<String> onLocation;
  final ValueChanged<String> onPotSize;
  final VoidCallback onSave;

  const _DetailsStep({
    required this.selected,
    required this.location,
    required this.potSize,
    required this.nicknameCtrl,
    required this.saving,
    required this.onLocation,
    required this.onPotSize,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // selected plant card
          Container(
            decoration: BoxDecoration(
              color: GharsColors.charcoal800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GharsColors.gold.withValues(alpha: 0.4)),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Text(_categoryEmoji[selected.category] ?? '🌱',
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected.nameAr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: GharsColors.textPrimary,
                      ),
                    ),
                    Text(selected.nameEn,
                        style: const TextStyle(fontSize: 12, color: GharsColors.textMuted)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GharsColors.charcoal700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '💧 ${selected.wateringCycleSummer} أيام',
                    style: const TextStyle(fontSize: 11, color: GharsColors.gold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // nickname
          const _Label('اسم مخصص (اختياري)'),
          const SizedBox(height: 6),
          TextField(
            controller: nicknameCtrl,
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: GharsColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration('مثال: وردة الشرفة'),
          ),
          const SizedBox(height: 20),

          // location
          const _Label('موقع النبتة'),
          const SizedBox(height: 8),
          Row(
            children: _locations.map((loc) {
              final isSelected = location == loc.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => onLocation(loc.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? GharsColors.gold.withValues(alpha: 0.15)
                            : GharsColors.charcoal800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? GharsColors.gold : GharsColors.charcoal700,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Icon(loc.$3,
                              size: 20,
                              color: isSelected ? GharsColors.gold : GharsColors.textMuted),
                          const SizedBox(height: 4),
                          Text(
                            loc.$2,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? GharsColors.gold : GharsColors.textSecondary,
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

          // pot size
          const _Label('حجم الوعاء'),
          const SizedBox(height: 8),
          Row(
            children: _potSizes.map((ps) {
              final isSelected = potSize == ps.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => onPotSize(ps.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? GharsColors.gold.withValues(alpha: 0.15)
                            : GharsColors.charcoal800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? GharsColors.gold : GharsColors.charcoal700,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        ps.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? GharsColors.gold : GharsColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // save button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: saving ? null : onSave,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: saving
                        ? [GharsColors.charcoal600, GharsColors.charcoal500]
                        : [GharsColors.goldDim, GharsColors.gold],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (saving)
                      const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          color: GharsColors.textPrimary, strokeWidth: 2,
                        ),
                      )
                    else
                      const Text('🌱', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(
                      saving ? 'جاري الحفظ...' : 'إضافة النبتة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: saving ? GharsColors.textMuted : GharsColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: GharsColors.textMuted, fontSize: 13),
      filled: true,
      fillColor: GharsColors.charcoal800,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GharsColors.charcoal700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GharsColors.charcoal700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GharsColors.gold),
      ),
    );

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: GharsColors.textSecondary,
        ),
      );
}
