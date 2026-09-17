import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'diary_screen.dart';
import 'more_screen.dart';
import 'progress_screen.dart';
import 'today_screen.dart';
import 'workout_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(
          state: widget.state,
          onDiary: () => setState(() => index = 1),
          onActivity: () => setState(() => index = 2)),
      DiaryScreen(state: widget.state),
      WorkoutScreen(state: widget.state),
      ProgressScreen(state: widget.state),
      MoreScreen(state: widget.state),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final desktop = box.maxWidth >= 900;
        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: 232,
                  color: AppColors.paper,
                  child: SafeArea(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 26, 18, 26),
                          child: Row(children: [
                            _Logo(),
                            SizedBox(width: 12),
                            Text('SAAPADU',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                )),
                          ]),
                        ),
                        Expanded(
                          child: NavigationRail(
                            backgroundColor: AppColors.paper,
                            extended: true,
                            labelType: NavigationRailLabelType.none,
                            selectedIndex: index,
                            onDestinationSelected: (value) =>
                                setState(() => index = value),
                            indicatorColor: AppColors.lime,
                            minExtendedWidth: 215,
                            groupAlignment: -.85,
                            destinations: const [
                              NavigationRailDestination(
                                icon: Icon(Icons.home_outlined),
                                selectedIcon: Icon(Icons.home_rounded),
                                label: Text('Today'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.menu_book_outlined),
                                selectedIcon: Icon(Icons.menu_book_rounded),
                                label: Text('Diary'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.fitness_center_outlined),
                                selectedIcon:
                                    Icon(Icons.fitness_center_rounded),
                                label: Text('Activity'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.show_chart_outlined),
                                selectedIcon: Icon(Icons.show_chart_rounded),
                                label: Text('Progress'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.grid_view_outlined),
                                selectedIcon: Icon(Icons.grid_view_rounded),
                                label: Text('More'),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(children: [
                              Icon(Icons.lock_outline,
                                  size: 17, color: AppColors.forest),
                              SizedBox(width: 8),
                              Expanded(
                                  child: Text('Your data stays on this device',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted))),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[index]),
              ],
            ),
          );
        }
        return Scaffold(
          body: pages[index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Today'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book_rounded),
                  label: 'Diary'),
              NavigationDestination(
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(Icons.fitness_center_rounded),
                  label: 'Activity'),
              NavigationDestination(
                  icon: Icon(Icons.show_chart_outlined),
                  selectedIcon: Icon(Icons.show_chart_rounded),
                  label: 'Progress'),
              NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'More'),
            ],
          ),
        );
      },
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
            color: AppColors.forest, shape: BoxShape.circle),
        child: const Icon(Icons.spa_outlined, color: AppColors.lime, size: 21),
      );
}
