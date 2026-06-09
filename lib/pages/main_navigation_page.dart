import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import 'admin_page.dart';
import 'community_page.dart';
import 'home_page.dart';
import 'my_page.dart';
import 'status_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  Timer? _reservationAlertTimer;
  GymProvider? _provider;
  final Set<String> _shownReservationAlertKeys = {};

  static const _pagesAdmin = [
    HomePage(),
    StatusPage(),
    CommunityPage(),
    MyPage(),
    AdminPage(),
  ];
  static const _pagesUser = [
    HomePage(),
    StatusPage(),
    CommunityPage(),
    MyPage(),
  ];

  @override
  void initState() {
    super.initState();
    _reservationAlertTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkReservationAlert(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<GymProvider>();
    if (_provider == provider) return;

    _provider?.removeListener(_checkReservationAlert);
    _provider = provider;
    provider.addListener(_checkReservationAlert);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkReservationAlert();
    });
  }

  @override
  void dispose() {
    _reservationAlertTimer?.cancel();
    _provider?.removeListener(_checkReservationAlert);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<GymProvider>().currentUser?.role == 'admin';
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
              label: '홈',
            ),
            const NavigationDestination(
              icon: Icon(Icons.analytics_outlined, color: blueColor),
              selectedIcon: Icon(Icons.analytics, color: textColor),
              label: '현황',
            ),
            const NavigationDestination(
              icon: Icon(Icons.forum_outlined, color: blueColor),
              selectedIcon: Icon(Icons.forum, color: textColor),
              label: '커뮤니티',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline, color: blueColor),
              selectedIcon: Icon(Icons.person, color: textColor),
              label: '마이페이지',
            ),
            if (isAdmin)
              const NavigationDestination(
                icon: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: blueColor,
                ),
                selectedIcon: Icon(
                  Icons.admin_panel_settings,
                  color: textColor,
                ),
                label: '관리질',
              ),
          ],
        ),
      ),
    );
  }

  void _checkReservationAlert() {
    if (!mounted) return;
    final provider = _provider;
    if (provider == null) return;
    if (provider.currentUser == null) {
      _shownReservationAlertKeys.clear();
      return;
    }

    final alert = provider.getMyReservationAlert();
    if (alert == null || !_shownReservationAlertKeys.add(alert.key)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_reservationAlertMessage(alert)),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: '예약 보기',
            textColor: greenColor,
            onPressed: () {
              if (mounted) {
                setState(() => _selectedIndex = 3);
              }
            },
          ),
        ),
      );
    });
  }

  String _reservationAlertMessage(ReservationAlert alert) {
    final machineName = alert.reservation.machineName;
    final startTime = formatTimeOnly(alert.reservation.reservedStartAt);
    return switch (alert.type) {
      ReservationAlertType.ready => '$machineName 예약 시간이 시작됐습니다. ($startTime)',
      ReservationAlertType.upcoming =>
        '$machineName 예약이 ${alert.minutesUntilStart}분 후 시작됩니다. ($startTime)',
    };
  }
}
