import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/app_images.dart';
import 'package:recipe_app/main.dart';
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
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 80, // The "ceiling" - limits height to ~3 rows
                  ),
                  child: SingleChildScrollView(
                    physics:
                        const BouncingScrollPhysics(), // Premium scroll feel
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.userIngredients.map((ingredient) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF006E1C).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF006E1C).withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            ingredient,
                            style: const TextStyle(
                              color: Color(0xFF006E1C),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
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
                      return _buildPremiumRecipeCard(context, recipe);
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
                // --- IMAGE AREA (WITH FIREBASE FALLBACK) ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child:
                      (recipe["image_url"] != null &&
                          recipe["image_url"].toString().isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: recipe["image_url"],
                          width: 90,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 90,
                            height: 100,
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF006E1C),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            AppImages.getRecipeImage(recipe["name"] ?? ""),
                            width: 90,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          AppImages.getRecipeImage(recipe["name"] ?? ""),
                          width: 90,
                          height: 100,
                          fit: BoxFit.cover,
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
                                      : const Color(0xFFD78A1F),
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
