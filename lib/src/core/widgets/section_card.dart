import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SectionCard extends StatelessWidget {
  const SectionCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}
