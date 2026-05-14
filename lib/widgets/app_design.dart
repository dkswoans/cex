import 'package:flutter/material.dart';

import '../utils/status_utils.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const sectionTitle = TextStyle(
    color: textColor,
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );

  static const itemTitle = TextStyle(
    color: textColor,
    fontSize: 17,
    fontWeight: FontWeight.w900,
  );

  static const label = TextStyle(
    color: mutedTextColor,
    fontSize: 13,
    fontWeight: FontWeight.w800,
  );

  static const value = TextStyle(
    color: textColor,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const empty = TextStyle(
    color: mutedTextColor,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTextStyles.sectionTitle),
    );
  }
}

class AppRecordCard extends StatelessWidget {
  const AppRecordCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
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
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.empty,
      ),
    );
  }
}
