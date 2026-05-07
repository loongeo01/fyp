import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/pantry_provider.dart';

class IngredientSearchBar extends StatefulWidget {
  final Function(String) onPlus;
  final Function(String) onSearchChanged;
  final String hintText;
  final bool havePlusButton;
  final String defaultText;

  const IngredientSearchBar({
    super.key,
    required this.onPlus,
    required this.onSearchChanged,
    this.defaultText = "",
    this.hintText = "Type an ingredient...",
    this.havePlusButton = true,
  });

  @override
  State<IngredientSearchBar> createState() => _IngredientSearchBarState();
}

class _IngredientSearchBarState extends State<IngredientSearchBar> {
  // REMOVED: Static _pantryDatabase list is gone!

  @override
  Widget build(BuildContext context) {
    final dynamicSuggestions = context
        .watch<PantryProvider>()
        .masterIngredients
        .map((item) => item['name'].toString())
        .toList();

    return Autocomplete<String>(
      // NEW: When a user clicks a suggestion from the dropdown
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        // Use the dynamic list passed from the parent!
        return dynamicSuggestions.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            // Only set default text if controller is empty to avoid overwriting typing
            if (widget.defaultText.isNotEmpty &&
                textEditingController.text.isEmpty) {
              textEditingController.text = widget.defaultText;
            }

            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              onSubmitted: (String value) {
                widget.onSearchChanged(value);
              },
              decoration: InputDecoration(
                hintText: widget.hintText,
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                suffixIcon: widget.havePlusButton
                    ? IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.green,
                          size: 28,
                        ),
                        onPressed: () {
                          if (textEditingController.text.trim().isNotEmpty) {
                            widget.onPlus(
                              textEditingController.text.trim().toUpperCase(),
                            );
                            textEditingController.clear();
                          }
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
              ),
            );
          },
    );
  }
}
