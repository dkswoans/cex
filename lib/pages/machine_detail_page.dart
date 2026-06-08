import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/app_design.dart';
import '../widgets/reservation_time_dialog.dart';
import '../widgets/status_badge.dart';

class MachineDetailPage extends StatelessWidget {
  const MachineDetailPage({super.key, required this.machineId});

  final String machineId;

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        MachineModel? machine;
        for (final item in provider.machines) {
          if (item.machineId == machineId) {
            machine = item;
            break;
          }
        }

        if (machine == null) {
          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(title: const Text('기구 정보')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  provider.errorMessage ?? '기구 정보를 불러오지 못했습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: redColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }

        final currentUser = provider.currentUser;
        final reservations = provider
            .getReservationsByMachine(machineId)
            .where((r) => r.status == ReservationStatus.waiting)
            .toList();
        final activeReservations = provider.getCurrentUsersByMachine(machineId);
        final myReservation = provider.getMyReservationForMachine(machineId);
        final isCurrentUserUsing = provider.isUserUsingMachine(machineId);
        final capacity = provider.getMachineCapacity(machineId);
        final isMultiUnitMachine = capacity > 1;
        final variants = provider.getMachineVariants(machineId);
        final hasVariants = variants.isNotEmpty;
        final maxUseMinutes = provider.getMaxUseMinutesForMachine(machineId);
        final maxReservationMinutes = provider
            .getMaxReservationMinutesForMachine(machineId);
        final activeUserText = activeReservations.isEmpty
            ? machine.currentUserName ?? '-'
            : '${activeReservations.map((reservation) => reservation.userName).join(', ')} (${activeReservations.length}/$capacity)';
        final canStart =
            !isCurrentUserUsing &&
            (variants.isNotEmpty ||
                myReservation?.status == ReservationStatus.active ||
                provider.hasAvailableUnitNow(machineId));
        final canReserve =
            machine.status != MachineStatus.repair &&
            !isCurrentUserUsing &&
            (variants.isNotEmpty || myReservation == null);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(title: Text(machine.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Transform.rotate(
                angle:
                    (math.Random(machineId.hashCode ^ 0xABCD).nextDouble() -
                        0.5) *
                    0.06,
                child: _WobblyCard(
                  seed: '${machineId}_card',
                  shadows: _randomShadows('${machineId}_card'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _MachineTitleBanner(
                                  machineId: machineId,
                                  name: machine.name,
                                ),
                                if (machine.description != null) ...[
                                  const SizedBox(height: 6),
                                  _SkewedLabel(
                                    text: machine.description!,
                                    seed: '${machineId}_d',
                                  ),
                                ],
                              ],
                            ),
                          ),
                          StatusBadge(status: machine.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FunInfoRow(
                        label: '최대 사용 시간',
                        value: '$maxUseMinutes분',
                        seed: '${machineId}0',
                      ),
                      _FunInfoRow(
                        label: '현재 사용자',
                        value: activeUserText,
                        seed: '${machineId}1',
                      ),
                      if (!isMultiUnitMachine && !hasVariants) ...[
                        _FunInfoRow(
                          label: '시작 시간',
                          value: formatTimeOnly(machine.startedAt),
                          seed: '${machineId}2',
                        ),
                        _FunInfoRow(
                          label: '종료 예정',
                          value: formatTimeOnly(machine.endAt),
                          seed: '${machineId}3',
                        ),
                        _FunInfoRow(
                          label: '남은 시간',
                          value: formatRemainingMinutes(
                            provider.getRemainingMinutes(machine),
                          ),
                          seed: '${machineId}4',
                        ),
                      ],
                      _FunInfoRow(
                        label: '대기 인원',
                        value: '${provider.getWaitingCount(machineId)}명',
                        seed: '${machineId}5',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const AppSectionTitle('예약 시간표'),
              _ScheduleOverview(
                machine: machine,
                provider: provider,
                activeReservations: activeReservations,
                waitingReservations: reservations,
                myReservation: myReservation,
                capacity: capacity,
                hasVariants: hasVariants,
              ),
              const SizedBox(height: 16),
              AppSectionTitle(isMultiUnitMachine ? '현재 사용 현황' : '현재 사용자'),
              if (activeReservations.isEmpty)
                Transform.rotate(
                  angle:
                      (math.Random(
                            '${machineId}_empty_active'.hashCode ^ 0xABCD,
                          ).nextDouble() -
                          0.5) *
                      0.06,
                  child: _WobblyCard(
                    seed: '${machineId}_empty_active',
                    shadows: _randomShadows('${machineId}_empty_active'),
                    child: const Center(
                      child: Text(
                        '현재 사용 중인 사람이 없습니다.',
                        style: AppTextStyles.empty,
                      ),
                    ),
                  ),
                )
              else
                for (final entry in activeReservations.asMap().entries)
                  Transform.rotate(
                    angle:
                        (math.Random(
                              '${machineId}_active_${entry.key}'.hashCode ^
                                  0xABCD,
                            ).nextDouble() -
                            0.5) *
                        0.06,
                    child: _WobblyCard(
                      seed: '${machineId}_active_${entry.key}',
                      shadows: _randomShadows(
                        '${machineId}_active_${entry.key}',
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: amberColor,
                            foregroundColor: textColor,
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.value.userName,
                                  style: AppTextStyles.itemTitle,
                                ),
                                if (variants.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    entry.value.machineName,
                                    style: AppTextStyles.label,
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Text(
                                  formatTimeRange(
                                    entry.value.reservedStartAt,
                                    entry.value.reservedEndAt,
                                  ),
                                  style: AppTextStyles.value,
                                ),
                              ],
                            ),
                          ),
                          Text('사용 중', style: AppTextStyles.label),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              const AppSectionTitle('대기자 목록'),
              if (reservations.isEmpty)
                Transform.rotate(
                  angle:
                      (math.Random(
                            '${machineId}_empty_wait'.hashCode ^ 0xABCD,
                          ).nextDouble() -
                          0.5) *
                      0.06,
                  child: _WobblyCard(
                    seed: '${machineId}_empty_wait',
                    shadows: _randomShadows('${machineId}_empty_wait'),
                    child: const Center(
                      child: Text('대기자가 없습니다.', style: AppTextStyles.empty),
                    ),
                  ),
                )
              else
                for (final entry in reservations.asMap().entries)
                  Transform.rotate(
                    angle:
                        (math.Random(
                              '${machineId}_wait_${entry.key}'.hashCode ^
                                  0xABCD,
                            ).nextDouble() -
                            0.5) *
                        0.06,
                    child: _WobblyCard(
                      seed: '${machineId}_wait_${entry.key}',
                      shadows: _randomShadows('${machineId}_wait_${entry.key}'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: lightGrayColor,
                            foregroundColor: textColor,
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.value.userName,
                                  style: AppTextStyles.itemTitle,
                                ),
                                if (variants.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    entry.value.machineName,
                                    style: AppTextStyles.label,
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Text(
                                  formatTimeRange(
                                    entry.value.reservedStartAt,
                                    entry.value.reservedEndAt,
                                  ),
                                  style: AppTextStyles.value,
                                ),
                              ],
                            ),
                          ),
                          if (entry.value.userId == currentUser?.userId)
                            Wrap(
                              spacing: 4,
                              children: [
                                TextButton(
                                  onPressed:
                                      provider.isActionLoading ||
                                          provider.isLoading
                                      ? null
                                      : () => _editReservation(
                                          context,
                                          provider,
                                          entry.value,
                                        ),
                                  child: const Text('수정'),
                                ),
                                TextButton(
                                  onPressed:
                                      provider.isActionLoading ||
                                          provider.isLoading
                                      ? null
                                      : () => _cancelWithConfirm(
                                          context,
                                          provider,
                                          entry.value.reservationId,
                                        ),
                                  child: const Text('예약 취소'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              if (machine.status == MachineStatus.repair)
                const AppEmptyPanel(text: '점검 중인 기구입니다.')
              else
                _ActionButtons(
                  showStart: !isCurrentUserUsing,
                  canReserve: canReserve,
                  canCancel: myReservation != null,
                  canFinish: isCurrentUserUsing,
                  isLoading: provider.isActionLoading || provider.isLoading,
                  onStart: () async {
                    if (!canStart) {
                      _showMessage(context, '현재 사용 가능한 자리가 없습니다.');
                      return;
                    }
                    final variant = variants.isEmpty
                        ? null
                        : await _askVariant(
                            context,
                            title: machineId == 'dumbbell'
                                ? '덤벨 무게 선택'
                                : '바벨 무게 선택',
                            variants: variants,
                          );
                    if (variants.isNotEmpty && variant == null) return;
                    if (!context.mounted) return;
                    final minutes = await _askMinutes(
                      context,
                      title: '사용 시간',
                      maxMinutes: maxUseMinutes,
                      initialMinutes: maxUseMinutes,
                      helperText: '1분부터 $maxUseMinutes분까지 사용할 수 있습니다.',
                      confirmLabel: '사용하기',
                    );
                    if (minutes == null) return;
                    final message = await provider.startUsingMachine(
                      machineId,
                      minutes: minutes,
                      variantLabel: variant,
                    );
                    if (!context.mounted) return;
                    _showMessage(context, message);
                  },
                  onReserve: () async {
                    final variant = variants.isEmpty
                        ? null
                        : await _askVariant(
                            context,
                            title: machineId == 'dumbbell'
                                ? '덤벨 무게 선택'
                                : '바벨 무게 선택',
                            variants: variants,
                          );
                    if (variants.isNotEmpty && variant == null) return;
                    if (!context.mounted) return;
                    final request = await _askReservation(
                      context,
                      maxMinutes: maxReservationMinutes,
                      findEarliestStartAt: (minutes) =>
                          provider.getEarliestReservationStartAt(
                            machineId,
                            minutes: minutes,
                            variantLabel: variant,
                          ),
                    );
                    if (request == null) return;
                    final message = await provider.reserveMachine(
                      machineId,
                      minutes: request.minutes,
                      startAt: request.startAt,
                      variantLabel: variant,
                    );
                    if (!context.mounted) return;
                    _showMessage(context, message);
                  },
                  onCancel: myReservation == null
                      ? null
                      : () => _cancelWithConfirm(
                          context,
                          provider,
                          myReservation.reservationId,
                        ),
                  onFinish: () => _finishWithConfirm(context, provider),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<int?> _askMinutes(
    BuildContext context, {
    required String title,
    required int maxMinutes,
    required int initialMinutes,
    required String helperText,
    required String confirmLabel,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => _MinutesDialog(
        title: title,
        maxMinutes: maxMinutes,
        initialMinutes: initialMinutes,
        helperText: helperText,
        confirmLabel: confirmLabel,
      ),
    );
  }

  Future<String?> _askVariant(
    BuildContext context, {
    required String title,
    required List<String> variants,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _VariantPickerDialog(title: title, variants: variants),
    );
  }

  Future<ReservationTimeRequest?> _askReservation(
    BuildContext context, {
    required int maxMinutes,
    DateTime? initialStartAt,
    int? initialMinutes,
    String title = '예약 시간 설정',
    String confirmLabel = '예약하기',
    DateTime? Function(int minutes)? findEarliestStartAt,
  }) {
    return showDialog<ReservationTimeRequest>(
      context: context,
      builder: (_) => ReservationTimeDialog(
        maxMinutes: maxMinutes,
        initialStartAt: initialStartAt,
        initialMinutes: initialMinutes,
        title: title,
        confirmLabel: confirmLabel,
        findEarliestStartAt: findEarliestStartAt,
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
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
    final initialMinutes = _reservationMinutes(reservation, maxMinutes);
    final request = await _askReservation(
      context,
      maxMinutes: maxMinutes,
      initialStartAt: reservation.reservedStartAt,
      initialMinutes: initialMinutes,
      title: '예약 수정',
      confirmLabel: '수정하기',
    );
    if (request == null) return;

    final message = await provider.updateReservation(
      reservation.reservationId,
      startAt: request.startAt,
      minutes: request.minutes,
    );
    if (!context.mounted) return;
    _showMessage(context, message);
  }

  int _reservationMinutes(ReservationModel reservation, int fallback) {
    final startAt = reservation.reservedStartAt;
    final endAt = reservation.reservedEndAt;
    if (startAt == null || endAt == null) return fallback;
    final minutes = endAt.difference(startAt).inMinutes;
    if (minutes < 1) return fallback;
    return minutes;
  }

  Future<void> _cancelWithConfirm(
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
    _showMessage(context, message);
  }

  Future<void> _finishWithConfirm(
    BuildContext context,
    GymProvider provider,
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
    _showMessage(context, message);
  }
}

List<BoxShadow> _randomShadows(String seed) {
  final rng = math.Random(seed.hashCode);
  const colors = [greenColor, redColor, blueColor, amberColor, borderColor];
  final count = 2 + rng.nextInt(3);
  return List.generate(count, (_) {
    final color = colors[rng.nextInt(colors.length)];
    final dx = (rng.nextDouble() * 14 - 2);
    final dy = (rng.nextDouble() * 14 - 2);
    return BoxShadow(color: color, offset: Offset(dx, dy), blurRadius: 0);
  });
}

List<BoxShadow> _chipShadows(String seed) {
  final rng = math.Random(seed.hashCode);
  const colors = [greenColor, redColor, blueColor, amberColor, borderColor];
  final count = 1 + rng.nextInt(2);
  return List.generate(count, (_) {
    final color = colors[rng.nextInt(colors.length)];
    final dx = rng.nextDouble() * 4 + 1;
    final dy = rng.nextDouble() * 4 + 1;
    return BoxShadow(color: color, offset: Offset(dx, dy), blurRadius: 0);
  });
}

Path _buildWobblyPath(String seed, Size size, {double jitterScale = 1.0}) {
  final rng = math.Random(seed.hashCode);
  double j() {
    final sign = rng.nextBool() ? 1 : -1;
    return sign * (3 + rng.nextDouble() * 3) * jitterScale;
  }

  final W = size.width;
  final H = size.height;

  final tl = Offset(j(), j());
  final tr = Offset(W + j(), j());
  final br = Offset(W + j(), H + j());
  final bl = Offset(j(), H + j());

  final topMid = Offset(W / 2 + j(), j() * 2);
  final rightMid = Offset(W + j() * 2, H / 2 + j());
  final bottomMid = Offset(W / 2 + j(), H + j() * 2);
  final leftMid = Offset(j() * 2, H / 2 + j());

  return Path()
    ..moveTo(tl.dx, tl.dy)
    ..quadraticBezierTo(topMid.dx, topMid.dy, tr.dx, tr.dy)
    ..quadraticBezierTo(rightMid.dx, rightMid.dy, br.dx, br.dy)
    ..quadraticBezierTo(bottomMid.dx, bottomMid.dy, bl.dx, bl.dy)
    ..quadraticBezierTo(leftMid.dx, leftMid.dy, tl.dx, tl.dy)
    ..close();
}

class _WobblyCardPainter extends CustomPainter {
  const _WobblyCardPainter({
    required this.seed,
    required this.shadows,
    this.fillColor = surfaceColor,
    this.jitterScale = 1.0,
  });

  final String seed;
  final List<BoxShadow> shadows;
  final Color fillColor;
  final double jitterScale;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildWobblyPath(seed, size, jitterScale: jitterScale);

    for (final shadow in shadows) {
      canvas.drawPath(path.shift(shadow.offset), Paint()..color = shadow.color);
    }

    canvas.drawPath(path, Paint()..color = fillColor);

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
  }

  @override
  bool shouldRepaint(covariant _WobblyCardPainter old) =>
      old.seed != seed ||
      old.fillColor != fillColor ||
      old.jitterScale != jitterScale;
}

class _WobblyCardClipper extends CustomClipper<Path> {
  const _WobblyCardClipper({required this.seed, this.jitterScale = 1.0});

  final String seed;
  final double jitterScale;

  @override
  Path getClip(Size size) =>
      _buildWobblyPath(seed, size, jitterScale: jitterScale);

  @override
  bool shouldReclip(covariant _WobblyCardClipper old) =>
      old.seed != seed || old.jitterScale != jitterScale;
}

class _WobblyCard extends StatelessWidget {
  const _WobblyCard({
    required this.seed,
    required this.shadows,
    required this.child,
  });

  final String seed;
  final List<BoxShadow> shadows;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CustomPaint(
        painter: _WobblyCardPainter(seed: seed, shadows: shadows),
        child: ClipPath(
          clipper: _WobblyCardClipper(seed: seed),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MachineTitleBanner extends StatelessWidget {
  const _MachineTitleBanner({required this.machineId, required this.name});

  final String machineId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(machineId.hashCode);
    final angle = (rng.nextDouble() - 0.5) * 0.22;
    final colors = [greenColor, blueColor, amberColor, redColor];
    final color = colors[rng.nextInt(colors.length)];

    return Transform.rotate(
      alignment: Alignment.centerLeft,
      angle: angle,
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontSize: 36,
          fontWeight: FontWeight.w900,
          height: 1.0,
          letterSpacing: 1.0,
          shadows: const [
            Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
      ),
    );
  }
}

class _SkewedLabel extends StatelessWidget {
  const _SkewedLabel({required this.text, required this.seed});

  final String text;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final angle = (math.Random(seed.hashCode).nextDouble() - 0.5) * 0.12;
    return Transform.rotate(
      alignment: Alignment.centerLeft,
      angle: angle,
      child: Text(text, style: AppTextStyles.label),
    );
  }
}

class _FunInfoRow extends StatelessWidget {
  const _FunInfoRow({
    required this.label,
    required this.value,
    required this.seed,
  });

  final String label;
  final String value;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(seed.hashCode);
    final rowAngle = (rng.nextDouble() - 0.5) * 0.10;
    final labelAngle = (rng.nextDouble() - 0.5) * 0.14;
    final valueAngle = (rng.nextDouble() - 0.5) * 0.12;
    final colors = [greenColor, redColor, amberColor, blueColor];
    final labelColor = colors[rng.nextInt(colors.length)];
    final valueColor = colors[rng.nextInt(colors.length)];

    return Transform.rotate(
      alignment: Alignment.centerLeft,
      angle: rowAngle,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              alignment: Alignment.center,
              angle: labelAngle,
              child: Text(
                '$label  ',
                style: TextStyle(
                  color: labelColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
            Transform.rotate(
              alignment: Alignment.center,
              angle: valueAngle,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  shadows: const [
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
      ),
    );
  }
}

class _ScheduleOverview extends StatelessWidget {
  const _ScheduleOverview({
    required this.machine,
    required this.provider,
    required this.activeReservations,
    required this.waitingReservations,
    required this.myReservation,
    required this.capacity,
    required this.hasVariants,
  });

  final MachineModel machine;
  final GymProvider provider;
  final List<ReservationModel> activeReservations;
  final List<ReservationModel> waitingReservations;
  final ReservationModel? myReservation;
  final int capacity;
  final bool hasVariants;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final schedule = _scheduleReservations();
    final nextReservation = _nextReservation(now);
    final availability = _availabilitySummary(now);
    final items = [
      _ScheduleItem(
        label: '현재 사용 중',
        title: _currentUsageTitle(),
        detail: _currentUsageDetail(),
        color: textColor,
        icon: Icons.fitness_center_rounded,
      ),
      _ScheduleItem(
        label: '다음 예약',
        title: nextReservation == null
            ? '다음 예약 없음'
            : formatTimeRange(
                nextReservation.reservedStartAt,
                nextReservation.reservedEndAt,
              ),
        detail: nextReservation == null
            ? '아직 잡힌 예약이 없습니다.'
            : _reservationDetail(nextReservation),
        color: amberColor,
        icon: Icons.schedule_rounded,
      ),
      _ScheduleItem(
        label: '내 예약',
        title: _myReservationTitle(),
        detail: _myReservationDetail(),
        color: blueColor,
        icon: Icons.person_rounded,
      ),
      _ScheduleItem(
        label: '예약 가능한 시간',
        title: availability.title,
        detail: availability.detail,
        color: greenColor,
        icon: Icons.event_available_rounded,
      ),
    ];

    return _WobblyCard(
      seed: '${machine.machineId}_schedule',
      shadows: _randomShadows('${machine.machineId}_schedule'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in items.asMap().entries) ...[
            _ScheduleLine(item: entry.value),
            if (entry.key != items.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          _ScheduleTimeline(
            reservations: schedule,
            myReservation: myReservation,
            hasVariants: hasVariants,
            machineName: machine.name,
          ),
        ],
      ),
    );
  }

  String _currentUsageTitle() {
    if (activeReservations.isEmpty) return '지금 비어 있음';
    if (capacity > 1) return '${activeReservations.length}/$capacity자리 사용 중';
    return '사용 중';
  }

  String _currentUsageDetail() {
    if (activeReservations.isEmpty) {
      return '지금 사용 중인 사람이 없습니다.';
    }

    final details = activeReservations
        .take(2)
        .map((reservation) {
          final range = formatTimeRange(
            reservation.reservedStartAt,
            reservation.reservedEndAt,
          );
          return '${reservation.userName} $range';
        })
        .join(' · ');
    final extraCount = activeReservations.length - 2;
    return extraCount > 0 ? '$details 외 $extraCount명' : details;
  }

  ReservationModel? _nextReservation(DateTime now) {
    for (final reservation in waitingReservations) {
      final endAt = reservation.reservedEndAt;
      if (endAt == null || endAt.isAfter(now)) return reservation;
    }
    return null;
  }

  String _myReservationTitle() {
    final reservation = myReservation;
    if (reservation == null) return '내 예약 없음';
    return formatTimeRange(
      reservation.reservedStartAt,
      reservation.reservedEndAt,
    );
  }

  String _myReservationDetail() {
    final reservation = myReservation;
    if (reservation == null) return '이 기구에 잡아둔 예약이 없습니다.';
    final statusText = reservation.status == ReservationStatus.active
        ? '사용 시간'
        : '예약 시간';
    return '$statusText · ${_reservationTimeDetail(reservation)}';
  }

  String _reservationDetail(ReservationModel reservation) {
    return '${reservation.userName} · ${_reservationTimeDetail(reservation)}';
  }

  String _reservationTimeDetail(ReservationModel reservation) {
    final range = formatTimeRange(
      reservation.reservedStartAt,
      reservation.reservedEndAt,
    );
    if (!hasVariants || reservation.machineName == machine.name) {
      return range;
    }
    return '${reservation.machineName} · $range';
  }

  _AvailabilitySummary _availabilitySummary(DateTime now) {
    if (machine.status == MachineStatus.repair) {
      return const _AvailabilitySummary(
        title: '점검 중',
        detail: '점검이 끝난 뒤 예약할 수 있습니다.',
      );
    }

    if (hasVariants) {
      return const _AvailabilitySummary(
        title: '종류 선택 후 확인',
        detail: '덤벨/바벨은 무게별 예약 시간이 따로 잡힙니다.',
      );
    }

    final schedule = _scheduleReservations();
    final availableNow = provider.hasAvailableUnitNow(machine.machineId);
    if (availableNow) {
      final remainingNow = math.max(
        1,
        capacity - _overlapCountAt(now, schedule),
      );
      final title = capacity > 1 ? '지금 $remainingNow자리 가능' : '지금 가능';
      final nextBusyStart = _nextBusyStartAfter(now, schedule);
      final detail = nextBusyStart == null
          ? '잡힌 예약이 없어 바로 사용할 수 있습니다.'
          : capacity > 1
          ? '다음 예약은 ${formatTimeOnly(nextBusyStart)} 예정입니다.'
          : '다음 예약 ${formatTimeOnly(nextBusyStart)} 전까지 비어 있습니다.';
      return _AvailabilitySummary(title: title, detail: detail);
    }

    final nextAvailableStart = _nextAvailableStartAfter(now, schedule);
    if (nextAvailableStart == null) {
      return const _AvailabilitySummary(
        title: '사용 종료 후 가능',
        detail: '현재 사용 종료 시간이 확정되면 빈 시간이 표시됩니다.',
      );
    }

    return _AvailabilitySummary(
      title: '${formatTimeOnly(nextAvailableStart)}부터 가능',
      detail: '예약 또는 사용이 끝난 뒤 자리가 생깁니다.',
    );
  }

  List<ReservationModel> _scheduleReservations() {
    final reservationsById = <String, ReservationModel>{};
    for (final reservation in activeReservations) {
      reservationsById[reservation.reservationId] = reservation;
    }
    for (final reservation in waitingReservations) {
      reservationsById[reservation.reservationId] = reservation;
    }
    final result = reservationsById.values.toList()
      ..sort((a, b) => _reservationStart(a).compareTo(_reservationStart(b)));
    return result;
  }

  DateTime _reservationStart(ReservationModel reservation) {
    return reservation.reservedStartAt ?? reservation.createdAt;
  }

  DateTime? _nextBusyStartAfter(DateTime now, List<ReservationModel> schedule) {
    for (final reservation in schedule) {
      final startAt = reservation.reservedStartAt;
      if (startAt != null && startAt.isAfter(now)) return startAt;
    }
    return null;
  }

  DateTime? _nextAvailableStartAfter(
    DateTime now,
    List<ReservationModel> schedule,
  ) {
    final candidates = <DateTime>[];
    for (final reservation in schedule) {
      final endAt = reservation.reservedEndAt;
      if (endAt != null && endAt.isAfter(now)) {
        candidates.add(endAt);
      }
    }
    candidates.sort();

    DateTime? lastCandidate;
    for (final candidate in candidates) {
      if (lastCandidate != null && candidate.isAtSameMomentAs(lastCandidate)) {
        continue;
      }
      lastCandidate = candidate;
      if (_overlapCountAt(candidate, schedule) < capacity) {
        return candidate;
      }
    }
    return null;
  }

  int _overlapCountAt(DateTime time, List<ReservationModel> schedule) {
    final probeEnd = time.add(const Duration(minutes: 1));
    return schedule.where((reservation) {
      final startAt = reservation.reservedStartAt;
      final endAt = reservation.reservedEndAt;
      final hasStarted = startAt == null || startAt.isBefore(probeEnd);
      if (!hasStarted) return false;
      if (endAt == null) return reservation.status == ReservationStatus.active;
      return endAt.isAfter(time);
    }).length;
  }
}

class _ScheduleItem {
  const _ScheduleItem({
    required this.label,
    required this.title,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String label;
  final String title;
  final String detail;
  final Color color;
  final IconData icon;
}

class _AvailabilitySummary {
  const _AvailabilitySummary({required this.title, required this.detail});

  final String title;
  final String detail;
}

class _ScheduleLine extends StatelessWidget {
  const _ScheduleLine({required this.item});

  final _ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Color.lerp(item.color, bgColor, 0.78),
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: const [
          BoxShadow(color: borderColor, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2.5),
            ),
            child: Icon(item.icon, size: 21, color: borderColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ScheduleLabelChip(label: item.label, color: item.color),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: borderColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleLabelChip extends StatelessWidget {
  const _ScheduleLabelChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: borderColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ScheduleTimeline extends StatelessWidget {
  const _ScheduleTimeline({
    required this.reservations,
    required this.myReservation,
    required this.hasVariants,
    required this.machineName,
  });

  final List<ReservationModel> reservations;
  final ReservationModel? myReservation;
  final bool hasVariants;
  final String machineName;

  @override
  Widget build(BuildContext context) {
    final visibleReservations = reservations.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline_rounded, color: textColor, size: 20),
              SizedBox(width: 6),
              Text(
                '오늘 예약 순서',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (visibleReservations.isEmpty)
            const Text(
              '남은 예약이 없습니다.',
              textAlign: TextAlign.center,
              style: AppTextStyles.empty,
            )
          else
            for (final entry in visibleReservations.asMap().entries) ...[
              _ScheduleTimelineRow(
                reservation: entry.value,
                isMine:
                    myReservation?.reservationId == entry.value.reservationId,
                hasVariants: hasVariants,
                machineName: machineName,
              ),
              if (entry.key != visibleReservations.length - 1)
                const SizedBox(height: 8),
            ],
          if (reservations.length > visibleReservations.length) ...[
            const SizedBox(height: 8),
            Text(
              '외 ${reservations.length - visibleReservations.length}건 더 있음',
              textAlign: TextAlign.center,
              style: AppTextStyles.label,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleTimelineRow extends StatelessWidget {
  const _ScheduleTimelineRow({
    required this.reservation,
    required this.isMine,
    required this.hasVariants,
    required this.machineName,
  });

  final ReservationModel reservation;
  final bool isMine;
  final bool hasVariants;
  final String machineName;

  @override
  Widget build(BuildContext context) {
    final isActive = reservation.status == ReservationStatus.active;
    final color = isMine
        ? blueColor
        : isActive
        ? redColor
        : amberColor;
    final statusText = isMine
        ? '내 예약'
        : isActive
        ? '사용 중'
        : '예약';
    final detail = hasVariants && reservation.machineName != machineName
        ? '${reservation.userName} · ${reservation.machineName}'
        : reservation.userName;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color.lerp(color, bgColor, 0.82),
        border: Border.all(color: borderColor, width: 2.5),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatTimeOnly(reservation.reservedStartAt),
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '~ ${formatTimeOnly(reservation.reservedEndAt)}',
                  style: const TextStyle(
                    color: borderColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 4, height: 42, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ScheduleLabelChip(label: statusText, color: color),
                const SizedBox(height: 5),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MinutesDialog extends StatefulWidget {
  const _MinutesDialog({
    required this.title,
    required this.maxMinutes,
    required this.initialMinutes,
    required this.helperText,
    required this.confirmLabel,
  });

  final String title;
  final int maxMinutes;
  final int initialMinutes;
  final String helperText;
  final String confirmLabel;

  @override
  State<_MinutesDialog> createState() => _MinutesDialogState();
}

class _MinutesDialogState extends State<_MinutesDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialMinutes.clamp(1, widget.maxMinutes).toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: '분',
          helperText: widget.helperText,
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }

  void _submit() {
    final minutes = int.tryParse(_controller.text.trim());
    if (minutes == null || minutes < 1 || minutes > widget.maxMinutes) {
      setState(() {
        _errorText = '1~${widget.maxMinutes} 사이의 숫자를 입력하세요.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(minutes);
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.showStart,
    required this.canReserve,
    required this.canCancel,
    required this.canFinish,
    required this.isLoading,
    required this.onStart,
    required this.onReserve,
    required this.onCancel,
    required this.onFinish,
  });

  final bool showStart;
  final bool canReserve;
  final bool canCancel;
  final bool canFinish;
  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback onReserve;
  final VoidCallback? onCancel;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        if (showStart)
          _Button(label: '사용 시작', onPressed: isLoading ? null : onStart),
        if (canReserve)
          _Button(label: '예약하기', onPressed: isLoading ? null : onReserve),
        if (canCancel)
          _Button(
            label: '예약 취소',
            onPressed: isLoading ? null : onCancel,
            isDanger: true,
          ),
        if (canFinish)
          _Button(
            label: '사용 종료',
            onPressed: isLoading ? null : onFinish,
            isDanger: true,
          ),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: isDanger ? redColor : blueColor,
        foregroundColor: textColor,
        minimumSize: const Size(132, 48),
      ),
      child: Text(label),
    );
  }
}

class _VariantPickerDialog extends StatefulWidget {
  const _VariantPickerDialog({required this.title, required this.variants});

  final String title;
  final List<String> variants;

  @override
  State<_VariantPickerDialog> createState() => _VariantPickerDialogState();
}

class _VariantPickerDialogState extends State<_VariantPickerDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Transform.rotate(
        angle: -0.03,
        alignment: Alignment.centerLeft,
        child: Text(
          widget.title,
          style: const TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 14,
            runSpacing: 18,
            children: widget.variants.map((v) {
              final isSelected = _selected == v;
              final rng = math.Random(v.hashCode);
              final angle = (rng.nextDouble() - 0.5) * 0.18;
              final shadows = isSelected
                  ? [
                      const BoxShadow(
                        color: redColor,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                      const BoxShadow(
                        color: blueColor,
                        offset: Offset(-2, -2),
                        blurRadius: 0,
                      ),
                    ]
                  : _chipShadows(v);
              final fillColor = isSelected ? blueColor : surfaceColor;

              return GestureDetector(
                onTap: () => setState(() => _selected = v),
                child: Transform.rotate(
                  angle: angle,
                  child: CustomPaint(
                    painter: _WobblyCardPainter(
                      seed: v,
                      shadows: shadows,
                      fillColor: fillColor,
                      jitterScale: 0.35,
                    ),
                    child: ClipPath(
                      clipper: _WobblyCardClipper(seed: v, jitterScale: 0.35),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          v,
                          style: TextStyle(
                            color: isSelected ? bgColor : textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            height: 1.0,
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
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('선택'),
        ),
      ],
    );
  }
}
