import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipe_app/ingredient_prices.dart';
import 'package:recipe_app/pantry_screen.dart';
import 'package:recipe_app/searchBar.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';

import 'package:provider/provider.dart';
import 'pantry_provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:flutter_dotenv/flutter_dotenv.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final token = dotenv.env['MAPBOX_TOKEN'];

  if (token == null || token.isEmpty) {
    throw Exception("MAPBOX_TOKEN not found. Check your .env file.");
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  mapbox.MapboxOptions.setAccessToken(token!);
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
      debugShowCheckedModeBanner: false, // Removes the ugly 'DEBUG' banner
      // --- UI UPGRADE: Modern Theme ---
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE65100), // A warm, appetizing orange/red
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto', // Clean, modern font
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If Firebase says we have a logged-in user, show the Scanner
          if (snapshot.hasData) {
            return const IngredientScannerScreen();
          }
          // Otherwise, show the Login Screen
          return const AuthScreen();
        },
      ),
    );
  }
}

class IngredientScannerScreen extends StatefulWidget {
  const IngredientScannerScreen({super.key});

  @override
  State<IngredientScannerScreen> createState() =>
      _IngredientScannerScreenState();
}

class _IngredientScannerScreenState extends State<IngredientScannerScreen> {
  File? _image;
  String _result = "Ready to scan your pantry";
  Interpreter? _interpreter;
  List<String>? _labels;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _suggestedRecipes = [];
  final bool _isLoadingRecipes = false;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadModelAndLabels();
  }

  Future<void> _loadModelAndLabels() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/malaysian_ingredients.tflite',
      );
      String labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData
          .split('\n')
          .where((label) => label.isNotEmpty)
          .toList();
    } catch (e) {
      setState(() => _result = "Error loading AI model.");
    }
  }

  Future<void> _takePicture() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() {
      _image = File(photo.path);
      _result = "Analyzing ingredient...";
      _isAnalyzing = true;
      _suggestedRecipes.clear();
    });

    _runInference(File(photo.path));
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

  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null || _labels == null) return;

    img.Image? rawImage = img.decodeImage(imageFile.readAsBytesSync());
    if (rawImage == null) return;
    img.Image resizedImage = img.copyResize(rawImage, width: 224, height: 224);

    var input = List.generate(
      1,
      (i) => List.generate(
        224,
        (y) => List.generate(224, (x) => List.generate(3, (c) => 0.0)),
      ),
    );

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }

    var output = List.filled(1 * 3, 0.0).reshape([1, 3]);
    _interpreter!.run(input, output);

    List<double> probabilities = (output[0] as List).cast<double>();
    double maxProb = 0;
    int maxIndex = -1;

    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }

    setState(() {
      _isAnalyzing = false;
    });

    if (maxProb > 0.6) {
      String ingredientName = _labels![maxIndex]
          .replaceAll('_', ' ')
          .toUpperCase()
          .trim();

      setState(() {
        _result = "Found: $ingredientName";
      });

      if (mounted) {
        context.read<PantryProvider>().addIngredient(ingredientName);
      }
      // ----------------------------

      _findRecipesForIngredient(ingredientName);
    } else {
      setState(() {
        _result = "Not sure! Try a clearer angle.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'AI Pantry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.kitchen, color: Colors.green),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PantryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.redAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoritesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.attach_money_outlined,
              color: Colors.greenAccent,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IngredientPrices(ingredientName: ""),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      // --- FIX 1: Wrap everything in a SingleChildScrollView ---
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: IngredientSearchBar(
                // Your list of strings
                hintText:
                    "Search for ingredients...", // Optional: you can customize this!
                onPlus: (String selection) {
                  setState(() {
                    context.read<PantryProvider>().addIngredient(selection);
                  });
                },
                onSearchChanged: (String selection) {
                  _result = "Found: $selection";
                  _image = null;

                  _findRecipesForIngredient(selection);
                },
              ),
            ),

            // Viewfinder Area
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _image != null
                    ? Image.file(_image!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.document_scanner_outlined,
                            size: 60,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Tap 'Scan' to start",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            if (_isAnalyzing)
              const CircularProgressIndicator()
            else
              Text(
                _result,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _result.contains("Found")
                      ? Colors.green[700]
                      : Colors.black87,
                ),
              ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _takePicture,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text(
                'Scan Ingredient',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
            ),

            const SizedBox(height: 24),

            if ((_image != null && !_isAnalyzing) | _result.contains("Found"))
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Text(
                        "Suggested Recipes",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    _isLoadingRecipes
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _suggestedRecipes.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                _image == null
                                    ? "Waiting for ingredients..."
                                    : "No recipes found.",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 0, bottom: 20),
                            itemCount: _suggestedRecipes.length,
                            // --- FIX 3: These two lines are critical for nesting Lists! ---
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return RecipeCard(
                                recipe: _suggestedRecipes[index],
                              );
                            },
                          ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- NEW COMPONENT: A custom, beautifully styled Recipe Card ---
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
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // --- UI UPGRADE: Navigate to the Detail Screen ---
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
                // A placeholder for a future recipe image
                Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Beautiful little status "chips" for Time and Difficulty
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe["time"] ?? "N/A",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.local_fire_department_outlined,
                            size: 14,
                            color: Colors.orange[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe["difficulty"] ?? "N/A",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
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
class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isFavorite = false;

  // We will use the recipe's name as its unique ID for saving
  late String _recipeName;

  String _selectedState = 'Selangor'; // Default state
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
    _loadSavedLocation(); // Check memory for their preferred state
  }

  // Load their last selected state so they don't have to change it every time
  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedState = prefs.getString('preferred_state') ?? 'Selangor';
    });
  }

  // Save their choice to the phone's memory
  Future<void> _updateLocation(String? newState) async {
    if (newState == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_state', newState);
    setState(() {
      _selectedState = newState;
    });
  }

  // Look inside the user's specific Cloud document to see if they saved this
  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Safety check

    try {
      // 1. Ask Firebase for this specific user's document
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // 2. Check if the document exists and contains the recipe
      if (userDoc.exists) {
        // We use 'try-catch' here just in case the 'favorites' array hasn't been created yet
        try {
          List<dynamic> favorites = userDoc.get('favorites') ?? [];
          if (favorites.contains(_recipeName)) {
            setState(() {
              _isFavorite = true;
            });
          }
        } catch (e) {
          // Field doesn't exist yet, which is fine!
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  // The logic to add or remove it from the Cloud
  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to save favorites.")),
      );
      return;
    }

    // 1. Point directly to the user's specific document
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    // Optimistically update the UI so the heart turns red instantly without waiting for the internet
    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      if (_isFavorite) {
        // ADD TO CLOUD
        // We use SetOptions(merge: true). This is a pro-trick: if the user document
        // doesn't exist yet (because they just created an account), this automatically creates it!
        await userRef.set({
          'favorites': FieldValue.arrayUnion([_recipeName]),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Saved to Cloud Favorites! ☁️❤️")),
          );
        }
      } else {
        // REMOVE FROM CLOUD
        await userRef.set({
          'favorites': FieldValue.arrayRemove([_recipeName]),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Removed from Favorites")),
          );
        }
      }
    } catch (e) {
      // If the internet drops and it fails to save, revert the heart icon back
      setState(() {
        _isFavorite = !_isFavorite;
      });
      print("Failed to update cloud: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final myPantry = context.watch<PantryProvider>().savedIngredients;

    // 1. Extract the data safely from the Firebase document
    List<dynamic> ingredients = widget.recipe['ingredients'] ?? [];
    List<dynamic> instructions = widget.recipe['instructions'] ?? [];

    // --- NEW: Extract the Pricing Data ---
    Map<String, dynamic>? costData = widget.recipe['cost_by_state'];
    String displayedCost = "N/A";

    if (costData != null && costData.containsKey(_selectedState)) {
      double cost = costData[_selectedState].toDouble();
      displayedCost = "RM ${cost.toStringAsFixed(2)}";
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Recipe Details"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.grey[800],
              size: 28,
            ),
            onPressed: _toggleFavorite,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PREMIUM HEADER AREA ---
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _recipeName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- INFO CHIPS (Time, Difficulty, and NEW Price) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip(
                  context,
                  Icons.timer,
                  widget.recipe["time"] ?? "N/A",
                ),
                const SizedBox(width: 16),
                _buildInfoChip(
                  context,
                  Icons.local_fire_department,
                  widget.recipe["difficulty"] ?? "N/A",
                ),
                const SizedBox(width: 16),
                _buildInfoChip(
                  context,
                  Icons.shopping_cart_outlined,
                  displayedCost,
                ), // <-- The New Price Chip
              ],
            ),

            const SizedBox(height: 24),

            // --- NEW: THE LOCATION DROPDOWN ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedState,
                          icon: const Icon(Icons.arrow_drop_down),
                          isExpanded: true,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: _updateLocation,
                          items: _availableStates.map<DropdownMenuItem<String>>(
                            (String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text("Grocery Prices: $value"),
                              );
                            },
                          ).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- INGREDIENTS LIST ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Required Ingredients",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  ...ingredients.map((ingredient) {
                    // --- THE CROSS-REFERENCE MATH ---
                    // Convert the recipe item to uppercase to match how the AI scanner saves it
                    String currentItem = ingredient
                        .toString()
                        .toUpperCase()
                        .trim();
                    bool iHaveThis = myPantry.any((e) => e.key == currentItem);

                    return Row(
                      children: [
                        Icon(
                          // --- DYNAMIC ICON ---
                          iHaveThis
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: iHaveThis
                              ? Colors.green[600]
                              : Colors.grey[400],
                          size: 22,
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IngredientPrices(
                                  ingredientName: ingredient.toString(),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            ingredient.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: iHaveThis
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                              // --- DYNAMIC TEXT STYLE ---
                              // Fade the text and cross it out if we already own it!
                              color: iHaveThis ? Colors.grey : Colors.black87,
                              decoration: iHaveThis
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),

                  const SizedBox(height: 16),

                  // --- COOKING INSTRUCTIONS LIST ---
                  const Text(
                    "Cooking Instructions",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  instructions.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "Instructions coming soon!",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : Column(
                          children: instructions.asMap().entries.map((entry) {
                            int stepNumber = entry.key + 1;
                            String stepText = entry.value.toString();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    child: Text(
                                      stepNumber.toString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      stepText,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
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
      // 1. Get the list of saved recipe names from the user's document
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      List<dynamic> savedRecipeNames = [];
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        savedRecipeNames = data['favorites'] ?? [];
      }

      // If they haven't saved anything yet, stop loading and show the empty state
      if (savedRecipeNames.isEmpty) {
        setState(() {
          _favoriteRecipes = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Fetch ALL recipes from the main database
      // (Since your FYP database is small, this is the safest and fastest way to filter)
      QuerySnapshot recipesSnapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .get();

      List<Map<String, dynamic>> matchedRecipes = [];

      for (var doc in recipesSnapshot.docs) {
        var recipeData = doc.data() as Map<String, dynamic>;
        // 3. If the recipe's name is in the user's saved list, add it to our UI list!
        if (savedRecipeNames.contains(recipeData['name'])) {
          matchedRecipes.add(recipeData);
        }
      }

      setState(() {
        _favoriteRecipes = matchedRecipes;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading favorites: $e");
      setState(() {
        _isLoading = false;
      });
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
