import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../utils/status_utils.dart';
import 'app_design.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final MachineStatus status;

  @override
  Widget build(BuildContext context) {
    final color = machineStatusColor(status);

    return Transform.rotate(
      angle: status.index.isEven ? -0.045 : 0.055,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Color.lerp(color, bgColor, 0.18),
          border: Border.all(color: borderColor, width: 2.5),
          borderRadius: BorderRadius.circular(
            status.index == 1 ? AppRadii.sm : AppRadii.pill,
          ),
          boxShadow: AppShadows.sticker,
        ),
        child: Text(
          machineStatusText(status),
          style: const TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

String statusText(MachineStatus status) => machineStatusText(status);
