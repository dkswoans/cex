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
        final myReservation = provider.getMyReservationForMachine(machineId);
        final isCurrentUserUsing =
            currentUser != null &&
            machine.currentUserId != null &&
            machine.currentUserId == currentUser.userId;
        final canStart =
            machine.status == MachineStatus.available ||
            myReservation?.status == ReservationStatus.active;
        final canReserve =
            machine.status != MachineStatus.repair &&
            !isCurrentUserUsing &&
            myReservation == null;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(title: Text(machine.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppRecordCard(
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
                              Text(
                                machine.name,
                                style: AppTextStyles.itemTitle,
                              ),
                              if (machine.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  machine.description!,
                                  style: AppTextStyles.label,
                                ),
                              ],
                            ],
                          ),
                        ),
                        StatusBadge(status: machine.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppInfoRow(
                      label: '최대 사용 시간',
                      value: '${machine.maxUseMinutes}분',
                    ),
                    AppInfoRow(
                      label: '현재 사용자',
                      value: machine.currentUserName ?? '-',
                    ),
                    AppInfoRow(
                      label: '시작 시간',
                      value: formatTimeOnly(machine.startedAt),
                    ),
                    AppInfoRow(
                      label: '종료 예정',
                      value: formatTimeOnly(machine.endAt),
                    ),
                    AppInfoRow(
                      label: '남은 시간',
                      value: formatRemainingMinutes(
                        provider.getRemainingMinutes(machine),
                      ),
                    ),
                    AppInfoRow(
                      label: '대기 인원',
                      value: '${provider.getWaitingCount(machineId)}명',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const AppSectionTitle('대기자 목록'),
              if (reservations.isEmpty)
                const AppEmptyPanel(text: '대기자가 없습니다.')
              else
                ...reservations.map(
                  (reservation) => AppRecordCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: lightGrayColor,
                          foregroundColor: textColor,
                          child: Text(
                            '${reservation.order}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reservation.userName,
                                style: AppTextStyles.itemTitle,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                reservationStatusText(reservation.status),
                                style: AppTextStyles.label,
                              ),
                            ],
                          ),
                        ),
                        if (reservation.userId == currentUser?.userId)
                          TextButton(
                            onPressed: () async {
                              final message = await provider.cancelReservation(
                                reservation.reservationId,
                              );
                              if (!context.mounted) return;
                              _showMessage(context, message);
                            },
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
                  onStart: () async {
                    final message = await provider.startUsingMachine(machineId);
                    if (!context.mounted) return;
                    _showMessage(context, message);
                  },
                  onReserve: () async {
                    final request = await _askReservation(context);
                    if (request == null) return;
                    final message = await provider.reserveMachine(
                      machineId,
                      minutes: request.minutes,
                      startAt: request.startAt,
                    );
                    if (!context.mounted) return;
                    _showMessage(context, message);
                  },
                  onCancel: myReservation == null
                      ? null
                      : () async {
                          final message = await provider.cancelReservation(
                            myReservation.reservationId,
                          );
                          if (!context.mounted) return;
                          _showMessage(context, message);
                        },
                  onFinish: () async {
                    final message = await provider.finishUsingMachine(
                      machineId,
                    );
                    if (!context.mounted) return;
                    _showMessage(context, message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<_ReservationRequest?> _askReservation(BuildContext context) {
    return showDialog<_ReservationRequest>(
      context: context,
      builder: (_) => const _ReservationDialog(),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReservationRequest {
  const _ReservationRequest({required this.startAt, required this.minutes});

  final DateTime startAt;
  final int minutes;
}

class _ReservationDialog extends StatefulWidget {
  const _ReservationDialog();

  @override
  State<_ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<_ReservationDialog> {
  final _minutesController = TextEditingController(text: '15');
  TimeOfDay _startTime = const TimeOfDay(hour: 21, minute: 0);
  String? _errorText;

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
              helperText: '1분부터 15분까지 예약할 수 있습니다.',
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
    if (minutes == null || minutes < 1 || minutes > 15) {
      setState(() {
        _errorText = '이용 시간은 1~15분으로 입력하세요.';
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
    required this.onStart,
    required this.onReserve,
    required this.onCancel,
    required this.onFinish,
  });

  final bool canStart;
  final bool canReserve;
  final bool canCancel;
  final bool canFinish;
  final VoidCallback onStart;
  final VoidCallback onReserve;
  final VoidCallback? onCancel;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canStart) _Button(label: '사용 시작', onPressed: onStart),
        if (canReserve) _Button(label: '예약하기', onPressed: onReserve),
        if (canCancel)
          _Button(label: '예약 취소', onPressed: onCancel, isDanger: true),
        if (canFinish)
          _Button(label: '사용 종료', onPressed: onFinish, isDanger: true),
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
      ),
      child: Text(label),
    );
  }
}
