import codecs

widgets = """

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
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 11,
                  color: GharsColors.textMuted,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// بطاقة أصيص
class _PotCard extends ConsumerWidget {
  final Garden garden;
  const _PotCard({required this.garden});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(gardenPlantCountProvider(garden.id));

    return GestureDetector(
      onTap: () => context.push(
          '/garden/${garden.id}?name=${Uri.encodeComponent(garden.name)}'),
      child: Container(
        decoration: BoxDecoration(
          color: GharsColors.charcoal800,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GharsColors.charcoal700),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('\u{1FAB4}', style: TextStyle(fontSize: 26)),
                const Spacer(),
                _GardenPopupMenu(garden: garden),
              ],
            ),
            const Spacer(),
            Text(garden.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GharsColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            countAsync.when(
              data: (n) => Text(
                  n == 0 ? 'لا توجد نبتة'
                         : 'نبتة واحدة',
                  style: const TextStyle(fontSize: 11, color: GharsColors.textMuted)),
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// قائمة الكارد المشتركة
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
                garden: garden,
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
          final userId =
              Supabase.instance.client.auth.currentUser!.id;
          final res = await http.delete(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/api/gardens/${garden.id}'),
            headers: {
              'Content-Type': 'application/json',
              'x-user-id': userId
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
                style: TextStyle(
                    color: GharsColors.diseased, fontSize: 13)),
          ]),
        ),
      ],
    );
  }
}

// بطاقة اختيار نوع الإنشاء
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
        padding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
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
"""

with open('G:/ghars_app/lib/features/home/home_screen.dart', 'a', encoding='utf-8') as f:
    f.write(widgets)
print('done')
