import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../models/user_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/app_design.dart';
import 'login_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) context.read<GymProvider>().syncFromDatabase();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final user = provider.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('로그인이 필요합니다.')),
          );
        }

        final currentMachine = provider.getMachineCurrentlyUsedByMe();
        final myReservations = provider.getMyReservations();
        final weeklyMinutes = provider.getWeeklyUsageMinutes();
        final weeklyCount = provider.getWeeklySessionCount();
        final topMachines = provider.getTopMachinesByUsage(3);
        final recentLogs = provider.getMyUsageLogs().take(5).toList();
        final isLoading = provider.isActionLoading || provider.isLoading;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('마이'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '새로고침',
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        await provider.syncFromDatabase();
                        if (!context.mounted) return;
                        if (provider.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.errorMessage!)),
                          );
                        }
                      },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: provider.syncFromDatabase,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileCard(user: user),
                const SizedBox(height: 20),
                if (currentMachine != null) ...[
                  const AppSectionTitle('현재 사용 중'),
                  _CurrentUsageCard(
                    machine: currentMachine,
                    provider: provider,
                    isLoading: isLoading,
                    onFinish: () =>
                        _confirmFinish(context, provider, currentMachine.machineId),
                  ),
                  const SizedBox(height: 20),
                ],
                const AppSectionTitle('예약 현황'),
                if (myReservations.isEmpty)
                  const AppEmptyPanel(text: '예약한 기구가 없습니다.')
                else
                  ...myReservations.map(
                    (r) => _MyReservationCard(
                      reservation: r,
                      estimatedWaitMinutes: provider.getEstimatedWaitMinutes(
                        r.machineId,
                        r.userId,
                      ),
                      isLoading: isLoading,
                      onCancel: () =>
                          _confirmCancel(context, provider, r.reservationId),
                    ),
                  ),
                const SizedBox(height: 20),
                const AppSectionTitle('이번 주 운동'),
                _WeeklyStatsCard(
                  weeklyMinutes: weeklyMinutes,
                  sessionCount: weeklyCount,
                ),
                const SizedBox(height: 20),
                if (topMachines.isNotEmpty) ...[
                  const AppSectionTitle('많이 쓴 기구 TOP 3'),
                  ...topMachines.asMap().entries.map(
                    (e) => _TopMachineCard(
                      rank: e.key + 1,
                      name: e.value.key,
                      minutes: e.value.value,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const AppSectionTitle('최근 이용 기록'),
                if (recentLogs.isEmpty)
                  const AppEmptyPanel(text: '이용 기록이 없습니다.')
                else
                  ...recentLogs.map(
                    (log) => AppRecordCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(log.machineName, style: AppTextStyles.itemTitle),
                                const SizedBox(height: 4),
                                Text(
                                  formatDateTime(log.endedAt),
                                  style: AppTextStyles.label,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${log.usedMinutes}분',
                            style: const TextStyle(
                              color: blueColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context, provider),
                  icon: const Icon(Icons.logout),
                  label: const Text('로그아웃'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: redColor,
                    backgroundColor: bgColor,
                    side: const BorderSide(color: redColor, width: 2.5),
                  ),
                ),
                const SizedBox(height: 72),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmFinish(
    BuildContext context,
    GymProvider provider,
    String machineId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('사용 종료'),
        content: const Text('기구 사용을 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: redColor),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final message = await provider.finishUsingMachine(machineId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmCancel(
    BuildContext context,
    GymProvider provider,
    String reservationId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('예약 취소'),
        content: const Text('예약을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: redColor),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final message = await provider.cancelReservation(reservationId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmLogout(BuildContext context, GymProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    provider.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return AppRecordCard(
      shadows: AppShadows.loud,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: blueColor,
            foregroundColor: textColor,
            child: Text(
              user.name.isNotEmpty ? user.name[0] : '?',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: AppTextStyles.itemTitle),
                const SizedBox(height: 4),
                Text(user.userId, style: AppTextStyles.label),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: user.role == 'admin' ? redColor : greenColor,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Text(
              user.role == 'admin' ? '관리자' : '일반',
              style: const TextStyle(
                color: borderColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentUsageCard extends StatelessWidget {
  const _CurrentUsageCard({
    required this.machine,
    required this.provider,
    required this.isLoading,
    required this.onFinish,
  });

  final MachineModel machine;
  final GymProvider provider;
  final bool isLoading;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final remaining = provider.getRemainingMinutes(machine);
    return AppRecordCard(
      shadows: const [
        BoxShadow(color: redColor, offset: Offset(5, 5), blurRadius: 0),
        BoxShadow(color: blueColor, offset: Offset(-3, -3), blurRadius: 0),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(machine.name, style: AppTextStyles.itemTitle),
              ),
              Text(
                formatRemainingMinutes(remaining),
                style: const TextStyle(
                  color: redColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppInfoRow(
            label: '종료 예정',
            value: formatTimeOnly(machine.endAt),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : onFinish,
              style: FilledButton.styleFrom(backgroundColor: redColor),
              child: const Text('사용 종료'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyReservationCard extends StatelessWidget {
  const _MyReservationCard({
    required this.reservation,
    required this.estimatedWaitMinutes,
    required this.isLoading,
    required this.onCancel,
  });

  final ReservationModel reservation;
  final int estimatedWaitMinutes;
  final bool isLoading;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isActive = reservation.status == ReservationStatus.active;
    return AppRecordCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(reservation.machineName, style: AppTextStyles.itemTitle),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? greenColor : amberColor,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Text(
                  isActive ? '사용 가능' : '대기 중',
                  style: const TextStyle(
                    color: borderColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppInfoRow(
            label: '예약 시간',
            value: formatTimeRange(
              reservation.reservedStartAt,
              reservation.reservedEndAt,
            ),
          ),
          if (!isActive)
            AppInfoRow(
              label: '예상 대기',
              value: formatRemainingMinutes(estimatedWaitMinutes),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : onCancel,
              style: FilledButton.styleFrom(backgroundColor: redColor),
              child: const Text('예약 취소'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyStatsCard extends StatelessWidget {
  const _WeeklyStatsCard({
    required this.weeklyMinutes,
    required this.sessionCount,
  });

  final int weeklyMinutes;
  final int sessionCount;

  @override
  Widget build(BuildContext context) {
    return AppRecordCard(
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: '총 운동 시간',
              value: formatRemainingMinutes(weeklyMinutes),
            ),
          ),
          Container(width: 2, height: 40, color: borderColor),
          Expanded(
            child: _StatItem(label: '이용 횟수', value: '$sessionCount회'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
              color: blueColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.label),
      ],
    );
  }
}

class _TopMachineCard extends StatelessWidget {
  const _TopMachineCard({
    required this.rank,
    required this.name,
    required this.minutes,
  });

  final int rank;
  final String name;
  final int minutes;

  static const _rankColors = [redColor, blueColor, greenColor];

  @override
  Widget build(BuildContext context) {
    final rankColor = rank <= 3 ? _rankColors[rank - 1] : amberColor;
    return AppRecordCard(
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: borderColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: AppTextStyles.itemTitle)),
          Text(
            formatRemainingMinutes(minutes),
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
