import 'package:flutter/material.dart';

/// A reusable card grid widget for displaying items in a grid layout
class CardGrid extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;
  final List<Widget> children;

  const CardGrid({
    super.key,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.2,
    this.spacing = 12.0,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}

