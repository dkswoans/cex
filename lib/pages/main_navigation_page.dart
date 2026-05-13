import 'package:flutter/material.dart';

import '../utils/status_utils.dart';
import 'admin_page.dart';
import 'home_page.dart';
import 'my_reservation_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  static const _pages = [HomePage(), MyReservationPage(), AdminPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: redColor,
          border: Border(top: BorderSide(color: Colors.black, width: 6)),
          boxShadow: [
            BoxShadow(color: greenColor, offset: Offset(0, -6), blurRadius: 0),
          ],
        ),
        child: NavigationBar(
          height: 76,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: bgColor,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              color: bgColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined, color: blueColor),
              selectedIcon: Icon(Icons.map, color: textColor),
              label: '지도봄',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined, color: blueColor),
              selectedIcon: Icon(Icons.list_alt, color: textColor),
              label: '내찜',
            ),
            NavigationDestination(
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
