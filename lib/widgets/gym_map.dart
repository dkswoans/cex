import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../utils/status_utils.dart';
import 'app_design.dart';
import 'machine_marker.dart';

class GymMap extends StatelessWidget {
  const GymMap({
    super.key,
    required this.machines,
    required this.onMachineTap,
    required this.getWaitingCount,
    required this.getMarkerSummary,
  });

  final List<MachineModel> machines;
  final ValueChanged<MachineModel> onMachineTap;
  final int Function(String machineId) getWaitingCount;
  final String Function(String machineId) getMarkerSummary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Transform.rotate(
          angle: 0.01,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: amberColor,
              border: Border.all(color: borderColor, width: 4),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: const [
                BoxShadow(
                  color: blueColor,
                  offset: Offset(5, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _MapPainter())),
                const Positioned(
                  top: 8,
                  left: 9,
                  child: _MapLabel(
                    text: '거울임',
                    color: redColor,
                    icon: Icons.horizontal_rule,
                  ),
                ),
                const Positioned(
                  left: 10,
                  bottom: 10,
                  child: _MapLabel(
                    text: '입구ㅋ',
                    color: textColor,
                    icon: Icons.login,
                  ),
                ),
                Positioned(
                  right: width * 0.04,
                  top: height * 0.23,
                  child: _AreaBox(
                    width: width * 0.30,
                    height: height * 0.43,
                    label: '숨참존',
                    subLabel: '러닝 9대',
                  ),
                ),
                Positioned(
                  right: width * 0.05,
                  bottom: height * 0.06,
                  child: _AreaBox(
                    width: width * 0.27,
                    height: height * 0.15,
                    label: '헛바퀴',
                    subLabel: '4대',
                  ),
                ),
                ...machines.map((machine) {
                  final markerSize = _markerSize(machine);
                  final left = width * machine.mapX - markerSize.width / 2;
                  final top = height * machine.mapY - markerSize.height / 2;
                  final safeLeft = left.clamp(
                    5.0,
                    width - markerSize.width - 5.0,
                  );
                  final safeTop = top.clamp(
                    44.0,
                    height - markerSize.height - 5.0,
                  );

                  return Positioned(
                    left: safeLeft,
                    top: safeTop,
                    child: MachineMarker(
                      machine: machine,
                      isSelected: false,
                      waitingCount: getWaitingCount(machine.machineId),
                      summaryText: getMarkerSummary(machine.machineId),
                      onTap: () => onMachineTap(machine),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Size _markerSize(MachineModel machine) {
    return switch (machine.machineId) {
      'dumbbell' => const Size(78, 50),
      'barbell' => const Size(90, 46),
      'treadmill' => const Size(106, 78),
      'cycle' => const Size(94, 58),
      _ => const Size(72, 46),
    };
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final zonePaint = Paint()
      ..color = lightGrayColor.withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = redColor.withValues(alpha: 0.36)
      ..strokeWidth = 2;
    final slashPaint = Paint()
      ..color = blueColor.withValues(alpha: 0.28)
      ..strokeWidth = 4;

    for (var x = -0.2; x < 1.2; x += 0.12) {
      canvas.drawLine(
        Offset(size.width * x, 0),
        Offset(size.width * (x + 0.45), size.height),
        linePaint,
      );
    }

    for (var y = 0.08; y < 0.94; y += 0.16) {
      canvas.drawLine(
        Offset(0, size.height * y),
        Offset(size.width, size.height * (y + 0.04)),
        slashPaint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.04,
          size.height * 0.12,
          size.width * 0.39,
          size.height * 0.72,
        ),
        const Radius.circular(28),
      ),
      zonePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.38,
          size.height * 0.16,
          size.width * 0.25,
          size.height * 0.70,
        ),
        const Radius.circular(2),
      ),
      zonePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          boxShadow: const [
            BoxShadow(color: borderColor, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaBox extends StatelessWidget {
  const _AreaBox({
    required this.width,
    required this.height,
    required this.label,
    required this.subLabel,
  });

  final double width;
  final double height;
  final String label;
  final String subLabel;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: 0.035,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.62),
            border: Border.all(color: textColor, width: 2.5),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: redColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
