import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/app_images.dart';
import 'package:recipe_app/ingredient_prices.dart';
import 'package:recipe_app/pantry_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isFavorite = false;
  late String _recipeName;

  @override
  void initState() {
    super.initState();
    _recipeName = widget.recipe["name"] ?? "Unknown";
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        // 1. Check standard favorites list
        List<dynamic> favorites = data['favorites'] ?? [];
        if (favorites.contains(_recipeName)) {
          setState(() => _isFavorite = true);
          return;
        }

        // 2. Legacy check: Just in case they favorited an AI recipe
        // before we made this update, keep checking the old list so it doesn't break!
        List<dynamic> aiFavorites = data['ai_favorites'] ?? [];
        bool isSavedInAi = aiFavorites.any(
          (recipeMap) => recipeMap['name'] == _recipeName,
        );

        if (isSavedInAi) {
          setState(() => _isFavorite = true);
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to save favorites.")),
      );
      return;
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    bool isAiRecipe = widget.recipe["isAI"] == true;

    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      if (_isFavorite) {
        // --- SAVING ---
        if (isAiRecipe) {
          // 1. Check if this AI recipe has already been added to the global database
          final recipesRef = FirebaseFirestore.instance.collection('recipes');
          final query = await recipesRef
              .where('name', isEqualTo: _recipeName)
              .get();

          if (query.docs.isEmpty) {
            // 2. Clean the data to match your Firebase schema exactly (no local flags)
            Map<String, dynamic> globalRecipeData = {
              "name": _recipeName,
              "time": widget.recipe["time"] ?? "N/A",
              "difficulty": widget.recipe["difficulty"] ?? "N/A",
              "image_url": widget.recipe["image_url"] ?? "",
              "ingredients": widget.recipe["ingredients"] ?? [],
              "instructions": widget.recipe["instructions"] ?? [],
            };

            // 3. Save it to the global 'recipes' collection
            await recipesRef.add(globalRecipeData);

            if (mounted) {
              context.read<PantryProvider>().refreshRecipes();
            }
          }
        }

        // 4. Save the name to the user's standard favorites list (Works for BOTH now!)
        await userRef.set({
          'favorites': FieldValue.arrayUnion([_recipeName]),
        }, SetOptions(merge: true));
      } else {
        // --- REMOVING ---
        // Just remove the name from their personal favorites list.
        // We DO NOT delete it from the global 'recipes' collection because
        // other users might have it favorited!
        await userRef.set({
          'favorites': FieldValue.arrayRemove([_recipeName]),
        }, SetOptions(merge: true));

        // Legacy cleanup (removes it from the old array if it was there)
        if (isAiRecipe) {
          await userRef.set({
            'ai_favorites': FieldValue.arrayRemove([widget.recipe]),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      // Revert the UI if the network request fails
      setState(() {
        _isFavorite = !_isFavorite;
      });
      print("Favorite Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final myPantry = context.watch<PantryProvider>().savedIngredients;
    List<dynamic> ingredients = widget.recipe['ingredients'] ?? [];
    List<dynamic> instructions = widget.recipe['instructions'] ?? [];

    // --- CALCULATE MISSING INGREDIENTS ---
    List<String> missingIngredients = [];
    for (var ingredient in ingredients) {
      String currentItem = ingredient.toString().toUpperCase().trim();
      bool iHaveThis = myPantry.any((e) => e.key == currentItem);
      if (!iHaveThis) {
        missingIngredients.add(currentItem);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- STITCH: HERO HEADER ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                CachedNetworkImage(
                  imageUrl: widget.recipe["image_url"] ?? "",
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF006E1C),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    AppImages.getRecipeImage(_recipeName),
                    width: double.infinity,
                    height: 360,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorite
                                ? Colors.redAccent
                                : const Color.fromARGB(255, 35, 34, 34),
                          ),
                          onPressed: _toggleFavorite,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAF8),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // --- STITCH: RECIPE TITLE & STATS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recipeName,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: Color(0xFF191C1B),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStitchStatChip(
                        Icons.schedule,
                        widget.recipe["time"] ?? "N/A",
                      ),
                      const SizedBox(width: 8),
                      _buildStitchStatChip(
                        Icons.restaurant,
                        widget.recipe["difficulty"] ?? "N/A",
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- STITCH: SMART INGREDIENTS LIST ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Ingredients",
                        style: TextStyle(
                          fontSize: 24,
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
                          "${ingredients.length} Items",
                          style: const TextStyle(
                            color: Color(0xFF006E1C),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- NEW: SHOP MISSING ITEMS BUTTON ---
                  if (missingIngredients.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Badge(
                        label: Text(
                          missingIngredients.length.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        backgroundColor: Colors.redAccent,
                        offset: const Offset(4, -4),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IngredientPrices(
                                  initialBasket: missingIngredients,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(173, 16, 122, 39),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.shopping_cart_checkout,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  ...ingredients.map((ingredient) {
                    String currentItem = ingredient
                        .toString()
                        .toUpperCase()
                        .trim();
                    bool iHaveThis = myPantry.any((e) => e.key == currentItem);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: iHaveThis
                            ? const Color(0xFFF2F4F2)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: iHaveThis
                              ? Colors.transparent
                              : Colors.grey.shade200,
                        ),
                        boxShadow: iHaveThis
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          iHaveThis
                              ? const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(0xFF006E1C),
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                )
                              : Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                      width: 2,
                                    ),
                                  ),
                                ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ingredient.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: iHaveThis
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                    color: iHaveThis
                                        ? const Color(0xFF6F7A6B)
                                        : const Color(0xFF191C1B),
                                  ),
                                ),
                                if (iHaveThis)
                                  const Text(
                                    "In Pantry",
                                    style: TextStyle(
                                      color: Color(0xFF006E1C),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Optional: Keep individual search button for missing items just in case
                          if (!iHaveThis)
                            IconButton(
                              icon: const Icon(
                                Icons.search,
                                color: Color(0xFF006E1C),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => IngredientPrices(
                                      ingredientName: ingredient.toString(),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- STITCH: COOKING INSTRUCTIONS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Cooking Steps",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF191C1B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  instructions.isEmpty
                      ? const Text(
                          "Instructions coming soon!",
                          style: TextStyle(color: Colors.grey),
                        )
                      : Column(
                          children: instructions.asMap().entries.map((entry) {
                            int stepNumber = entry.key + 1;
                            String stepText = entry.value.toString();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF94F990),
                                    foregroundColor: const Color(0xFF002204),
                                    child: Text(
                                      stepNumber.toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        stepText,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          height: 1.5,
                                          color: Color(0xFF3F4A3C),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER: STITCH STAT CHIP ---
  Widget _buildStitchStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3F4A3C)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF3F4A3C),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
