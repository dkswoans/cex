import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import 'app_design.dart';
import 'status_badge.dart';

class MachineCard extends StatelessWidget {
  const MachineCard({
    super.key,
    required this.machine,
    required this.waitingCount,
    required this.remainingMinutes,
    required this.onTap,
  });

  final MachineModel machine;
  final int waitingCount;
  final int remainingMinutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.sticker,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      machine.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusBadge(status: machine.status),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Info(
                    icon: Icons.timer_outlined,
                    label: '남은 시간 ${formatRemainingMinutes(remainingMinutes)}',
                  ),
                  _Info(icon: Icons.people_outline, label: '대기 $waitingCount명'),
                  _Info(
                    icon: Icons.schedule_outlined,
                    label: '최대 ${machine.maxUseMinutes}분',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: mutedTextColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: mutedTextColor, fontSize: 13),
        ),
      ],
    );
  }
}
