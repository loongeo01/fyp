import 'package:flutter/material.dart';

class PremiumIngredientWrap extends StatelessWidget {
  final List<String> ingredients;
  final double maxHeight;

  // Making this optional. If provided, the chip gets an 'x' button.
  // If left null, it's just a normal display chip.
  final void Function(String)? onDeleted;

  const PremiumIngredientWrap({
    super.key,
    required this.ingredients,
    this.maxHeight = 80.0,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ingredients.map((item) {
            bool hasDelete = onDeleted != null;

            return Container(
              // Adjust padding dynamically based on whether the icon is there
              padding: EdgeInsets.only(
                left: 12,
                right: hasDelete ? 4 : 12,
                top: hasDelete ? 4 : 6,
                bottom: hasDelete ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF006E1C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF006E1C).withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFF006E1C),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),

                  // If they passed in a delete function, render the 'x' icon
                  if (hasDelete) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => onDeleted!(item),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.cancel,
                          size: 16,
                          color: Color(0xFF006E1C),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
