import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../providers/gardens_provider.dart';
import 'home/home_screen.dart';
import 'today/today_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 0;

  static const _screens = [HomeScreen(), TodayScreen()];

  @override
  Widget build(BuildContext context) {
    // عدد المهام لعرض الـ Badge
    final todayCount = ref.watch(todayTasksProvider).whenOrNull(
          data: (tasks) => tasks.length,
        ) ??
        0;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: GharsColors.charcoal700, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: GharsColors.charcoal900,
          surfaceTintColor: Colors.transparent,
          indicatorColor: GharsColors.green.withValues(alpha: 0.12),
          labelBehavior:
              NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.yard_outlined),
              selectedIcon: Icon(Icons.yard, color: GharsColors.green),
              label: 'حدائقي',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: todayCount > 0,
                label: Text('$todayCount'),
                backgroundColor: GharsColors.critical,
                textStyle:
                    const TextStyle(fontSize: 10, color: Colors.white),
                child: const Icon(Icons.water_drop_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: todayCount > 0,
                label: Text('$todayCount'),
                backgroundColor: GharsColors.critical,
                textStyle:
                    const TextStyle(fontSize: 10, color: Colors.white),
                child: const Icon(Icons.water_drop,
                    color: GharsColors.green),
              ),
              label: 'اليوم',
            ),
          ],
        ),
      ),
    );
  }
}
