import 'dart:io';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipe_app/app_images.dart';
import 'package:recipe_app/favorites_screen.dart';
import 'package:recipe_app/ingredient_prices.dart';
import 'package:recipe_app/pantry_screen.dart';
import 'package:recipe_app/premium_ingredient_wrap.dart';
import 'package:recipe_app/premium_recipe_card.dart';
import 'package:recipe_app/recipe_detail_screen.dart';
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

  List<Map<String, dynamic>> _suggestedRecipes = [];
  final bool _isLoadingRecipes = false;
  bool _isAnalyzing = false;

  // Animation for the AI Scan Line
  late AnimationController _scanAnimationController;

  bool _scanFailed = false;

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

    pantryProvider.masterIngredients
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
                                    PremiumIngredientWrap(
                                      ingredients: _detectedIngredients,
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

                // --- NEW STITCH: FROSTED GLASS ERROR CARD ---
                if (_scanFailed && !_isAnalyzing)
                  Positioned(
                    bottom: -40, // Sits slightly higher since it has no chips
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
                                    0xFFD78A1F,
                                  ).withOpacity(0.2), // Orange Tint
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.search_off,
                                  color: Color(0xFFD78A1F), // Orange Icon
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "NO MATCH FOUND",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFD78A1F),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "We couldn't detect any supported ingredients. Try adjusting the angle or lighting.",
                                      style: TextStyle(
                                        color: Color(0xFF191C1B),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        height: 1.3,
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
                            return PremiumRecipeCard(
                              recipe: _suggestedRecipes[index],
                            );
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

  Future<void> _takePicture() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() {
      _image = File(photo.path);
      _isAnalyzing = true;
      _suggestedRecipes.clear();
      _detectedIngredients
          .clear(); // <-- NEW: Clear old chips when a new photo is taken
      _scanFailed = false;
    });

    _runInference(File(photo.path));
  }

  Future<void> _runInference(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      // --- NEW: THE HARD BOUNDARY INGREDIENT LIST ---
      final List<String> allowedIngredients = [
        "BAWANG MERAH",
        "BAWANG BESAR",
        "BAWANG PUTIH",
        "HALIA",
        "SERAI",
        "LENGKUAS",
        "TOMATO",
        "LOBAK MERAH",
        "SAWI",
        "KOBIS",
        "TIMUN",
        "TERUNG",
        "CILI MERAH",
        "CILI PADI",
        "UBI KENTANG",
        "BROKOLI",
        "AYAM",
        "DAGING",
        "TELUR",
        "IKAN KEMBUNG",
        "IKAN SIAKAP",
        "UDANG",
        "SOTONG",
        "IKAN BILIS",
        "BERAS",
        "MINYAK MASAK",
        "GULA",
        "TEPUNG GANDUM",
        "SANTAN",
        "GARAM",
        "KICAP MANIS",
        "SOS TIRAM",
        "CILI KERING",
        "SERBUK KUNYIT",
        "SERBUK KARI AYAM",
      ];

      final model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-2.5-flash',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature:
              0.1, // LOW TEMPERATURE: Forces strict obedience to the list
        ),
        // --- UPGRADED: STRICT AI PROMPT ---
        systemInstruction: Content.system('''
          You are an expert Malaysian food ingredient identifier.
          Look at the image and identify visible raw ingredients.
          
          CRITICAL RULES:
          1. You MUST ONLY identify ingredients that exist in this exact allowed list:
          [${allowedIngredients.join(", ")}]
          2. Do NOT identify, invent, or translate any ingredient that is not on this list.
          3. If an item in the image is not on the list, IGNORE IT completely.
          4. If you cannot confidently identify ANY items from the allowed list in the image, return an empty array [].
          5. Return the exact raw ingredient names in UPPERCASE exactly as they appear in the list.
          
          You MUST respond in valid JSON using EXACTLY this schema:
          {
            "ingredients": [
              {
                "name": "AYAM",
                "confidence": 0.95
              }
            ]
          }
        '''),
      );

      final prompt = [
        Content.multi([
          TextPart('Identify all supported ingredients in this image.'),
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

        List<dynamic> detectedItems = data['ingredients'] ?? [];
        List<String> validIngredients = [];

        for (var item in detectedItems) {
          String name = item['name'] ?? "UNKNOWN";
          double confidence = (item['confidence'] ?? 0.0).toDouble();

          if (name != "UNKNOWN" && confidence > 0.6) {
            validIngredients.add(name);
            if (mounted) {
              context.read<PantryProvider>().addIngredient(name);
            }
          }
        }

        setState(() {
          _isAnalyzing = false;
        });

        // --- UPGRADED: FALLBACK UI ---
        if (validIngredients.isNotEmpty) {
          setState(() {
            _detectedIngredients = validIngredients;
            _scanFailed = false; // Success!
          });
          _findRecipesForMultipleIngredients(validIngredients);
        } else {
          setState(() {
            _detectedIngredients = [];
            _scanFailed = true; // <--- Trigger the error card!
          });
        }
      }
    } catch (e) {
      print("Vision AI Error: $e");
      setState(() {
        _isAnalyzing = false;
        _detectedIngredients = [];
        _scanFailed = true; // <--- Trigger the error card on crash too!
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Error analyzing image. Please check your connection.",
            ),
          ),
        );
      }
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
