import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/main.dart';
import 'pantry_provider.dart';

class PantryRecipesScreen extends StatelessWidget {
  final List<String> userIngredients;

  const PantryRecipesScreen({super.key, required this.userIngredients});

  // --- THE SYNCHRONOUS SORTING ALGORITHM (Kept exactly as you wrote it!) ---
  List<Map<String, dynamic>> _getSortedRecipes(
    List<Map<String, dynamic>> globalRecipes,
  ) {
    List<Map<String, dynamic>> scoredRecipes = [];
    Set<String> myPantry = userIngredients.map((e) => e.toUpperCase()).toSet();

    for (var recipe in globalRecipes) {
      if (recipe['ingredients'] == null) continue;

      List<dynamic> rawIngredients = recipe['ingredients'];
      List<String> recipeIngredients = rawIngredients
          .map((e) => e.toString())
          .toList();

      int matchCount = 0;
      for (String item in recipeIngredients) {
        if (myPantry.contains(item.toUpperCase())) {
          matchCount++;
        }
      }

      int missingCount = recipeIngredients.length - matchCount;

      if (matchCount > 0) {
        scoredRecipes.add({
          ...recipe,
          "matchCount": matchCount,
          "missingCount": missingCount,
          "totalNeeded": recipeIngredients.length,
        });
      }
    }

    scoredRecipes.sort((a, b) {
      int matchComparison = b["matchCount"].compareTo(a["matchCount"]);
      if (matchComparison != 0) return matchComparison;
      return a["missingCount"].compareTo(b["missingCount"]);
    });

    return scoredRecipes;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantryProvider>();
    final sortedRecipes = _getSortedRecipes(provider.allRecipes);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          "Pantry Matches",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF006E1C),
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF191C1B)),
      ),
      body: !provider.hasFetchedRecipes
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF006E1C)),
            )
          : sortedRecipes.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: sortedRecipes.length,
              itemBuilder: (context, index) {
                final recipe = sortedRecipes[index];
                return _buildPremiumRecipeCard(context, recipe);
              },
            ),
    );
  }

  // --- STITCH: BEAUTIFUL EMPTY STATE ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Color(0xFFBECAB9),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No matching recipes yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add a few more ingredients to your pantry\nto unlock delicious possibilities.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6F7A6B),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- STITCH: PREMIUM RECIPE MATCH CARD ---
  Widget _buildPremiumRecipeCard(
    BuildContext context,
    Map<String, dynamic> recipe,
  ) {
    bool isPerfectMatch = recipe["missingCount"] == 0;
    double matchPercentage = recipe["matchCount"] / recipe["totalNeeded"];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPerfectMatch
              ? const Color(0xFF006E1C).withOpacity(0.3)
              : Colors.grey.shade100,
          width: isPerfectMatch ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPerfectMatch
                ? const Color(0xFF006E1C).withOpacity(0.05)
                : const Color(0xFF142814).withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecipeDetailScreen(recipe: recipe),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- IMAGE PLACEHOLDER ---
                Container(
                  width: 90,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Color(0xFFBECAB9),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),

                // --- CONTENT AREA ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recipe Title
                      Text(
                        recipe["name"] ?? "Unknown Recipe",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1B),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Time & Difficulty
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: Color(0xFF6F7A6B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe["time"] ?? "--",
                            style: const TextStyle(
                              color: Color(0xFF6F7A6B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: CircleAvatar(
                              radius: 2,
                              backgroundColor: Color(0xFFBECAB9),
                            ),
                          ),
                          Text(
                            recipe["difficulty"] ?? "N/A",
                            style: const TextStyle(
                              color: Color(0xFF6F7A6B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- MATCH PROGRESS BAR ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isPerfectMatch
                                    ? "Ready to Cook"
                                    : "You have ${recipe["matchCount"]}/${recipe["totalNeeded"]}",
                                style: TextStyle(
                                  color: isPerfectMatch
                                      ? const Color(0xFF006E1C)
                                      : const Color(
                                          0xFFD78A1F,
                                        ), // Green or Orange
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!isPerfectMatch)
                                Text(
                                  "Missing ${recipe["missingCount"]}",
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // The Visual Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: matchPercentage,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isPerfectMatch
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFFFB866),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
