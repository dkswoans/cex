import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../utils/status_utils.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final MachineStatus status;

  @override
  Widget build(BuildContext context) {
    final color = machineStatusColor(status);

    return Transform.rotate(
      angle: status.index.isEven ? -0.09 : 0.11,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Color.lerp(color, bgColor, 0.25),
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(status.index == 1 ? 3 : 999),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: Text(
          machineStatusText(status),
          style: const TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

String statusText(MachineStatus status) => machineStatusText(status);
