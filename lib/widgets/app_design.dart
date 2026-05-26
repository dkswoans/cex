import 'package:flutter/material.dart';

import '../utils/status_utils.dart';

class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

class AppRadii {
  const AppRadii._();

  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

class AppShadows {
  const AppShadows._();

  static const sticker = [
    BoxShadow(color: borderColor, offset: Offset(4, 4), blurRadius: 0),
  ];

  static const loud = [
    BoxShadow(color: blueColor, offset: Offset(5, 5), blurRadius: 0),
    BoxShadow(color: redColor, offset: Offset(-2, -2), blurRadius: 0),
  ];
}

class AppTextStyles {
  const AppTextStyles._();

  static const sectionTitle = TextStyle(
    color: textColor,
    fontSize: 18,
    fontWeight: FontWeight.w900,
    height: 1.15,
  );

  static const itemTitle = TextStyle(
    color: textColor,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    height: 1.2,
  );

  static const label = TextStyle(
    color: mutedTextColor,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.25,
  );

  static const value = TextStyle(
    color: textColor,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.3,
  );

  static const empty = TextStyle(
    color: mutedTextColor,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.35,
  );
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: AppTextStyles.sectionTitle),
    );
  }
}

class AppRecordCard extends StatelessWidget {
  const AppRecordCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.sticker,
      ),
      child: child,
    );
  }
}

class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 104,
  });

  final String label;
  final String value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: AppTextStyles.label),
          ),
          Expanded(child: Text(value, style: AppTextStyles.value)),
        ],
      ),
    );
  }
}

class AppEmptyPanel extends StatelessWidget {
  const AppEmptyPanel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.sticker,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.empty,
      ),
    );
  }
}
