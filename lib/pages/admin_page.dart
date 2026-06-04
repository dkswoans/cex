import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../widgets/app_design.dart';
import '../widgets/status_badge.dart';
import '../widgets/wobbly_card.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final totalCount = provider.machines.length;
        final availableCount = provider.machines
            .where((m) => m.status == MachineStatus.available)
            .length;
        final usingCount = provider.machines
            .where((m) => m.status == MachineStatus.using)
            .length;
        final repairCount = provider.machines
            .where((m) => m.status == MachineStatus.repair)
            .length;
        final isLoading = provider.isActionLoading || provider.isLoading;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('관리'),
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
                _sectionLabel('현황'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: '전체',
                        value: '$totalCount',
                        seed: 'metric_total',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _MetricCard(
                        label: '가능',
                        value: '$availableCount',
                        seed: 'metric_avail',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _MetricCard(
                        label: '사용 중',
                        value: '$usingCount',
                        seed: 'metric_using',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _MetricCard(
                        label: '점검',
                        value: '$repairCount',
                        seed: 'metric_repair',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _tiltedCard(
                  seed: 'reset_btn',
                  shadows: const [
                    BoxShadow(color: redColor, offset: Offset(4, 4), blurRadius: 0),
                  ],
                  child: GestureDetector(
                    onTap: isLoading ? null : () => _confirmReset(context, provider),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.restore, color: redColor, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '데모 데이터 초기화',
                            style: TextStyle(
                              color: redColor,
                              fontSize: 15,
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
                        ],
                      ),
                    ),
                  ),
                ),
                _sectionLabel('기구별 예약 시간표'),
                _tiltedCard(
                  seed: 'timeline_card',
                  padding: const EdgeInsets.all(12),
                  child: _ReservationTimeline(
                    machines: provider.machines,
                    reservations: provider.reservations,
                  ),
                ),
                _sectionLabel('기구 목록'),
                ...provider.machines.map(
                  (machine) => _tiltedCard(
                    seed: 'machine_${machine.machineId}',
                    child: _MachineCardContent(
                      machine: machine,
                      provider: provider,
                      isLoading: isLoading,
                      onEdit: () => _showEditDialog(context, provider, machine),
                      onToggleRepair: () =>
                          _confirmToggleRepair(context, provider, machine),
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

  Future<void> _confirmToggleRepair(
    BuildContext context,
    GymProvider provider,
    MachineModel machine,
  ) async {
    final goingToRepair = machine.status != MachineStatus.repair;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(goingToRepair ? '점검 전환' : '점검 해제'),
        content: Text(
          goingToRepair
              ? '${machine.name}을(를) 점검 상태로 변경합니다.\n현재 예약이 모두 취소됩니다.'
              : '${machine.name}의 점검을 해제합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final message = await provider.toggleRepairStatus(machine.machineId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showEditDialog(
    BuildContext context,
    GymProvider provider,
    MachineModel machine,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => _MachineEditDialog(machine: machine, provider: provider),
    );
  }

  Future<void> _confirmReset(BuildContext context, GymProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('데모 초기화'),
        content: const Text('모든 예약과 사용 기록이 삭제되고\n기구가 기본 상태로 초기화됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: redColor),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await provider.resetMachinesForDemo();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('초기화가 완료되었습니다.')));
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────

Widget _tiltedCard({
  required String seed,
  required Widget child,
  List<BoxShadow>? shadows,
  EdgeInsets padding = const EdgeInsets.all(AppSpacing.lg),
}) {
  final angle = (math.Random(seed.hashCode ^ 0xABCD).nextDouble() - 0.5) * 0.06;
  return Transform.rotate(
    angle: angle,
    child: WobblyCard(
      seed: seed,
      shadows: shadows ?? randomShadows(seed),
      padding: padding,
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
        fontSize: 26,
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

Widget _funRow(String label, String value, String seed) {
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: labelAngle,
            child: Text(
              '$label  ',
              style: TextStyle(
                color: labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
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
                fontSize: 14,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── section widgets ───────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
    final cardAngle = (rng.nextDouble() - 0.5) * 0.10;
    final valueAngle = (rng.nextDouble() - 0.5) * 0.14;
    final labelAngle = (rng.nextDouble() - 0.5) * 0.12;
    const valueColors = [blueColor, redColor, greenColor, amberColor];
    final valueColor = valueColors[rng.nextInt(valueColors.length)];

    return Transform.rotate(
      angle: cardAngle,
      child: WobblyCard(
        seed: seed,
        shadows: chipShadows(seed),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            Transform.rotate(
              angle: valueAngle,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Transform.rotate(
              angle: labelAngle,
              child: Text(
                label,
                style: const TextStyle(
                  color: mutedTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
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

class _MachineCardContent extends StatelessWidget {
  const _MachineCardContent({
    required this.machine,
    required this.provider,
    required this.isLoading,
    required this.onEdit,
    required this.onToggleRepair,
  });

  final MachineModel machine;
  final GymProvider provider;
  final bool isLoading;
  final VoidCallback onEdit;
  final VoidCallback onToggleRepair;

  @override
  Widget build(BuildContext context) {
    final seed = 'mc_${machine.machineId}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _bigTitle(machine.name, '${seed}_title')),
            Transform.rotate(
              angle: 0.05,
              child: StatusBadge(status: machine.status),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _funRow('최대 사용', '${machine.maxUseMinutes}분', '${seed}_max'),
        _funRow('사용자', machine.currentUserName ?? '-', '${seed}_user'),
        _funRow(
          '대기',
          '${provider.getWaitingCount(machine.machineId)}명',
          '${seed}_wait',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: isLoading ? null : onEdit,
              child: const Text('수정'),
            ),
            OutlinedButton(
              onPressed: isLoading ? null : onToggleRepair,
              style: machine.status == MachineStatus.repair
                  ? OutlinedButton.styleFrom(foregroundColor: greenColor)
                  : OutlinedButton.styleFrom(foregroundColor: redColor),
              child: Text(
                machine.status == MachineStatus.repair ? '점검 해제' : '점검 전환',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── machine edit dialog ───────────────────────────────────────────────────────

class _MachineEditDialog extends StatefulWidget {
  const _MachineEditDialog({required this.machine, required this.provider});

  final MachineModel machine;
  final GymProvider provider;

  @override
  State<_MachineEditDialog> createState() => _MachineEditDialogState();
}

class _MachineEditDialogState extends State<_MachineEditDialog> {
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _mapXCtrl;
  late final TextEditingController _mapYCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _minutesCtrl = TextEditingController(
      text: widget.machine.maxUseMinutes.toString(),
    );
    _mapXCtrl = TextEditingController(
      text: widget.machine.mapX.toStringAsFixed(3),
    );
    _mapYCtrl = TextEditingController(
      text: widget.machine.mapY.toStringAsFixed(3),
    );
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _mapXCtrl.dispose();
    _mapYCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.machine.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _minutesCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '최대 사용 시간 (분)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mapXCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '지도 X (0~1)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _mapYCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '지도 Y (0~1)'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: redColor, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }

  Future<void> _submit() async {
    final minutes = int.tryParse(_minutesCtrl.text.trim());
    final mapX = double.tryParse(_mapXCtrl.text.trim());
    final mapY = double.tryParse(_mapYCtrl.text.trim());

    if (minutes == null || minutes < 1 || minutes > 120) {
      setState(() => _error = '사용 시간은 1~120 사이 숫자로 입력하세요.');
      return;
    }
    if (mapX == null || mapX < 0 || mapX > 1) {
      setState(() => _error = 'X 좌표는 0~1 사이 숫자로 입력하세요.');
      return;
    }
    if (mapY == null || mapY < 0 || mapY > 1) {
      setState(() => _error = 'Y 좌표는 0~1 사이 숫자로 입력하세요.');
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    final message = await widget.provider.updateMachineSettings(
      widget.machine.machineId,
      maxUseMinutes: minutes,
      mapX: mapX,
      mapY: mapY,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── reservation timeline ──────────────────────────────────────────────────────

class _ReservationTimeline extends StatelessWidget {
  const _ReservationTimeline({
    required this.machines,
    required this.reservations,
  });

  final List<MachineModel> machines;
  final List<ReservationModel> reservations;

  static const _rowHeight = 36.0;
  static const _headerHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    if (machines.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            '기구 정보 없음',
            style: TextStyle(
              color: mutedTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
    final height = _headerHeight + machines.length * _rowHeight;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TimelinePainter(
          machines: machines,
          reservations: reservations,
          now: DateTime.now(),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.machines,
    required this.reservations,
    required this.now,
  });

  final List<MachineModel> machines;
  final List<ReservationModel> reservations;
  final DateTime now;

  static const _openHour = 21;
  static const _closeHour = 23;
  static const _totalMinutes = (_closeHour - _openHour) * 60.0;
  static const _labelWidth = 72.0;
  static const _rowHeight = 36.0;
  static const _headerHeight = 22.0;
  static const _rowPad = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final tw = size.width - _labelWidth;

    const labelPaint = TextStyle(
      color: Color(0xFF7A00FF),
      fontSize: 10,
      fontWeight: FontWeight.w800,
    );
    final timeLabels = ['21:00', '21:30', '22:00', '22:30', '23:00'];
    for (var i = 0; i < timeLabels.length; i++) {
      final x = _labelWidth + i / (timeLabels.length - 1) * tw;
      final tp = TextPainter(
        text: TextSpan(text: timeLabels[i], style: labelPaint),
        textDirection: TextDirection.ltr,
      )..layout();
      final clampedX = (x - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(clampedX, 2));
    }

    for (var mi = 0; mi < machines.length; mi++) {
      final machine = machines[mi];
      final rowTop = _headerHeight + mi * _rowHeight;

      final labelTp = TextPainter(
        text: TextSpan(
          text: machine.name,
          style: const TextStyle(
            color: Color(0xFF7A00FF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: _labelWidth - 4);
      labelTp.paint(
        canvas,
        Offset(0, rowTop + (_rowHeight - labelTp.height) / 2),
      );

      final bgRect = Rect.fromLTWH(
        _labelWidth,
        rowTop + _rowPad,
        tw,
        _rowHeight - _rowPad * 2,
      );
      canvas.drawRect(bgRect, Paint()..color = const Color(0x30FFF200));
      canvas.drawRect(
        bgRect,
        Paint()
          ..color = const Color(0x30111111)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final gridPaint = Paint()
        ..color = const Color(0x30111111)
        ..strokeWidth = 1;
      for (var g = 1; g < 4; g++) {
        final gx = _labelWidth + g / 4 * tw;
        canvas.drawLine(
          Offset(gx, rowTop + _rowPad),
          Offset(gx, rowTop + _rowHeight - _rowPad),
          gridPaint,
        );
      }

      final machineReservations = reservations.where(
        (r) =>
            r.machineId == machine.machineId &&
            (r.status == ReservationStatus.waiting ||
                r.status == ReservationStatus.active),
      );

      for (final r in machineReservations) {
        final startAt = r.reservedStartAt;
        final endAt = r.reservedEndAt;
        if (startAt == null || endAt == null) continue;

        final startKst = startAt.toUtc().add(const Duration(hours: 9));
        final endKst = endAt.toUtc().add(const Duration(hours: 9));
        final openMinutes = _openHour * 60.0;
        final closeMinutes = _closeHour * 60.0;
        final sMin = (startKst.hour * 60.0 + startKst.minute)
            .clamp(openMinutes, closeMinutes);
        final eMin = (endKst.hour * 60.0 + endKst.minute)
            .clamp(openMinutes, closeMinutes);
        if (sMin >= eMin) continue;

        final left = _labelWidth + (sMin - openMinutes) / _totalMinutes * tw;
        final width = (eMin - sMin) / _totalMinutes * tw;
        final barRect = Rect.fromLTWH(
          left + 1,
          rowTop + _rowPad + 2,
          width - 2,
          _rowHeight - _rowPad * 2 - 4,
        );

        final barColor = r.status == ReservationStatus.active
            ? const Color(0xFFFF0000)
            : const Color(0xFFFF7A00);
        final rRect =
            RRect.fromRectAndRadius(barRect, const Radius.circular(3));
        canvas.drawRRect(rRect, Paint()..color = barColor);
        canvas.drawRRect(
          rRect,
          Paint()
            ..color = const Color(0xFF111111)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

        if (barRect.width > 18) {
          final userTp = TextPainter(
            text: TextSpan(
              text: r.userName,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout(maxWidth: barRect.width - 4);
          userTp.paint(
            canvas,
            Offset(
              barRect.left + 2,
              barRect.top + (barRect.height - userTp.height) / 2,
            ),
          );
        }
      }

      final nowKst = now.toUtc().add(const Duration(hours: 9));
      final nowMin = nowKst.hour * 60.0 + nowKst.minute;
      if (nowMin >= _openHour * 60.0 && nowMin < _closeHour * 60.0) {
        final nx =
            _labelWidth + (nowMin - _openHour * 60.0) / _totalMinutes * tw;
        canvas.drawLine(
          Offset(nx, rowTop),
          Offset(nx, rowTop + _rowHeight),
          Paint()
            ..color = const Color(0xFF0019FF)
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => true;
}
