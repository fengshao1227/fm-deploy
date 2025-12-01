import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';

/// 主框架（带底部导航栏）
class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const _BottomNavBar(),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location == AppRoutes.home) {
      currentIndex = 0;
    } else if (location == AppRoutes.projects) {
      currentIndex = 1;
    } else if (location == AppRoutes.deployments) {
      currentIndex = 2;
    } else if (location == AppRoutes.settings) {
      currentIndex = 3;
    }

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go(AppRoutes.home);
            break;
          case 1:
            context.go(AppRoutes.projects);
            break;
          case 2:
            context.go(AppRoutes.deployments);
            break;
          case 3:
            context.go(AppRoutes.settings);
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: '首页',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: '项目',
        ),
        NavigationDestination(
          icon: Icon(Icons.rocket_launch_outlined),
          selectedIcon: Icon(Icons.rocket_launch),
          label: '部署',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: '设置',
        ),
      ],
    );
  }
}
