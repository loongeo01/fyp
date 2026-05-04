import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantryProvider extends ChangeNotifier {
  Map<String, int> _savedIngredients = {};
  String _searchQuery = "";

  List<Map<String, dynamic>> _allRecipes = [];
  bool _hasFetchedRecipes = false;

  // NEW: A loading state so the UI knows we are fetching from Firebase
  bool _isLoading = true;

  // --- THE CONSTRUCTOR ---
  // When the app starts, this runs immediately to fetch their saved food!
  PantryProvider() {
    _loadPantryFromFirebase();
    _fetchAllRecipesOnce();
  }

  // 2. The Getters
  List<MapEntry<String, int>> get savedIngredients =>
      _savedIngredients.entries.toList();
  bool get isLoading => _isLoading;

  List<MapEntry<String, int>> get filteredIngredients {
    if (_searchQuery.trim().isEmpty) {
      return _savedIngredients.entries.toList();
    }
    return _savedIngredients.entries.where((entry) {
      return entry.key.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<Map<String, dynamic>> get allRecipes => _allRecipes;
  bool get hasFetchedRecipes => _hasFetchedRecipes;

  // --- NEW: FIREBASE SYNC METHODS ---

  Future<void> _fetchAllRecipesOnce() async {
    if (_hasFetchedRecipes) return; // Never download twice!

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .get();

      // Convert Firebase docs into a normal Dart List and save the IDs!
      _allRecipes = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Inject the document ID into the map for safety
        return data;
      }).toList();

      _hasFetchedRecipes = true;
      notifyListeners(); // Tell the whole app the recipes are ready!
    } catch (e) {
      print("Error fetching recipes: $e");
    }
  }

  // 1. Download from Cloud on Startup
  Future<void> _loadPantryFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Look for a document matching this user's unique ID
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        // If they have a pantry saved, grab it!
        if (data.containsKey('pantry')) {
          // Convert it back from Firebase's format to our Map<String, int>
          _savedIngredients = Map<String, int>.from(data['pantry']);
        }
      }
    } catch (e) {
      print("Firebase Download Error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  // 2. Upload to Cloud (We run this quietly in the background after any change)
  Future<void> _syncToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      // .update() completely OVERWRITES the 'pantry' field with our exact map.
      // This ensures deleted items are actually wiped from the cloud!
      await docRef.update({'pantry': _savedIngredients});
    } catch (e) {
      // If .update() crashes, it usually means this is a brand new user
      // and their document doesn't exist in the database yet.
      // If that happens, we create the document from scratch using .set()!
      await docRef.set({'pantry': _savedIngredients});
    }
  }

  // --- THE MODIFIED METHODS ---
  // Every method now calls _syncToFirebase() right after updating the local memory!

  void addIngredient(String item) {
    if (_savedIngredients.containsKey(item)) {
      _savedIngredients[item] = _savedIngredients[item]! + 1;
    } else {
      _savedIngredients[item] = 1;
    }
    notifyListeners();
    _syncToFirebase(); // <-- SYNC!
  }

  void removeIngredient(String item) {
    _savedIngredients.remove(item);
    notifyListeners();
    _syncToFirebase(); // <-- SYNC!
  }

  void updateQuantity(String item, int change) {
    if (_savedIngredients.containsKey(item)) {
      int newQuantity = _savedIngredients[item]! + change;

      if (newQuantity <= 0) {
        _savedIngredients.remove(item);
      } else {
        _savedIngredients[item] = newQuantity;
      }
      notifyListeners();
      _syncToFirebase(); // <-- SYNC!
    }
  }

  void updateSearch(String query) {
    _searchQuery = query;
    notifyListeners();
    // We do NOT sync here, because search text doesn't need to be saved to the database.
  }
}
