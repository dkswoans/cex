import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
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
            (machine.status == MachineStatus.reserved &&
                myReservation?.status == ReservationStatus.active);
        final canReserve =
            (machine.status == MachineStatus.using ||
                machine.status == MachineStatus.reserved) &&
            myReservation == null;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(title: Text(machine.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                if (machine.description != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    machine.description!,
                                    style: const TextStyle(
                                      color: mutedTextColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          StatusBadge(status: machine.status),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _InfoRow(
                        label: '최대 사용 시간',
                        value: '${machine.maxUseMinutes}분',
                      ),
                      _InfoRow(
                        label: '현재 사용자',
                        value: machine.currentUserName ?? '-',
                      ),
                      _InfoRow(
                        label: '시작 시간',
                        value: formatTimeOnly(machine.startedAt),
                      ),
                      _InfoRow(
                        label: '종료 예정',
                        value: formatTimeOnly(machine.endAt),
                      ),
                      _InfoRow(
                        label: '남은 시간',
                        value: formatRemainingMinutes(
                          provider.getRemainingMinutes(machine),
                        ),
                      ),
                      _InfoRow(
                        label: '대기 인원',
                        value: '${provider.getWaitingCount(machineId)}명',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '대기자 목록',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (reservations.isEmpty)
                const _EmptyPanel(text: '대기자가 없습니다.')
              else
                ...reservations.map(
                  (reservation) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: lightGrayColor,
                        foregroundColor: textColor,
                        child: Text('${reservation.order}'),
                      ),
                      title: Text(
                        reservation.userName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(reservationStatusText(reservation.status)),
                      trailing: reservation.userId == currentUser?.userId
                          ? TextButton(
                              onPressed: () async {
                                final message = await provider
                                    .cancelReservation(
                                      reservation.reservationId,
                                    );
                                if (!context.mounted) return;
                                _showMessage(context, message);
                              },
                              child: const Text(
                                '예약 취소',
                                style: TextStyle(color: redColor),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (machine.status == MachineStatus.repair)
                const _EmptyPanel(text: '점검 중인 기구입니다.')
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
                    final message = await provider.reserveMachine(machineId);
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

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: const TextStyle(color: mutedTextColor)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: mutedTextColor),
      ),
    );
  }
}
