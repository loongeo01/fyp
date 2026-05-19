import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/main.dart';
import 'package:recipe_app/pantry_provider.dart';
import 'package:recipe_app/premium_recipe_card.dart';
import 'package:recipe_app/all_recipes_screen.dart'; // <-- NEW: Import the new screen

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with RouteAware {
  List<Map<String, dynamic>> _favoriteRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchFavoriteRecipes());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _fetchFavoriteRecipes();
  }

  Future<void> _fetchFavoriteRecipes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists || userDoc.data() == null) {
        setState(() => _isLoading = false);
        return;
      }

      final data = userDoc.data() as Map<String, dynamic>;

      List<dynamic> savedRecipeNames = data['favorites'] ?? [];
      List<dynamic> aiFavorites = data['ai_favorites'] ?? [];

      List<Map<String, dynamic>> matchedRecipes = [];

      if (savedRecipeNames.isNotEmpty) {
        QuerySnapshot recipesSnapshot = await FirebaseFirestore.instance
            .collection('recipes')
            .get();

        for (var doc in recipesSnapshot.docs) {
          var recipeData = doc.data() as Map<String, dynamic>;
          if (savedRecipeNames.contains(recipeData['name'])) {
            matchedRecipes.add(recipeData);
          }
        }
      }

      for (var aiRecipe in aiFavorites) {
        matchedRecipes.add(Map<String, dynamic>.from(aiRecipe));
      }

      if (!mounted) return;

      Set<String> myPantry = context
          .read<PantryProvider>()
          .savedIngredients
          .map((e) => e.key.toUpperCase().trim())
          .toSet();

      List<Map<String, dynamic>> processedRecipes = [];

      for (var recipe in matchedRecipes) {
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

      setState(() {
        _favoriteRecipes = processedRecipes;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading favorites: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          "My Favorites",
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
        centerTitle: false,
        // --- NEW: ADDED ACTION BUTTON HERE ---
        actions: [
          IconButton(
            icon: const Icon(
              Icons.food_bank,
              size: 32,
              color: Color(0xFF006E1C),
            ),
            tooltip: "View All Recipes",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AllRecipesScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF006E1C)),
            )
          : _favoriteRecipes.isEmpty
          ? _buildEmptyState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Saved Collection",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006E1C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${_favoriteRecipes.length} Recipes",
                          style: const TextStyle(
                            color: Color(0xFF006E1C),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: _favoriteRecipes.length,
                    itemBuilder: (context, index) {
                      return PremiumRecipeCard(recipe: _favoriteRecipes[index]);
                    },
                  ),
                ),
              ],
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
              Icons.favorite_border,
              size: 64,
              color: Color(0xFFBECAB9),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No favorites yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tap the heart icon on any recipe\nto save it for later.",
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
