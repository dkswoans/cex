import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/app_design.dart';
import '../widgets/status_badge.dart';


class MachineDetailPage extends StatelessWidget {
  const MachineDetailPage({super.key, required this.machineId});

  final String machineId;

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final machine = provider.getMachineById(machineId);
        final currentUser = provider.currentUser;
        final reservations = provider.getReservationsByMachine(machineId);
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
                angle: (math.Random(machineId.hashCode ^ 0xABCD).nextDouble() - 0.5) * 0.06,
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
                      _FunInfoRow(label: '최대 사용 시간', value: '$maxUseMinutes분', seed: '${machineId}0'),
                      _FunInfoRow(label: '현재 사용자', value: activeUserText, seed: '${machineId}1'),
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
              AppSectionTitle(isMultiUnitMachine ? '현재 사용 현황' : '현재 사용자'),
              if (activeReservations.isEmpty)
                Transform.rotate(
                  angle: (math.Random('${machineId}_empty_active'.hashCode ^ 0xABCD).nextDouble() - 0.5) * 0.06,
                  child: _WobblyCard(
                    seed: '${machineId}_empty_active',
                    shadows: _randomShadows('${machineId}_empty_active'),
                    child: const Center(child: Text('현재 사용 중인 사람이 없습니다.', style: AppTextStyles.empty)),
                  ),
                )
              else
                for (final entry in activeReservations.asMap().entries)
                  Transform.rotate(
                    angle: (math.Random('${machineId}_active_${entry.key}'.hashCode ^ 0xABCD).nextDouble() - 0.5) * 0.06,
                    child: _WobblyCard(
                      seed: '${machineId}_active_${entry.key}',
                      shadows: _randomShadows('${machineId}_active_${entry.key}'),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: amberColor,
                            foregroundColor: textColor,
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(fontWeight: FontWeight.w900),
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
                  angle: (math.Random('${machineId}_empty_wait'.hashCode ^ 0xABCD).nextDouble() - 0.5) * 0.06,
                  child: _WobblyCard(
                    seed: '${machineId}_empty_wait',
                    shadows: _randomShadows('${machineId}_empty_wait'),
                    child: const Center(child: Text('대기자가 없습니다.', style: AppTextStyles.empty)),
                  ),
                )
              else
                for (final entry in reservations.asMap().entries)
                  Transform.rotate(
                    angle: (math.Random('${machineId}_wait_${entry.key}'.hashCode ^ 0xABCD).nextDouble() - 0.5) * 0.06,
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
                              style: const TextStyle(fontWeight: FontWeight.w900),
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
                                const SizedBox(height: 3),
                                Text('사용 중', style: AppTextStyles.label),
                              ],
                            ),
                          ),
                          if (entry.value.userId == currentUser?.userId)
                            TextButton(
                              onPressed: provider.isActionLoading || provider.isLoading
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
                    ),
                  ),
              const SizedBox(height: 16),
              if (machine.status == MachineStatus.repair)
                const AppEmptyPanel(text: '점검 중인 기구입니다.')
              else
                _ActionButtons(
                  canStart: canStart,
                  canReserve: canReserve,
                  canCancel: myReservation != null,
                  canFinish: isCurrentUserUsing,
                  isLoading: provider.isActionLoading || provider.isLoading,
                  onStart: () async {
                    final variant = variants.isEmpty
                        ? null
                        : await _askVariant(
                            context,
                            title: '바벨 무게',
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
                            title: '바벨 무게',
                            variants: variants,
                          );
                    if (variants.isNotEmpty && variant == null) return;
                    if (!context.mounted) return;
                    final request = await _askReservation(
                      context,
                      maxMinutes: maxReservationMinutes,
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
      builder: (_) => SimpleDialog(
        title: Text(title),
        children: [
          for (final variant in variants)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(variant),
              child: Text(variant),
            ),
        ],
      ),
    );
  }

  Future<_ReservationRequest?> _askReservation(
    BuildContext context, {
    required int maxMinutes,
  }) {
    return showDialog<_ReservationRequest>(
      context: context,
      builder: (_) => _ReservationDialog(maxMinutes: maxMinutes),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

Path _buildWobblyPath(String seed, Size size) {
  final rng = math.Random(seed.hashCode);
  double j() {
    final sign = rng.nextBool() ? 1 : -1;
    return sign * (3 + rng.nextDouble() * 3);
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
  const _WobblyCardPainter({required this.seed, required this.shadows});

  final String seed;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildWobblyPath(seed, size);

    for (final shadow in shadows) {
      canvas.drawPath(
        path.shift(shadow.offset),
        Paint()..color = shadow.color,
      );
    }

    canvas.drawPath(path, Paint()..color = surfaceColor);

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
  }

  @override
  bool shouldRepaint(covariant _WobblyCardPainter old) => old.seed != seed;
}

class _WobblyCardClipper extends CustomClipper<Path> {
  const _WobblyCardClipper({required this.seed});

  final String seed;

  @override
  Path getClip(Size size) => _buildWobblyPath(seed, size);

  @override
  bool shouldReclip(covariant _WobblyCardClipper old) => old.seed != seed;
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
                    Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
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
                    Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
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

class _ReservationRequest {
  const _ReservationRequest({required this.startAt, required this.minutes});

  final DateTime startAt;
  final int minutes;
}

class _ReservationDialog extends StatefulWidget {
  const _ReservationDialog({required this.maxMinutes});

  final int maxMinutes;

  @override
  State<_ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<_ReservationDialog> {
  late final TextEditingController _minutesController;
  TimeOfDay _startTime = const TimeOfDay(hour: 21, minute: 0);
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController(
      text: widget.maxMinutes.clamp(1, 30).toString(),
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('예약 시간'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('시작 시간'),
            subtitle: const Text('21:00~22:50 사이에서 선택'),
            trailing: FilledButton(
              onPressed: _pickStartTime,
              child: Text(_formatTime(_startTime)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '분',
              helperText: '1분부터 ${widget.maxMinutes}분까지 예약할 수 있습니다.',
              errorText: _errorText,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('예약하기')),
      ],
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: '예약 시작 시간',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked == null) return;
    setState(() {
      _startTime = picked;
      _errorText = null;
    });
  }

  void _submit() {
    final minutes = int.tryParse(_minutesController.text.trim());
    if (minutes == null || minutes < 1 || minutes > widget.maxMinutes) {
      setState(() {
        _errorText = '이용 시간은 1~${widget.maxMinutes}분으로 입력하세요.';
      });
      return;
    }

    final startAt = _todayKoreaTimeAsUtc(_startTime.hour, _startTime.minute);
    FocusScope.of(context).unfocus();
    Navigator.of(
      context,
    ).pop(_ReservationRequest(startAt: startAt, minutes: minutes));
  }

  DateTime _todayKoreaTimeAsUtc(int hour, int minute) {
    final nowKst = _koreaTime(DateTime.now());
    var startAt = DateTime.utc(
      nowKst.year,
      nowKst.month,
      nowKst.day,
      hour - 9,
      minute,
    );
    if (_koreaTime(startAt).isBefore(nowKst)) {
      startAt = startAt.add(const Duration(days: 1));
    }
    return startAt;
  }

  DateTime _koreaTime(DateTime dateTime) {
    return dateTime.toUtc().add(const Duration(hours: 9));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
    required this.canStart,
    required this.canReserve,
    required this.canCancel,
    required this.canFinish,
    required this.isLoading,
    required this.onStart,
    required this.onReserve,
    required this.onCancel,
    required this.onFinish,
  });

  final bool canStart;
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
        if (canStart) _Button(label: '사용 시작', onPressed: isLoading ? null : onStart),
        if (canReserve) _Button(label: '예약하기', onPressed: isLoading ? null : onReserve),
        if (canCancel)
          _Button(label: '예약 취소', onPressed: isLoading ? null : onCancel, isDanger: true),
        if (canFinish)
          _Button(label: '사용 종료', onPressed: isLoading ? null : onFinish, isDanger: true),
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
