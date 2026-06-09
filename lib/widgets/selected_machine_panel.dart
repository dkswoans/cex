import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import 'app_design.dart';
import 'status_badge.dart';

class SelectedMachinePanel extends StatelessWidget {
  const SelectedMachinePanel({
    super.key,
    required this.machine,
    required this.waitingCount,
    required this.remainingMinutes,
    required this.isMyReservation,
    required this.isCurrentUserUsing,
    required this.canStart,
    required this.onDetail,
    required this.onStart,
    required this.onReserve,
    required this.onCancel,
    required this.onFinish,
  });

  final MachineModel machine;
  final int waitingCount;
  final int remainingMinutes;
  final bool isMyReservation;
  final bool isCurrentUserUsing;
  final bool canStart;
  final VoidCallback onDetail;
  final VoidCallback onStart;
  final VoidCallback onReserve;
  final VoidCallback onCancel;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final canReserve =
        !isMyReservation &&
        machine.status != MachineStatus.available &&
        machine.status != MachineStatus.repair &&
        !isCurrentUserUsing;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.sticker,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '선택한 기구',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusBadge(status: machine.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            machine.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (machine.description != null) ...[
            const SizedBox(height: 4),
            Text(
              machine.description!,
              style: const TextStyle(color: mutedTextColor),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _Info(text: '최대 ${machine.maxUseMinutes}분'),
              _Info(text: '사용자 ${machine.currentUserName ?? '-'}'),
              _Info(text: '남은 시간 ${formatRemainingMinutes(remainingMinutes)}'),
              _Info(text: '대기 $waitingCount명'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(label: '상세보기', onPressed: onDetail),
              if (canStart) _ActionButton(label: '사용 시작', onPressed: onStart),
              if (canReserve)
                _ActionButton(label: '예약하기', onPressed: onReserve),
              if (isMyReservation && !isCurrentUserUsing)
                _ActionButton(
                  label: '예약 취소',
                  onPressed: onCancel,
                  isDanger: true,
                ),
              if (isCurrentUserUsing)
                _ActionButton(
                  label: '사용 종료',
                  onPressed: onFinish,
                  isDanger: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: textColor, fontWeight: FontWeight.w600),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: isDanger ? redColor : blueColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(label),
    );
  }
}
