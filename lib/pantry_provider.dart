import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class PantryItem {
  int quantity;
  List<DateTime> expiryDates;

  PantryItem({required this.quantity, List<DateTime>? expiryDates})
    : expiryDates = expiryDates ?? [];

  Map<String, dynamic> toMap() {
    return {
      'quantity': quantity,
      'expiryDates': expiryDates.map((d) => d.toIso8601String()).toList(),
    };
  }

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
  Map<String, PantryItem> _savedIngredients = {};
  String _searchQuery = "";

  List<Map<String, dynamic>> _allRecipes = [];
  bool _hasFetchedRecipes = false;

  List<Map<String, dynamic>> _masterIngredients = [];
  bool _isLoading = true;

  // --- NEW: TARGET PRICE STATE ---
  Map<String, double> _targetPrices = {};
  final Set<String> _alertedThisSession = {};

  PantryProvider() {
    _loadPantryFromFirebase();
    _fetchAllRecipesOnce();
    loadMasterIngredients();
  }

  List<MapEntry<String, PantryItem>> get savedIngredients =>
      _savedIngredients.entries.toList();
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get allRecipes => _allRecipes;
  List<Map<String, dynamic>> get masterIngredients => _masterIngredients;
  Map<String, double> get targetPrices => _targetPrices; // Expose for UI

  List<MapEntry<String, PantryItem>> get filteredIngredients {
    if (_searchQuery.trim().isEmpty) return _savedIngredients.entries.toList();
    return _savedIngredients.entries
        .where(
          (entry) =>
              entry.key.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  bool get hasFetchedRecipes => _hasFetchedRecipes;

  Future<void> loadMasterIngredients() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('master_ingredients')
          .get();
      _masterIngredients = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
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

  Future<void> refreshRecipes() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .get();
      _allRecipes = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      notifyListeners();
    } catch (e) {
      print("Error refreshing recipes: $e");
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

        // --- NEW: LOAD TARGET PRICES ---
        if (data.containsKey('target_prices')) {
          _targetPrices = Map<String, double>.from(
            (data['target_prices'] as Map).map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            ),
          );
        }
      }
    } catch (e) {
      print("Firebase Download Error: $e");
    }

    _isLoading = false;
    notifyListeners();

    // Trigger the silent check!
    _checkPriceDrops();
  }

  // --- NEW: THE APP-LAUNCH SILENT CHECKER ---
  Future<void> _checkPriceDrops() async {
    if (_targetPrices.isEmpty) return;

    Map<String, String> dosmTranslator = {
      "BAWANG MERAH": "BAWANG KECIL MERAH BIASA IMPORT (INDIA)",
      "BAWANG BESAR": "BAWANG BESAR KUNING/HOLLAND",
      "BAWANG PUTIH": "BAWANG PUTIH IMPORT (CHINA)",
      "HALIA": "HALIA BASAH (TUA)",
      "SERAI": "SERAI",
      "LENGKUAS": "LENGKUAS",
      "TOMATO": "TOMATO",
      "LOBAK MERAH": "LOBAK MERAH",
      "SAWI": "SAWI HIJAU",
      "KOBIS": "KUBIS BULAT (TEMPATAN)",
      "TIMUN": "TIMUN",
      "TERUNG": "TERUNG PANJANG",
      "CILI MERAH": "CILI MERAH - KULAI",
      "CILI PADI": "CILI API/PADI HIJAU",
      "UBI KENTANG": "UBI KENTANG RUSSET",
      "BROKOLI": "BROKOLI",
      "AYAM": "AYAM BERSIH - STANDARD",
      "DAGING": "DAGING LEMBU IMPORT (BLOCK)",
      "TELUR": "TELUR AYAM GRED A",
      "IKAN KEMBUNG": "IKAN KEMBUNG (ANTARA 8 HINGGA 12 EKOR SEKILOGRAM)",
      "IKAN SIAKAP": "IKAN SIAKAP (ANTARA 2 HINGGA 4 EKOR SEKILOGRAM)",
      "UDANG": "UDANG PUTIH BESAR (ANTARA 20 HINGGA 30 EKOR SEKILOGRAM)",
      "SOTONG": "SOTONG (≥ 6 EKOR SEKILOGRAM)",
      "IKAN BILIS": "IKAN BILIS GRED B (KOPEK)",
      "BERAS": "BERAS SUPER CAP RAMBUTAN 5% (IMPORT)",
      "MINYAK MASAK": "MINYAK MASAK TULEN CAP SAJI",
      "GULA": "GULA PUTIH BERTAPIS KASAR (PELBAGAI JENAMA)",
      "TEPUNG GANDUM": "TEPUNG GANDUM GP (BERBUNGKUS) PELBAGAI JENAMA",
      "SANTAN": "SANTAN KELAPA SEGAR (BIASA)",
      "GARAM": "GARAM HALUS BIASA (PELBAGAI JENAMA)",
      "KICAP MANIS": "KICAP LEMAK MANIS CAP KIPAS UDANG",
      "SOS TIRAM": "SOS TIRAM MAGGI",
      "CILI KERING": "CILI KERING KERINTING (BERTANGKAI/TIDAK BERTANGKAI)",
      "SERBUK KUNYIT": "SERBUK KUNYIT BABAS",
      "SERBUK KARI AYAM": "SERBUK KARI AYAM DAN DAGING ADABI",
    };

    try {
      final QuerySnapshot storeDocs = await FirebaseFirestore.instance
          .collection('stores')
          .get();

      for (String genericName in _targetPrices.keys) {
        // Prevent spamming the user multiple times per session
        if (_alertedThisSession.contains(genericName)) continue;

        double target = _targetPrices[genericName]!;
        String dbKey = dosmTranslator[genericName] ?? genericName;

        double lowestPrice = double.infinity;
        String bestStore = "";

        for (var doc in storeDocs.docs) {
          Map<String, dynamic> storeData = doc.data() as Map<String, dynamic>;
          Map<String, dynamic> pricesMap = storeData['prices'] ?? {};

          if (pricesMap.containsKey(dbKey)) {
            var priceData = pricesMap[dbKey];
            double price = priceData is Map
                ? (priceData['price'] as num).toDouble()
                : (priceData as num).toDouble();

            if (price < lowestPrice) {
              lowestPrice = price;
              bestStore = storeData['name'] ?? "A nearby store";
            }
          }
        }

        // FIRE NOTIFICATION IF IT BEATS THE TARGET
        if (lowestPrice <= target) {
          _alertedThisSession.add(genericName);
          NotificationService().showPriceDropNotification(
            genericName,
            lowestPrice,
            bestStore,
          );
        }
      }
    } catch (e) {
      print("Error checking price drops: $e");
    }
  }

  // --- NEW: TARGET PRICE SAVING METHODS ---
  Future<void> setTargetPrice(String item, double price) async {
    _targetPrices[item] = price;
    notifyListeners();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'target_prices': _targetPrices,
      }, SetOptions(merge: true));
    }
  }

  Future<void> removeTargetPrice(String item) async {
    _targetPrices.remove(item);
    notifyListeners();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'target_prices': _targetPrices,
      }, SetOptions(merge: true));
    }
  }

  // --- STANDARD INGREDIENT/EXPIRY METHODS (Unchanged) ---
  Future<void> _syncToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    Map<String, dynamic> uploadData = _savedIngredients.map(
      (key, value) => MapEntry(key, value.toMap()),
    );
    try {
      await docRef.update({'pantry': uploadData});
    } catch (e) {
      await docRef.set({'pantry': uploadData});
    }
  }

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

  void addExpiryDate(String item, DateTime date) {
    if (_savedIngredients.containsKey(item)) {
      _savedIngredients[item]!.expiryDates.add(date);
      _savedIngredients[item]!.expiryDates.sort((a, b) => a.compareTo(b));
      notifyListeners();
      _syncToFirebase();
      NotificationService().scheduleExpiryNotification(item, date);
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
      NotificationService().cancelNotification(item, dateToRemove);
    }
  }

  void updateExpiryDate(String item, DateTime oldDate, DateTime newDate) {
    if (_savedIngredients.containsKey(item)) {
      removeExpiryDate(item, oldDate);
      addExpiryDate(item, newDate);
    }
  }

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
