import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../models/user_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/app_design.dart';
import '../widgets/reservation_time_dialog.dart';
import '../widgets/wobbly_card.dart';
import 'login_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final user = provider.currentUser;
        if (user == null) {
          return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
        }

        final currentMachine = provider.getMachineCurrentlyUsedByMe();
        final myReservations = provider
            .getMyReservations()
            .where(
              (reservation) => reservation.status == ReservationStatus.waiting,
            )
            .toList();
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _tiltedCard(
                  seed: 'profile_${user.userId}',
                  child: _ProfileContent(user: user),
                ),
                const SizedBox(height: 8),
                if (currentMachine != null) ...[
                  _sectionLabel('현재 사용 중'),
                  _tiltedCard(
                    seed: 'using_${currentMachine.machineId}',
                    shadows: const [
                      BoxShadow(
                        color: redColor,
                        offset: Offset(6, 6),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: blueColor,
                        offset: Offset(-3, -3),
                        blurRadius: 0,
                      ),
                    ],
                    child: _CurrentUsageContent(
                      machine: currentMachine,
                      provider: provider,
                      isLoading: isLoading,
                      onFinish: () => _confirmFinish(
                        context,
                        provider,
                        currentMachine.machineId,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _sectionLabel('예약 현황'),
                if (myReservations.isEmpty)
                  _tiltedCard(
                    seed: 'no_res',
                    child: Center(
                      child: _funLabel('예약한 기구가 없습니다.', 'no_res_text'),
                    ),
                  )
                else
                  ...myReservations.asMap().entries.map(
                    (e) => _tiltedCard(
                      seed: 'res_${e.value.reservationId}',
                      child: _ReservationContent(
                        reservation: e.value,
                        estimatedWaitMinutes: provider.getEstimatedWaitMinutes(
                          e.value.machineId,
                          e.value.userId,
                        ),
                        isLoading: isLoading,
                        onEdit: () =>
                            _editReservation(context, provider, e.value),
                        onCancel: () => _confirmCancel(
                          context,
                          provider,
                          e.value.reservationId,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _sectionLabel('이번 주 운동'),
                _tiltedCard(
                  seed: 'weekly_stats',
                  child: _WeeklyContent(
                    weeklyMinutes: weeklyMinutes,
                    sessionCount: weeklyCount,
                  ),
                ),
                if (topMachines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sectionLabel('많이 쓴 기구 TOP 3'),
                  ...topMachines.asMap().entries.map(
                    (e) => _tiltedCard(
                      seed: 'top_${e.key}_${e.value.key}',
                      child: _TopMachineContent(
                        rank: e.key + 1,
                        name: e.value.key,
                        minutes: e.value.value,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _sectionLabel('최근 이용 기록'),
                if (recentLogs.isEmpty)
                  _tiltedCard(
                    seed: 'no_logs',
                    child: Center(
                      child: _funLabel('이용 기록이 없습니다.', 'no_logs_text'),
                    ),
                  )
                else
                  ...recentLogs.asMap().entries.map(
                    (e) => _tiltedCard(
                      seed: 'log_${e.key}_${e.value.logId}',
                      child: _LogContent(log: e.value),
                    ),
                  ),
                const SizedBox(height: 24),
                _tiltedCard(
                  seed: 'logout_btn',
                  shadows: const [
                    BoxShadow(
                      color: redColor,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
                  child: GestureDetector(
                    onTap: () => _confirmLogout(context, provider),
                    child: const Center(
                      child: Text(
                        '로그아웃',
                        style: TextStyle(
                          color: redColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Widget _tiltedCard({
    required String seed,
    required Widget child,
    List<BoxShadow>? shadows,
  }) {
    final angle =
        (math.Random(seed.hashCode ^ 0xABCD).nextDouble() - 0.5) * 0.06;
    return Transform.rotate(
      angle: angle,
      child: WobblyCard(
        seed: seed,
        shadows: shadows ?? randomShadows(seed),
        child: child,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    final rng = math.Random(text.hashCode);
    final angle = (rng.nextDouble() - 0.5) * 0.12;
    const colors = [textColor, blueColor, redColor, amberColor];
    final color = colors[rng.nextInt(colors.length)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, top: 10),
      child: Transform.rotate(
        alignment: Alignment.centerLeft,
        angle: angle,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
        ),
      ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editReservation(
    BuildContext context,
    GymProvider provider,
    ReservationModel reservation,
  ) async {
    final maxMinutes = provider.getMaxReservationMinutesForMachine(
      reservation.machineId,
    );
    final request = await showDialog<ReservationTimeRequest>(
      context: context,
      builder: (_) => ReservationTimeDialog(
        maxMinutes: maxMinutes,
        initialStartAt: reservation.reservedStartAt,
        initialMinutes: _reservationMinutes(reservation, maxMinutes),
        title: '예약 수정',
        confirmLabel: '수정하기',
      ),
    );
    if (request == null) return;

    final message = await provider.updateReservation(
      reservation.reservationId,
      startAt: request.startAt,
      minutes: request.minutes,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int _reservationMinutes(ReservationModel reservation, int fallback) {
    final startAt = reservation.reservedStartAt;
    final endAt = reservation.reservedEndAt;
    if (startAt == null || endAt == null) return fallback;
    final minutes = endAt.difference(startAt).inMinutes;
    return minutes < 1 ? fallback : minutes;
  }

  Future<void> _confirmLogout(
    BuildContext context,
    GymProvider provider,
  ) async {
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

// ── helpers ──────────────────────────────────────────────────────────────────

Widget _bigTitle(String text, String seed) {
  final rng = math.Random(seed.hashCode);
  final angle = (rng.nextDouble() - 0.5) * 0.22;
  const colors = [greenColor, blueColor, amberColor, redColor];
  final color = colors[rng.nextInt(colors.length)];
  return Transform.rotate(
    alignment: Alignment.centerLeft,
    angle: angle,
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 30,
        fontWeight: FontWeight.w900,
        height: 1.0,
        letterSpacing: 0.8,
        shadows: const [
          Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
    ),
  );
}

Widget _funLabel(String text, String seed, {double fontSize = 13}) {
  final rng = math.Random(seed.hashCode);
  final angle = (rng.nextDouble() - 0.5) * 0.16;
  const colors = [mutedTextColor, blueColor, amberColor, greenColor];
  final color = colors[rng.nextInt(colors.length)];
  return Transform.rotate(
    alignment: Alignment.centerLeft,
    angle: angle,
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        shadows: const [
          Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
        ],
      ),
    ),
  );
}

Widget _funRow(
  String label,
  String value,
  String seed, {
  double fontSize = 14,
}) {
  final rng = math.Random(seed.hashCode);
  final rowAngle = (rng.nextDouble() - 0.5) * 0.10;
  final labelAngle = (rng.nextDouble() - 0.5) * 0.14;
  final valueAngle = (rng.nextDouble() - 0.5) * 0.12;
  const colors = [greenColor, redColor, amberColor, blueColor];
  final labelColor = colors[rng.nextInt(colors.length)];
  final valueColor = colors[rng.nextInt(colors.length)];

  return Transform.rotate(
    alignment: Alignment.centerLeft,
    angle: rowAngle,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: labelAngle,
            child: Text(
              '$label  ',
              style: TextStyle(
                color: labelColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(1, 1),
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: valueAngle,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(1, 1),
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── section content widgets ───────────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileIdentityPanel(user: user),
        const SizedBox(height: 12),
        Transform.rotate(
          angle: -0.04,
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: user.role == 'admin' ? redColor : greenColor,
              border: Border.all(color: borderColor, width: 2.5),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              boxShadow: const [
                BoxShadow(
                  color: borderColor,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
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
        ),
      ],
    );
  }
}

class _ProfileIdentityPanel extends StatelessWidget {
  const _ProfileIdentityPanel({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileValueRow(
          label: '이름',
          value: user.name,
          fontSize: 38,
          valueColor: redColor,
        ),
        const SizedBox(height: 12),
        _ProfileValueRow(
          label: '학번',
          value: user.userId,
          fontSize: 26,
          valueColor: textColor,
        ),
      ],
    );
  }
}

class _ProfileValueRow extends StatelessWidget {
  const _ProfileValueRow({
    required this.label,
    required this.value,
    required this.fontSize,
    required this.valueColor,
  });

  final String label;
  final String value;
  final double fontSize;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: greenColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 1.0,
            shadows: [
              Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: 0,
            shadows: const [
              Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentUsageContent extends StatelessWidget {
  const _CurrentUsageContent({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bigTitle(machine.name, 'using_title_${machine.machineId}'),
        const SizedBox(height: 12),
        _funRow(
          '남은 시간',
          formatRemainingMinutes(remaining),
          'using_rem_${machine.machineId}',
        ),
        _funRow(
          '종료 예정',
          formatTimeOnly(machine.endAt),
          'using_end_${machine.machineId}',
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading ? null : onFinish,
            style: FilledButton.styleFrom(backgroundColor: redColor),
            child: const Text('사용 종료'),
          ),
        ),
      ],
    );
  }
}

class _ReservationContent extends StatelessWidget {
  const _ReservationContent({
    required this.reservation,
    required this.estimatedWaitMinutes,
    required this.isLoading,
    required this.onEdit,
    required this.onCancel,
  });

  final ReservationModel reservation;
  final int estimatedWaitMinutes;
  final bool isLoading;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isActive = reservation.status == ReservationStatus.active;
    final seed = 'res_content_${reservation.reservationId}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _bigTitle(reservation.machineName, '${seed}_title'),
            ),
            Transform.rotate(
              angle: 0.05,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isActive ? greenColor : amberColor,
                  border: Border.all(color: borderColor, width: 2.5),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  boxShadow: const [
                    BoxShadow(
                      color: borderColor,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
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
            ),
          ],
        ),
        const SizedBox(height: 10),
        _funRow(
          '예약 시간',
          formatTimeRange(
            reservation.reservedStartAt,
            reservation.reservedEndAt,
          ),
          '${seed}_time',
        ),
        if (!isActive)
          _funRow(
            '예상 대기',
            formatRemainingMinutes(estimatedWaitMinutes),
            '${seed}_wait',
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: isLoading ? null : onEdit,
                style: FilledButton.styleFrom(backgroundColor: blueColor),
                child: const Text('예약 수정'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: isLoading ? null : onCancel,
                style: FilledButton.styleFrom(backgroundColor: redColor),
                child: const Text('예약 취소'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeeklyContent extends StatelessWidget {
  const _WeeklyContent({
    required this.weeklyMinutes,
    required this.sessionCount,
  });

  final int weeklyMinutes;
  final int sessionCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Transform.rotate(
                angle: -0.05,
                child: Text(
                  formatRemainingMinutes(weeklyMinutes),
                  style: const TextStyle(
                    color: blueColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _funLabel('총 운동 시간', 'weekly_label1'),
            ],
          ),
        ),
        Container(width: 3, height: 44, color: borderColor),
        Expanded(
          child: Column(
            children: [
              Transform.rotate(
                angle: 0.06,
                child: Text(
                  '$sessionCount회',
                  style: const TextStyle(
                    color: redColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _funLabel('이용 횟수', 'weekly_label2'),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopMachineContent extends StatelessWidget {
  const _TopMachineContent({
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
    final seed = 'top_$rank';
    return Row(
      children: [
        Transform.rotate(
          angle: (math.Random(seed.hashCode).nextDouble() - 0.5) * 0.2,
          child: Text(
            '$rank',
            style: TextStyle(
              color: rankColor,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.0,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _funRow(
            name,
            formatRemainingMinutes(minutes),
            '${seed}_row',
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class _LogContent extends StatelessWidget {
  const _LogContent({required this.log});

  final dynamic log;

  @override
  Widget build(BuildContext context) {
    final seed = 'log_${log.logId}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _bigTitle(log.machineName, '${seed}_title')),
            Transform.rotate(
              angle: 0.06,
              child: Text(
                formatRemainingMinutes(log.usedMinutes),
                style: const TextStyle(
                  color: blueColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _funLabel(formatDateTime(log.endedAt), '${seed}_date', fontSize: 15),
      ],
    );
  }
}
