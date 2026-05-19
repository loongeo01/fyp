import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/pantry_provider.dart';
import 'package:recipe_app/premium_recipe_card.dart';
import 'package:recipe_app/searchBar.dart';

class AllRecipesScreen extends StatefulWidget {
  const AllRecipesScreen({super.key});

  @override
  State<AllRecipesScreen> createState() => _AllRecipesScreenState();
}

class _AllRecipesScreenState extends State<AllRecipesScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    // 1. Fetch raw recipes from your provider
    final List<Map<String, dynamic>> rawRecipes = context
        .watch<PantryProvider>()
        .allRecipes;

    // 2. Extract recipe names for your reusable IngredientSearchBar
    final List<String> recipeSuggestions = rawRecipes
        .map((recipe) => recipe['name'].toString())
        .toList();

    // 3. Sort recipes alphabetically safely
    List<Map<String, dynamic>> sortedRecipes = List<Map<String, dynamic>>.from(
      rawRecipes,
    );
    sortedRecipes.sort((a, b) {
      String nameA = (a['name'] ?? '').toString().toLowerCase();
      String nameB = (b['name'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    // 4. Retrieve current pantry state for PremiumCard compatibility match calculations
    Set<String> myPantry = context
        .watch<PantryProvider>()
        .savedIngredients
        .map((e) => e.key.toUpperCase().trim())
        .toSet();

    List<Map<String, dynamic>> processedRecipes = [];

    for (var recipe in sortedRecipes) {
      final String recipeName = (recipe['name'] ?? '').toString();

      // Filter dynamically based on search query submission
      if (_searchQuery.isNotEmpty &&
          !recipeName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        continue;
      }

      List<dynamic> rawIngredients = recipe['ingredients'] ?? [];
      int matchCount = 0;

      for (var item in rawIngredients) {
        if (myPantry.contains(item.toString().toUpperCase().trim())) {
          matchCount++;
        }
      }

      int totalNeeded = rawIngredients.length;
      int missingCount = totalNeeded - matchCount;

      processedRecipes.add({
        ...recipe,
        "matchCount": matchCount,
        "missingCount": missingCount,
        "totalNeeded": totalNeeded,
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          "All Recipes",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF006E1C),
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF191C1B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Dynamic search bar utilizing the updated customSuggestions configuration
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                hintText: "Search recipe names...",
                havePlusButton: false, // Turn off input entry button
                customSuggestions:
                    recipeSuggestions, // Injects names instead of ingredients
                onPlus: (_) {},
                onSearchChanged: (String typedText) {
                  setState(() {
                    _searchQuery = typedText;
                  });
                },
              ),
            ),
          ),

          // Display Area
          Expanded(
            child: processedRecipes.isEmpty
                ? Center(
                    child: Text(
                      "No matching recipes found.",
                      style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: processedRecipes.length,
                    itemBuilder: (context, index) {
                      return PremiumRecipeCard(recipe: processedRecipes[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
