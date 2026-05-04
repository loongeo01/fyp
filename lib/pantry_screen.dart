import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/ingredient_prices.dart';
import 'package:recipe_app/pantry_recipes_screen.dart';
import 'package:recipe_app/searchBar.dart'; // Make sure this path is correct
import 'pantry_provider.dart';

class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We watch BOTH lists to handle our empty states perfectly
    final rawIngredients = context.watch<PantryProvider>().savedIngredients;
    final displayList = context.watch<PantryProvider>().filteredIngredients;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Pantry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- 1. THE SEARCH BAR (ALWAYS VISIBLE) ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: IngredientSearchBar(
              hintText: "Search/Enter for ingredients...",
              onPlus: (String selection) {
                // Add it to the physical pantry list
                context.read<PantryProvider>().addIngredient(selection);

                // Clear the search query so they instantly see their newly added item
                context.read<PantryProvider>().updateSearch("");
              },
              onSearchChanged: (String typedText) {
                // Trigger the live filtering!
                context.read<PantryProvider>().updateSearch(typedText);
              },
            ),
          ),

          // --- 2. THE DYNAMIC CONTENT AREA ---
          Expanded(
            // Scenario A: The user has absolutely nothing in their pantry yet
            child: rawIngredients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.kitchen, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "Your pantry is empty!",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Type an ingredient above to add it.",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  )
                // Scenario B: They have items, but their search didn't match anything
                : displayList.isEmpty
                ? Center(
                    child: Text(
                      "No matching ingredients found.",
                      style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    ),
                  )
                // Scenario C: Show the beautiful, filterable list!
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      // --- NEW: Extracting from the MapEntry ---
                      final entry = displayList[index];
                      final String itemName = entry.key;
                      final int itemQuantity = entry.value;

                      return Dismissible(
                        key: Key(itemName), // Use the extracted key
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          context.read<PantryProvider>().removeIngredient(
                            itemName,
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("$itemName removed from pantry"),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => IngredientPrices(
                                    ingredientName: itemName.toString(),
                                  ),
                                ),
                              );
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.eco,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              itemName, // Use the extracted name here
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // --- THE NEW QUANTITY CONTROLS ---
                            trailing: Row(
                              mainAxisSize: MainAxisSize
                                  .min, // Prevents row from taking over the whole card
                              children: [
                                // Minus Button
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    context
                                        .read<PantryProvider>()
                                        .updateQuantity(itemName, -1);
                                  },
                                ),

                                // The Number
                                SizedBox(
                                  width:
                                      24, // Keeps the number centered perfectly
                                  child: Text(
                                    itemQuantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                // Plus Button
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    context
                                        .read<PantryProvider>()
                                        .updateQuantity(itemName, 1);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // --- THE NEW "GENERATE RECIPES" BUTTON ---
          // Only show the button if the pantry is NOT empty
          if (rawIngredients.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56, // Makes the button nice and tall for thumbs!
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome, color: Colors.white),
                    label: const Text(
                      "Find Matching Recipes",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    onPressed: () {
                      // Grab just the ingredient names from the Provider
                      List<String> myIngredients = rawIngredients
                          .map((e) => e.key)
                          .toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantryRecipesScreen(
                            userIngredients: myIngredients,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
