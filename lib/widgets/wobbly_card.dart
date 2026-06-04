import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/status_utils.dart';
import 'app_design.dart';

List<BoxShadow> randomShadows(String seed) {
  final rng = math.Random(seed.hashCode);
  const colors = [greenColor, redColor, blueColor, amberColor, borderColor];
  final count = 2 + rng.nextInt(3);
  return List.generate(count, (_) {
    final color = colors[rng.nextInt(colors.length)];
    final dx = rng.nextDouble() * 14 - 2;
    final dy = rng.nextDouble() * 14 - 2;
    return BoxShadow(color: color, offset: Offset(dx, dy), blurRadius: 0);
  });
}

List<BoxShadow> chipShadows(String seed) {
  final rng = math.Random(seed.hashCode);
  const colors = [greenColor, redColor, blueColor, amberColor, borderColor];
  final count = 1 + rng.nextInt(2);
  return List.generate(count, (_) {
    final color = colors[rng.nextInt(colors.length)];
    final dx = rng.nextDouble() * 4 + 1;
    final dy = rng.nextDouble() * 4 + 1;
    return BoxShadow(color: color, offset: Offset(dx, dy), blurRadius: 0);
  });
}

Path buildWobblyPath(String seed, Size size, {double jitterScale = 1.0}) {
  final rng = math.Random(seed.hashCode);
  double j() {
    final sign = rng.nextBool() ? 1 : -1;
    return sign * (3 + rng.nextDouble() * 3) * jitterScale;
  }

  final w = size.width;
  final h = size.height;

  final tl = Offset(j(), j());
  final tr = Offset(w + j(), j());
  final br = Offset(w + j(), h + j());
  final bl = Offset(j(), h + j());

  final topMid = Offset(w / 2 + j(), j() * 2);
  final rightMid = Offset(w + j() * 2, h / 2 + j());
  final bottomMid = Offset(w / 2 + j(), h + j() * 2);
  final leftMid = Offset(j() * 2, h / 2 + j());

  return Path()
    ..moveTo(tl.dx, tl.dy)
    ..quadraticBezierTo(topMid.dx, topMid.dy, tr.dx, tr.dy)
    ..quadraticBezierTo(rightMid.dx, rightMid.dy, br.dx, br.dy)
    ..quadraticBezierTo(bottomMid.dx, bottomMid.dy, bl.dx, bl.dy)
    ..quadraticBezierTo(leftMid.dx, leftMid.dy, tl.dx, tl.dy)
    ..close();
}

class WobblyCardPainter extends CustomPainter {
  const WobblyCardPainter({
    required this.seed,
    required this.shadows,
    this.fillColor = surfaceColor,
    this.jitterScale = 1.0,
  });

  final String seed;
  final List<BoxShadow> shadows;
  final Color fillColor;
  final double jitterScale;

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildWobblyPath(seed, size, jitterScale: jitterScale);
    for (final s in shadows) {
      canvas.drawPath(path.shift(s.offset), Paint()..color = s.color);
    }
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
  }

  @override
  bool shouldRepaint(covariant WobblyCardPainter old) =>
      old.seed != seed || old.fillColor != fillColor || old.jitterScale != jitterScale;
}

class WobblyCardClipper extends CustomClipper<Path> {
  const WobblyCardClipper({required this.seed, this.jitterScale = 1.0});

  final String seed;
  final double jitterScale;

  @override
  Path getClip(Size size) => buildWobblyPath(seed, size, jitterScale: jitterScale);

  @override
  bool shouldReclip(covariant WobblyCardClipper old) =>
      old.seed != seed || old.jitterScale != jitterScale;
}

class WobblyCard extends StatelessWidget {
  const WobblyCard({
    super.key,
    required this.seed,
    required this.shadows,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final String seed;
  final List<BoxShadow> shadows;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CustomPaint(
        painter: WobblyCardPainter(seed: seed, shadows: shadows),
        child: ClipPath(
          clipper: WobblyCardClipper(seed: seed),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
