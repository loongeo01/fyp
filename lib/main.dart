import 'dart:io';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipe_app/app_images.dart';
import 'package:recipe_app/ingredient_prices.dart';
import 'package:recipe_app/pantry_screen.dart';
import 'package:recipe_app/searchBar.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';

import 'package:provider/provider.dart';
import 'pantry_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'dart:convert';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'notification_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final token = dotenv.env['googleApiKey'];
  await NotificationService().init();

  if (token == null || token.isEmpty) {
    throw Exception("googleApiKey not found. Check your .env file.");
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (context) => PantryProvider(),
      child: RecipeApp(),
    ),
  );
}

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      title: 'Malaysian AI Pantry',
      debugShowCheckedModeBanner: false,
      // --- UI UPGRADE: STITCH PREMIUM THEME ---
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAF8), // Stitch Background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006E1C), // Stitch Primary Green
          primary: const Color(0xFF006E1C),
          surface: Colors.white,
          onBackground: const Color(0xFF191C1B),
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const MainNavigationScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // The 4 main screens of your app
  final List<Widget> _screens = [
    const IngredientScannerScreen(),
    const PantryScreen(),
    const FavoritesScreen(),
    IngredientPrices(ingredientName: ""),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: IndexedStack(index: _currentIndex, children: _screens),
      // --- STITCH: PREMIUM BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF142814).withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          32,
        ), // Safe bottom padding
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.center_focus_strong, "Scan"),
            _buildNavItem(1, Icons.kitchen, "Pantry"),
            _buildNavItem(2, Icons.favorite_border, "Favorites"),
            _buildNavItem(3, Icons.sell_outlined, "Prices"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF006E1C).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF006E1C) : Colors.grey.shade400,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF006E1C)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- UPGRADED COMPONENT: The AI Scanner Screen ---
class IngredientScannerScreen extends StatefulWidget {
  const IngredientScannerScreen({super.key});

  @override
  State<IngredientScannerScreen> createState() =>
      _IngredientScannerScreenState();
}

class _IngredientScannerScreenState extends State<IngredientScannerScreen>
    with SingleTickerProviderStateMixin {
  File? _image;
  List<String> _detectedIngredients = [];
  final ImagePicker _picker = ImagePicker();
  String _result = "Ready to scan";

  List<Map<String, dynamic>> _suggestedRecipes = [];
  final bool _isLoadingRecipes = false;
  bool _isAnalyzing = false;

  // Animation for the AI Scan Line
  late AnimationController _scanAnimationController;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    super.dispose();
  }

  // ... KEEP YOUR EXACT _loadModelAndLabels, _takePicture, _findRecipesForIngredient, and _runInference METHODS HERE ...
  // (Paste them directly back in to ensure your AI still works perfectly!)

  @override
  Widget build(BuildContext context) {
    final pantryProvider = context.watch<PantryProvider>();

    final List<String> officialNames = pantryProvider.masterIngredients
        .map((item) => item['name'].toString())
        .toList();

    bool hasMatch = _detectedIngredients.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      // --- STITCH: PREMIUM HEADER ---
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: const [
            Icon(Icons.eco, color: Color(0xFF006E1C), size: 28),
            SizedBox(width: 8),
            Text(
              "FreshMarket AI",
              style: TextStyle(
                color: Color(0xFF006E1C),
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'logout') {
                  await FirebaseAuth.instance.signOut();
                }
              },
              // Pushes the menu slightly down so it doesn't cover the profile icon
              offset: const Offset(0, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              elevation: 4,
              // The trigger is our Stitch-styled Profile Icon
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF006E1C).withOpacity(0.2),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF006E1C),
                  size: 20,
                ),
              ),
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      SizedBox(width: 12),
                      Text(
                        "Sign Out",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          children: [
            // Floating Search Bar
            Container(
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
                hintText: "Search manually...",
                onPlus: (selection) =>
                    context.read<PantryProvider>().addIngredient(selection),
                onSearchChanged: (selection) {
                  setState(() {
                    _detectedIngredients = [selection];
                    _image = null;
                    _findRecipesForMultipleIngredients([selection]);
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // --- STITCH: THE VIEWFINDER CARD ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF142814).withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // The Image Feed
                        _image != null
                            ? Image.file(_image!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey.shade100,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.center_focus_strong,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Tap to Scan Ingredient",
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                        // AI Overlays (Only show when analyzing)
                        if (_isAnalyzing) ...[
                          Container(
                            color: Colors.black.withOpacity(0.2),
                          ), // Subtle dim
                          _buildViewfinderBrackets(),
                          _buildScanLine(),
                        ],
                      ],
                    ),
                  ),
                ),

                // --- STITCH: FROSTED GLASS RESULT CARD ---
                if (hasMatch && !_isAnalyzing)
                  Positioned(
                    bottom: -60,
                    left: 20,
                    right: 20,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4CAF50,
                                  ).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF006E1C),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "INGREDIENT DETECTED",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF006E1C),
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF006E1C),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Text(
                                            "98% Match",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // --- UPGRADED: SCROLLABLE MULTI-INGREDIENT CHIPS ---
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight:
                                            80, // The "ceiling" - limits height to ~3 rows
                                      ),
                                      child: SingleChildScrollView(
                                        physics:
                                            const BouncingScrollPhysics(), // Premium scroll feel
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _detectedIngredients.map((
                                            ingredient,
                                          ) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF006E1C,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF006E1C,
                                                  ).withOpacity(0.2),
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 95), // Spacing for the overlapping card
            // --- SUGGESTED RECIPES LIST ---
            if (hasMatch && !_isAnalyzing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, bottom: 16),
                    child: Text(
                      "Unlock these recipes",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF191C1B),
                      ),
                    ),
                  ),
                  _isLoadingRecipes
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF006E1C),
                          ),
                        )
                      : _suggestedRecipes.isEmpty
                      ? Center(
                          child: Text(
                            "No recipes found.",
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _suggestedRecipes.length,
                          itemBuilder: (context, index) {
                            return RecipeCard(recipe: _suggestedRecipes[index]);
                          },
                        ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // --- HELPER UI METHODS FOR THE AI OVERLAYS ---
  Widget _buildViewfinderBrackets() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCorner(top: true, left: true),
              _buildCorner(top: true, left: false),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCorner(top: false, left: true),
              _buildCorner(top: false, left: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({required bool top, required bool left}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? const BorderSide(color: Color(0xFF4CAF50), width: 4)
              : BorderSide.none,
          bottom: !top
              ? const BorderSide(color: Color(0xFF4CAF50), width: 4)
              : BorderSide.none,
          left: left
              ? const BorderSide(color: Color(0xFF4CAF50), width: 4)
              : BorderSide.none,
          right: !left
              ? const BorderSide(color: Color(0xFF4CAF50), width: 4)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(12) : Radius.zero,
          topRight: top && !left ? const Radius.circular(12) : Radius.zero,
          bottomLeft: !top && left ? const Radius.circular(12) : Radius.zero,
          bottomRight: !top && !left ? const Radius.circular(12) : Radius.zero,
        ),
      ),
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _scanAnimationController,
      builder: (context, child) {
        return Positioned(
          // Moves the line up and down across the view
          top:
              MediaQuery.of(context).size.height *
              0.45 *
              _scanAnimationController.value,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF4CAF50),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.6),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _findRecipesForIngredient(String scannedIngredient) {
    // 1. Grab the global list
    final allRecipes = context.read<PantryProvider>().allRecipes;

    // 2. Filter it instantly in memory!
    final matchingRecipes = allRecipes.where((recipe) {
      if (recipe['ingredients'] == null) return false;
      List<dynamic> ingredients = recipe['ingredients'];

      // Check if this recipe contains the scanned word
      return ingredients.any(
        (item) =>
            item.toString().toUpperCase() == scannedIngredient.toUpperCase(),
      );
    }).toList();

    // 3. Update your UI (e.g., setState)
    setState(() {
      _suggestedRecipes = matchingRecipes;
      _isAnalyzing = false;
    });
  }

  Future<void> _takePicture() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() {
      _image = File(photo.path);
      _isAnalyzing = true;
      _suggestedRecipes.clear();
      _detectedIngredients
          .clear(); // <-- NEW: Clear old chips when a new photo is taken
    });

    _runInference(File(photo.path));
  }

  Future<void> _runInference(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      final model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-2.5-flash',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
        // --- UPGRADED INSTRUCTIONS FOR MULTIPLE ITEMS ---
        systemInstruction: Content.system('''
          You are an expert Malaysian food ingredient identifier.
          Look at the image and identify ALL visible raw ingredients.
          Return the raw ingredient names in UPPERCASE.
          
          You MUST respond in valid JSON using EXACTLY this schema:
          {
            "ingredients": [
              {
                "name": "CHICKEN",
                "confidence": 0.95
              },
              {
                "name": "SERAI",
                "confidence": 0.85
              }
            ]
          }
        '''),
      );

      final prompt = [
        Content.multi([
          TextPart('Identify all ingredients in this image.'),
          InlineDataPart('image/jpeg', imageBytes),
        ]),
      ];

      final response = await model.generateContent(prompt);

      if (response.text != null) {
        String rawText = response.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final Map<String, dynamic> data = jsonDecode(rawText);

        // 1. Extract the list of ingredients
        List<dynamic> detectedItems = data['ingredients'] ?? [];
        List<String> validIngredients = [];

        // 2. Loop through and filter the good ones
        for (var item in detectedItems) {
          String name = item['name'] ?? "UNKNOWN";
          double confidence = (item['confidence'] ?? 0.0).toDouble();

          if (name != "UNKNOWN" && confidence > 0.6) {
            validIngredients.add(name);
            // Instantly save to Pantry!
            if (mounted) {
              context.read<PantryProvider>().addIngredient(name);
            }
          }
        }

        setState(() {
          _isAnalyzing = false;
        });

        // 3. Update the UI and fetch recipes!
        if (validIngredients.isNotEmpty) {
          setState(() {
            // Save the actual list instead of a joined string
            _detectedIngredients = validIngredients;
          });

          // Pass the whole list to our new recipe finder
          _findRecipesForMultipleIngredients(validIngredients);
        } else {
          setState(() {
            _result = "No clear ingredients found. Try a better angle!";
          });
        }
      }
    } catch (e) {
      print("Vision AI Error: $e");
      setState(() {
        _isAnalyzing = false;
        _result = "Error analyzing image.";
      });
    }
  }

  void _findRecipesForMultipleIngredients(List<String> scannedIngredients) {
    // 1. Grab the global list
    final allRecipes = context.read<PantryProvider>().allRecipes;

    // 2. Filter it instantly in memory!
    final matchingRecipes = allRecipes.where((recipe) {
      if (recipe['ingredients'] == null) return false;
      List<dynamic> recipeIngredients = recipe['ingredients'];

      // 3. Check if the recipe contains ANY of the scanned items
      return recipeIngredients.any((item) {
        String recipeItem = item.toString().toUpperCase();
        return scannedIngredients.any(
          (scanned) => recipeItem == scanned.toUpperCase(),
        );
      });
    }).toList();

    // 4. Update your UI
    setState(() {
      _suggestedRecipes = matchingRecipes;
    });
  }
}

// --- NEW COMPONENT: A custom, beautifully styled Recipe Card ---
// --- UI UPGRADE: Premium Stitch Recipe/Store Card ---
class RecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;

  const RecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF142814,
            ).withOpacity(0.04), // Stitch Soft Shadow
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
                builder: (context) => RecipeDetailScreen(recipe: recipe),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Placeholder for premium image
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      16,
                    ), // Adjust this number for more/less rounding
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child:
                          (recipe["image_url"] != null &&
                              recipe["image_url"].toString().isNotEmpty)
                          // 1. If it's an AI recipe with a URL, load from Unsplash
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
                          // 2. Otherwise, load from local assets
                          : Image.asset(
                              AppImages.getRecipeImage(recipe["name"] ?? ""),
                              width: 90,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe["name"] ?? "Unknown Recipe",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF191C1B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe["time"] ?? "N/A",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF006E1C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              recipe["difficulty"] ?? "N/A",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF006E1C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- NEW SCREEN: The Recipe Details View ---
// --- UPGRADED SCREEN: Now Stateful to handle the Favorite button ---
// --- UPGRADED SCREEN: The Recipe Details View (Stitch Design) ---
class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isFavorite = false;
  late String _recipeName;

  String _selectedState = 'Selangor';
  final List<String> _availableStates = [
    'Selangor',
    'W.P. Kuala Lumpur',
    'Pulau Pinang',
  ];

  @override
  void initState() {
    super.initState();
    _recipeName = widget.recipe["name"] ?? "Unknown";
    _checkIfFavorite();
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedState = prefs.getString('preferred_state') ?? 'Selangor';
    });
  }

  Future<void> _updateLocation(String? newState) async {
    if (newState == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_state', newState);
    setState(() {
      _selectedState = newState;
    });
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

        // 1. Check standard favorites (List of Strings)
        List<dynamic> favorites = data['favorites'] ?? [];
        if (favorites.contains(_recipeName)) {
          setState(() => _isFavorite = true);
          return; // Stop here if found
        }

        // 2. Check AI favorites (List of Maps)
        List<dynamic> aiFavorites = data['ai_favorites'] ?? [];

        // We use .any() to check if any Map in the list has a matching name
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

    // 1. Identify if this is a temporary AI recipe
    bool isAiRecipe = widget.recipe["isAI"] == true;

    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      if (_isFavorite) {
        // --- SAVING ---
        if (isAiRecipe) {
          // For AI recipes, we save the WHOLE Map so we don't lose the data
          await userRef.set({
            'ai_favorites': FieldValue.arrayUnion([widget.recipe]),
          }, SetOptions(merge: true));
        } else {
          // For standard recipes, we stick to just saving the name/ID
          await userRef.set({
            'favorites': FieldValue.arrayUnion([_recipeName]),
          }, SetOptions(merge: true));
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Saved to Favorites! ❤️")),
          );
        }
      } else {
        // --- REMOVING ---
        if (isAiRecipe) {
          await userRef.set({
            'ai_favorites': FieldValue.arrayRemove([widget.recipe]),
          }, SetOptions(merge: true));
        } else {
          await userRef.set({
            'favorites': FieldValue.arrayRemove([_recipeName]),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
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

    Map<String, dynamic>? costData = widget.recipe['cost_by_state'];
    String displayedCost = "N/A";
    if (costData != null && costData.containsKey(_selectedState)) {
      double cost = costData[_selectedState].toDouble();
      displayedCost = "RM ${cost.toStringAsFixed(2)}";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SingleChildScrollView(
        // The bottom padding ensures the last instruction isn't cut off
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- STITCH: HERO HEADER ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                CachedNetworkImage(
                  // 1. Pass an empty string if null to safely trigger the errorWidget
                  imageUrl: widget.recipe["image_url"] ?? "",
                  fit: BoxFit.cover,

                  // 2. The Loading Spinner
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF006E1C),
                      ),
                    ),
                  ),

                  // 3. THE FALLBACK: If the URL is empty or the Unsplash link breaks,
                  // load the local asset here!
                  errorWidget: (context, url, error) => Image.asset(
                    AppImages.getRecipeImage(_recipeName),
                    width: double.infinity,
                    height: 360,
                    fit: BoxFit.cover,
                  ),
                ),
                // Frosted Back Button
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
                // Frosted Favorite Button
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
                                : Colors.white,
                          ),
                          onPressed: _toggleFavorite,
                        ),
                      ),
                    ),
                  ),
                ),
                // The overlapping rounded sheet effect
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
                        isAccent: false,
                      ),
                      const SizedBox(width: 8),
                      _buildStitchStatChip(
                        Icons.restaurant,
                        widget.recipe["difficulty"] ?? "N/A",
                        isAccent: false,
                      ),
                      const SizedBox(width: 8),
                      _buildStitchStatChip(
                        Icons.payments,
                        displayedCost,
                        isAccent: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- STITCH: REGION SELECTOR (DROPDOWN) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF006E1C),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Grocery Prices: ",
                      style: TextStyle(color: Color(0xFF6F7A6B)),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedState,
                        icon: const Icon(
                          Icons.expand_more,
                          color: Color(0xFF6F7A6B),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF191C1B),
                          fontSize: 14,
                        ),
                        onChanged: _updateLocation,
                        items: _availableStates.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
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
                  const SizedBox(height: 16),

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
                          // Dynamic Icon/Checkbox
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
                          // Ingredient Text
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
                          // Price Check Button
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
                                    backgroundColor: const Color(
                                      0xFF94F990,
                                    ), // Light green circle
                                    foregroundColor: const Color(
                                      0xFF002204,
                                    ), // Dark green text
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
  Widget _buildStitchStatChip(
    IconData icon,
    String label, {
    required bool isAccent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isAccent ? const Color(0xFFA0F399) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isAccent ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isAccent ? const Color(0xFF217128) : const Color(0xFF3F4A3C),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: isAccent ? FontWeight.bold : FontWeight.w500,
              color: isAccent
                  ? const Color(0xFF217128)
                  : const Color(0xFF3F4A3C),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// --- NEW SCREEN: My Favorites ---
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
    _fetchFavoriteRecipes();
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

      // 1. Get standard favorite names AND the full AI favorite objects
      List<dynamic> savedRecipeNames = data['favorites'] ?? [];
      List<dynamic> aiFavorites = data['ai_favorites'] ?? [];

      // 2. Fetch standard recipes from the main database
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

      // 3. ADD the AI favorites directly (they are already full maps!)
      for (var aiRecipe in aiFavorites) {
        matchedRecipes.add(Map<String, dynamic>.from(aiRecipe));
      }

      setState(() {
        _favoriteRecipes = matchedRecipes;
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Favorites"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteRecipes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.heart_broken, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No favorites yet.",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Scan some ingredients to find recipes you love!",
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 30),
              itemCount: _favoriteRecipes.length,
              itemBuilder: (context, index) {
                // Reusing your awesome custom RecipeCard here!
                return RecipeCard(recipe: _favoriteRecipes[index]);
              },
            ),
    );
  }
}
