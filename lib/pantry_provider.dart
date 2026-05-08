import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

// --- NEW: THE PANTRY ITEM DATA CLASS ---
class PantryItem {
  int quantity;
  List<DateTime> expiryDates;

  PantryItem({required this.quantity, List<DateTime>? expiryDates})
    : expiryDates = expiryDates ?? [];

  // Convert to Firebase format
  Map<String, dynamic> toMap() {
    return {
      'quantity': quantity,
      // Save dates as Strings so Firebase can easily read them
      'expiryDates': expiryDates.map((d) => d.toIso8601String()).toList(),
    };
  }

  // Convert from Firebase format
  factory PantryItem.fromMap(Map<String, dynamic> map) {
    return PantryItem(
      quantity: map['quantity'] ?? 1,
      expiryDates:
          (map['expiryDates'] as List<dynamic>?)
              ?.map((d) => DateTime.parse(d.toString()))
              .toList() ??
          [],
    );
  }
}

class PantryProvider extends ChangeNotifier {
  // UPGRADED: Now maps to the new PantryItem class instead of an int
  Map<String, PantryItem> _savedIngredients = {};
  String _searchQuery = "";

  List<Map<String, dynamic>> _allRecipes = [];
  bool _hasFetchedRecipes = false;

  List<Map<String, dynamic>> _masterIngredients = [];
  bool _isLoading = true;

  PantryProvider() {
    _loadPantryFromFirebase();
    _fetchAllRecipesOnce();
    loadMasterIngredients();
  }

  // 2. The Upgraded Getters
  List<MapEntry<String, PantryItem>> get savedIngredients =>
      _savedIngredients.entries.toList();
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get allRecipes => _allRecipes;
  List<Map<String, dynamic>> get masterIngredients => _masterIngredients;

  List<MapEntry<String, PantryItem>> get filteredIngredients {
    if (_searchQuery.trim().isEmpty) {
      return _savedIngredients.entries.toList();
    }
    return _savedIngredients.entries.where((entry) {
      return entry.key.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  bool get hasFetchedRecipes => _hasFetchedRecipes;

  // --- FIREBASE SYNC METHODS ---

  Future<void> loadMasterIngredients() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('master_ingredients')
          .get();

      _masterIngredients = snapshot.docs.map((doc) {
        return doc.data() as Map<String, dynamic>;
      }).toList();
      notifyListeners();
    } catch (e) {
      print("❌ Error loading master ingredients: $e");
    }
  }

  Future<void> _fetchAllRecipesOnce() async {
    if (_hasFetchedRecipes) return;
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .get();
      _allRecipes = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      _hasFetchedRecipes = true;
      notifyListeners();
    } catch (e) {
      print("Error fetching recipes: $e");
    }
  }

  Future<void> _loadPantryFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        if (data.containsKey('pantry')) {
          Map<String, dynamic> rawPantry = data['pantry'];

          // --- LEGACY MIGRATION LOGIC ---
          // Safely handles old users who just have an 'int' saved
          _savedIngredients = rawPantry.map((key, value) {
            if (value is int) {
              return MapEntry(key, PantryItem(quantity: value));
            } else {
              return MapEntry(
                key,
                PantryItem.fromMap(value as Map<String, dynamic>),
              );
            }
          });
        }
      }
    } catch (e) {
      print("Firebase Download Error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _syncToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Convert our custom objects back into normal Firebase maps
    Map<String, dynamic> uploadData = _savedIngredients.map(
      (key, value) => MapEntry(key, value.toMap()),
    );

    try {
      await docRef.update({'pantry': uploadData});
    } catch (e) {
      await docRef.set({'pantry': uploadData});
    }
  }

  // --- STANDARD INGREDIENT METHODS ---

  void addIngredient(String item) {
    if (_savedIngredients.containsKey(item)) {
      _savedIngredients[item]!.quantity += 1;
    } else {
      _savedIngredients[item] = PantryItem(quantity: 1);
    }
    notifyListeners();
    _syncToFirebase();
  }

  void removeIngredient(String item) {
    _savedIngredients.remove(item);
    notifyListeners();
    _syncToFirebase();
  }

  void updateQuantity(String item, int change) {
    if (_savedIngredients.containsKey(item)) {
      _savedIngredients[item]!.quantity += change;

      if (_savedIngredients[item]!.quantity <= 0) {
        _savedIngredients.remove(item);
      }
      notifyListeners();
      _syncToFirebase();
    }
  }

  void updateSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // --- NEW: EXPIRY DATE METHODS ---

  void addExpiryDate(String item, DateTime date) {
    if (_savedIngredients.containsKey(item)) {
      _savedIngredients[item]!.expiryDates.add(date);
      _savedIngredients[item]!.expiryDates.sort((a, b) => a.compareTo(b));
      notifyListeners();
      _syncToFirebase();
      NotificationService().scheduleExpiryNotification(
        item,
        date,
      ); // <-- NOTIFICATION ADDED
    }
  }

  void removeExpiryDate(String item, DateTime dateToRemove) {
    if (_savedIngredients.containsKey(item)) {
      _savedIngredients[item]!.expiryDates.removeWhere(
        (d) =>
            d.year == dateToRemove.year &&
            d.month == dateToRemove.month &&
            d.day == dateToRemove.day,
      );
      notifyListeners();
      _syncToFirebase();
      NotificationService().cancelNotification(
        item,
        dateToRemove,
      ); // <-- NOTIFICATION CANCELLED
    }
  }

  void updateExpiryDate(String item, DateTime oldDate, DateTime newDate) {
    if (_savedIngredients.containsKey(item)) {
      removeExpiryDate(item, oldDate);
      addExpiryDate(item, newDate);
    }
  }

  // --- IMAGE LOOKUP HELPER ---
  String? getImageUrl(String ingredientName) {
    try {
      final match = _masterIngredients.firstWhere(
        (item) =>
            item['name'].toString().toUpperCase() ==
            ingredientName.toUpperCase(),
      );
      return match['image_url']?.toString();
    } catch (e) {
      return null;
    }
  }
}
