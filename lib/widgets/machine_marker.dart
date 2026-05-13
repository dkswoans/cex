import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../utils/status_utils.dart';

class MachineMarker extends StatelessWidget {
  const MachineMarker({
    super.key,
    required this.machine,
    required this.isSelected,
    required this.waitingCount,
    required this.onTap,
  });

  final MachineModel machine;
  final bool isSelected;
  final int waitingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = machineStatusColor(machine.status);
    final size = _size;
    final markerDescription = _markerDescription;

    return Transform.rotate(
      angle: _tilt,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: size.width,
            height: size.height,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor == greenColor ? bgColor : surfaceColor,
              border: Border.all(color: borderColor, width: 3.5),
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: [
                BoxShadow(
                  color: statusColor,
                  blurRadius: 0,
                  offset: const Offset(5, 5),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        machine.shortName,
                        maxLines: 1,
                        style: const TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  _MarkerSubText(
                    text: markerDescription ?? '대기$waitingCount',
                    color: redColor,
                  ),
                  if (markerDescription != null && waitingCount > 0)
                    _MarkerSubText(text: '대기$waitingCount', color: textColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Size get _size {
    return switch (machine.machineId) {
      'dumbbell' => const Size(78, 50),
      'barbell' => const Size(90, 46),
      'treadmill' => const Size(106, 78),
      'cycle' => const Size(94, 58),
      _ => const Size(72, 46),
    };
  }

  double get _radius {
    return switch (machine.machineId.length % 4) {
      0 => 3,
      1 => 28,
      2 => 12,
      _ => 999,
    };
  }

  double get _tilt {
    return switch (machine.machineId.length % 5) {
      0 => -0.12,
      1 => 0.09,
      2 => -0.05,
      3 => 0.15,
      _ => 0.02,
    };
  }

  String? get _markerDescription {
    return switch (machine.machineId) {
      'dumbbell' => '3~20kg',
      'barbell' => '5~30kg',
      'treadmill' => '9대',
      'cycle' => '4대',
      _ => null,
    };
  }
}

class _MarkerSubText extends StatelessWidget {
  const _MarkerSubText({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.3,
      ),
    );
  }
}
