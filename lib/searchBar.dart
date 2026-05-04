import 'package:flutter/material.dart';

// 1. The Widget Class (Only holds final variables passed from the parent)
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

// 2. The State Class (Holds your changing variables and the UI)
class _IngredientSearchBarState extends State<IngredientSearchBar> {
  static const List<String> _pantryDatabase = [
    'BAWANG MERAH',
    'BAWANG PUTIH',
    'CILI PADI',
    'CILI MERAH',
    'AYAM',
    'DAGING',
    'TELUR',
    'KOBIS',
    'KANGKUNG',
    'IKAN BILIS',
  ];

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _pantryDatabase.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            textEditingController.text = widget.defaultText;

            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              // If they press the "Enter" or "Search" key on their phone keyboard
              onSubmitted: (String value) {
                // NEW: Shout the word up to the Parent Screen!
                widget.onSearchChanged(value);
              },
              decoration: InputDecoration(
                // --- NOTICE THE "widget." PREFIX HERE ---
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
                            // --- AND THE "widget." PREFIX HERE ---
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
