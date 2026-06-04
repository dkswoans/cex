import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import 'admin_page.dart';
import 'home_page.dart';
import 'my_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  static const _pagesAdmin = [HomePage(), MyPage(), AdminPage()];
  static const _pagesUser = [HomePage(), MyPage()];

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        context.watch<GymProvider>().currentUser?.role == 'admin';
    final pages = isAdmin ? _pagesAdmin : _pagesUser;
    final tabIndex = _selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(index: tabIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: surfaceColor,
          border: Border(top: BorderSide(color: Colors.black, width: 4)),
          boxShadow: [
            BoxShadow(color: blueColor, offset: Offset(0, -4), blurRadius: 0),
          ],
        ),
        child: NavigationBar(
          height: 72,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: bgColor,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              color: bgColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          selectedIndex: tabIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.map_outlined, color: blueColor),
              selectedIcon: Icon(Icons.map, color: textColor),
              label: '지도봄',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline, color: blueColor),
              selectedIcon: Icon(Icons.person, color: textColor),
              label: '마이',
            ),
            if (isAdmin)
              const NavigationDestination(
                icon: Icon(Icons.admin_panel_settings_outlined, color: blueColor),
                selectedIcon: Icon(Icons.admin_panel_settings, color: textColor),
                label: '관리질',
              ),
          ],
        ),
      ),
    );
  }
}
