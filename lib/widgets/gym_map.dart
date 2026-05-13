import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../utils/status_utils.dart';
import 'machine_marker.dart';

class GymMap extends StatelessWidget {
  const GymMap({
    super.key,
    required this.machines,
    required this.onMachineTap,
    required this.getWaitingCount,
  });

  final List<MachineModel> machines;
  final ValueChanged<MachineModel> onMachineTap;
  final int Function(String machineId) getWaitingCount;

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
              color: const Color(0xFFFF7A00),
              border: Border.all(color: borderColor, width: 6),
              borderRadius: BorderRadius.circular(31),
              boxShadow: const [
                BoxShadow(
                  color: blueColor,
                  offset: Offset(8, 8),
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
                      onTap: () => onMachineTap(machine),
                    ),
                  );
                }),
                const Positioned(top: 9, right: 9, child: _Legend()),
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
      ..color = lightGrayColor
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = redColor
      ..strokeWidth = 3;
    final slashPaint = Paint()
      ..color = blueColor
      ..strokeWidth = 5;

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
          border: Border.all(color: color, width: 4),
          borderRadius: BorderRadius.circular(2),
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
                letterSpacing: 2,
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
            color: Colors.white.withValues(alpha: 0.46),
            border: Border.all(color: textColor, width: 3),
            borderRadius: BorderRadius.circular(30),
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
                  letterSpacing: 2,
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 4),
        borderRadius: BorderRadius.circular(19),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: greenColor, label: '쌉'),
          _LegendDot(color: redColor, label: '씀'),
          _LegendDot(color: amberColor, label: '찜'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: bgColor,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
