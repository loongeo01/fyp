import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/main.dart';
import 'pantry_provider.dart'; // Make sure this path is correct for your project!

class PantryRecipesScreen extends StatelessWidget {
  final List<String> userIngredients;

  const PantryRecipesScreen({super.key, required this.userIngredients});

  // --- THE SYNCHRONOUS SORTING ALGORITHM ---
  // Runs instantly in RAM using the data passed from the Provider
  List<Map<String, dynamic>> _getSortedRecipes(
    List<Map<String, dynamic>> globalRecipes,
  ) {
    List<Map<String, dynamic>> scoredRecipes = [];

    // Convert to uppercase for super-safe matching
    Set<String> myPantry = userIngredients.map((e) => e.toUpperCase()).toSet();

    for (var recipe in globalRecipes) {
      // Safety check: ensure the recipe actually has an ingredients list
      if (recipe['ingredients'] == null) continue;

      List<dynamic> rawIngredients = recipe['ingredients'];
      List<String> recipeIngredients = rawIngredients
          .map((e) => e.toString())
          .toList();

      // 1. Count how many ingredients match
      int matchCount = 0;
      for (String item in recipeIngredients) {
        if (myPantry.contains(item.toUpperCase())) {
          matchCount++;
        }
      }

      // 2. Calculate missing ingredients
      int missingCount = recipeIngredients.length - matchCount;

      // 3. Only keep recipes where they have at least 1 matching ingredient
      if (matchCount > 0) {
        scoredRecipes.add({
          ...recipe,
          "matchCount": matchCount,
          "missingCount": missingCount,
          "totalNeeded": recipeIngredients.length,
        });
      }
    }

    // 4. Sort the list (Most matches first, then fewest missing)
    scoredRecipes.sort((a, b) {
      int matchComparison = b["matchCount"].compareTo(a["matchCount"]);
      if (matchComparison != 0) return matchComparison;
      return a["missingCount"].compareTo(b["missingCount"]);
    });

    return scoredRecipes;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Grab the already-downloaded recipes from the provider
    final provider = context.watch<PantryProvider>();

    // 2. Run the math instantly
    final sortedRecipes = _getSortedRecipes(provider.allRecipes);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Pantry Matches",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      // 3. Draw the UI based on the Provider's state
      body: !provider.hasFetchedRecipes
          ? const Center(
              child: CircularProgressIndicator(color: Colors.green),
            ) // Shows briefly if they click this before startup finishes
          : sortedRecipes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No matching recipes found.",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Try adding more items to your pantry!",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedRecipes.length,
              itemBuilder: (context, index) {
                final recipe = sortedRecipes[index];

                // Color coding the match percentage!
                bool isPerfectMatch = recipe["missingCount"] == 0;

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RecipeDetailScreen(recipe: recipe),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      // Give perfect matches a special green border
                      side: isPerfectMatch
                          ? BorderSide(color: Colors.green.shade400, width: 2)
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                recipe["name"] ?? "Unknown Recipe",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    recipe["time"] ?? "--",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // --- MATCHING STATUS BADGE ---
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isPerfectMatch
                                  ? Colors.green[100]
                                  : Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPerfectMatch
                                  ? "✨ You have all ${recipe["totalNeeded"]} ingredients!"
                                  : "You have ${recipe["matchCount"]} / ${recipe["totalNeeded"]} ingredients",
                              style: TextStyle(
                                color: isPerfectMatch
                                    ? Colors.green[800]
                                    : Colors.orange[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // --- SHOW MISSING INGREDIENTS (If any) ---
                          if (!isPerfectMatch)
                            Text(
                              "Missing: ${recipe["missingCount"]} item(s)",
                              style: TextStyle(
                                color: Colors.red[400],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
