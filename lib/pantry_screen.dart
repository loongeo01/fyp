import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/ingredient_prices.dart';
import 'package:recipe_app/pantry_recipes_screen.dart';
import 'package:recipe_app/searchBar.dart';
import 'pantry_provider.dart';

class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rawIngredients = context.watch<PantryProvider>().savedIngredients;
    final displayList = context.watch<PantryProvider>().filteredIngredients;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          'My Pantry',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF006E1C),
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // --- 1. THE SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IngredientSearchBar(
                hintText: "Search or add ingredients...",
                onPlus: (String selection) {
                  context.read<PantryProvider>().addIngredient(selection);
                  context.read<PantryProvider>().updateSearch("");
                },
                onSearchChanged: (String typedText) {
                  context.read<PantryProvider>().updateSearch(typedText);
                },
              ),
            ),
          ),

          // --- 2. THE DYNAMIC CONTENT AREA ---
          Expanded(
            child: rawIngredients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Your pantry is empty!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Type an ingredient above to add it.",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : displayList.isEmpty
                ? Center(
                    child: Text(
                      "No matching ingredients found.",
                      style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    ),
                  )
                // --- STITCH: 2-COLUMN PANTRY GRID ---
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio:
                          0.75, // Adjusts height to fit image + text + buttons
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final entry = displayList[index];
                      final String itemName = entry.key;
                      final int itemQuantity = entry.value;

                      return Dismissible(
                        key: Key(itemName),
                        direction: DismissDirection.horizontal,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        onDismissed: (direction) {
                          context.read<PantryProvider>().removeIngredient(
                            itemName,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("$itemName removed from pantry"),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: _buildGridCard(context, itemName, itemQuantity),
                      );
                    },
                  ),
          ),
        ],
      ),

      // --- STITCH: NEW CIRCULAR FLOATING ACTION BUTTON ---
      floatingActionButton: rawIngredients.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF006E1C),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  20,
                ), // Slightly rounded square look
              ),
              child: const Icon(Icons.menu_book, color: Colors.white, size: 28),
              onPressed: () {
                List<String> myIngredients = rawIngredients
                    .map((e) => e.key)
                    .toList();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PantryRecipesScreen(userIngredients: myIngredients),
                  ),
                );
              },
            )
          : null,
    );
  }

  // --- HELPER: BUILD THE INDIVIDUAL SQUARE CARD ---
  Widget _buildGridCard(
    BuildContext context,
    String itemName,
    int itemQuantity,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF142814).withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    IngredientPrices(ingredientName: itemName),
              ),
            );
          },
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- TOP 50%: IMAGE AREA ---
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Icon(
                        Icons.eco,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),

                  // --- BOTTOM 50%: TEXT & BUTTONS ---
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                      child: Column(
                        children: [
                          Text(
                            itemName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF191C1B),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // --- TOP RIGHT BADGE (UPGRADED) ---
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ), // Increased padding
                  decoration: BoxDecoration(
                    color: const Color(0xFF006E1C),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    "${itemQuantity}x",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14, // Increased from 10 to 14
                      fontWeight: FontWeight.w800, // Extra bold
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // --- TACTILE STEPPER AT BOTTOM (SIMPLIFIED) ---
              Positioned(
                bottom: 8,
                left: 12,
                right: 12,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F2), // Light grey pill
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Physical Minus Button
                      _buildTactileButton(
                        icon: Icons.remove,
                        onTap: () => context
                            .read<PantryProvider>()
                            .updateQuantity(itemName, -1),
                      ),

                      // Subtle vertical divider for a premium look
                      Container(
                        width: 1,
                        height: 16,
                        color: Colors.grey.shade300,
                      ),

                      // Physical Plus Button
                      _buildTactileButton(
                        icon: Icons.add,
                        onTap: () => context
                            .read<PantryProvider>()
                            .updateQuantity(itemName, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER: PHYSICAL BUTTON STYLE ---
  Widget _buildTactileButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.all(
          1.5,
        ), // Gives it a "nested" look inside the pill
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF006E1C)),
      ),
    );
  }
}
