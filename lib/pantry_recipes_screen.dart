import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/premium_ingredient_wrap.dart';
import 'package:recipe_app/premium_recipe_card.dart';
import 'pantry_provider.dart';
import 'ai_recipe_service.dart';

class PantryRecipesScreen extends StatefulWidget {
  final List<String> userIngredients;

  const PantryRecipesScreen({super.key, required this.userIngredients});

  @override
  State<PantryRecipesScreen> createState() => _PantryRecipesScreenState();
}

class _PantryRecipesScreenState extends State<PantryRecipesScreen> {
  List<Map<String, dynamic>> aiGeneratedRecipes = [];
  bool isThinking = false;

  // --- THE SYNCHRONOUS SORTING ALGORITHM ---
  List<Map<String, dynamic>> _getSortedRecipes(
    List<Map<String, dynamic>> globalRecipes,
  ) {
    List<Map<String, dynamic>> scoredRecipes = [];
    Set<String> myPantry = widget.userIngredients
        .map((e) => e.toUpperCase())
        .toSet();

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

    // 1. Get and sort the Firebase/Hardcoded recipes
    final sortedDatabaseRecipes = _getSortedRecipes(provider.allRecipes);

    // 2. MERGE the lists (Firebase first, AI recipes at the bottom)
    final allDisplayedRecipes = [
      ...sortedDatabaseRecipes,
      ...aiGeneratedRecipes,
    ];

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

      // --- UPGRADED: BODY WITH INGREDIENTS HEADER ---
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. The "Cooking With" Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Cooking with:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1B),
                  ),
                ),
                const SizedBox(height: 8),

                // --- YOUR NEW WRAP LAYOUT ---
                PremiumIngredientWrap(ingredients: widget.userIngredients),
                // -----------------------------
              ],
            ),
          ),

          // 2. The Recipes List (or Empty/Loading State)
          Expanded(
            child: !provider.hasFetchedRecipes
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF006E1C)),
                  )
                : allDisplayedRecipes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: allDisplayedRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = allDisplayedRecipes[index];
                      return PremiumRecipeCard(recipe: recipe);
                    },
                  ),
          ),
        ],
      ),
      // --- THE AI CHEF BUTTON (RESTORED!) ---
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD78A1F),
        elevation: 4,
        icon: isThinking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          isThinking ? "Chef is cooking..." : "Generate More",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: isThinking
            ? null
            : () async {
                setState(() => isThinking = true);

                // 1. Call the AI Service using exactly the selected ingredients!
                final newRecipes = await AIRecipeService.generateRecipes(
                  availableIngredients: widget.userIngredients,
                  previousRecipes: aiGeneratedRecipes
                      .map((r) => r["name"].toString())
                      .toList(),
                );

                if (newRecipes != null) {
                  Set<String> myPantry = widget.userIngredients
                      .map((e) => e.toUpperCase())
                      .toSet();

                  List<Map<String, dynamic>>
                  formattedAiRecipes = newRecipes.map((recipe) {
                    List<dynamic> aiIngredients = recipe["ingredients"] ?? [];

                    int matchCount = 0;
                    for (var item in aiIngredients) {
                      if (myPantry.contains(item.toString().toUpperCase())) {
                        matchCount++;
                      }
                    }

                    int totalNeeded = aiIngredients.length;
                    int missingCount = totalNeeded - matchCount;

                    return {
                      ...recipe as Map<String, dynamic>,
                      "id":
                          "AI_${recipe["name"]}_${DateTime.now().millisecondsSinceEpoch}",
                      "matchCount": matchCount,
                      "missingCount": missingCount,
                      "totalNeeded": totalNeeded,
                      "isAI": true,
                    };
                  }).toList();

                  setState(() {
                    aiGeneratedRecipes.addAll(formattedAiRecipes);
                  });
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "The AI Chef is taking a break. Try again later!",
                        ),
                      ),
                    );
                  }
                }

                setState(() => isThinking = false);
              },
      ),
    );
  }

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
}
