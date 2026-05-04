import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recipe_app/searchBar.dart';
import 'package:recipe_app/store_map_screen.dart'; // THE MISSING PIECE!

class IngredientPrices extends StatefulWidget {
  String ingredientName;

  IngredientPrices({super.key, required this.ingredientName});

  @override
  State<IngredientPrices> createState() => _IngredientPricesState();
}

class _IngredientPricesState extends State<IngredientPrices> {
  String _selectedLocation = 'My Location';
  final List<String> _locationOptions = [
    'My Location',
    'Cheras',
    'Kepong',
    'Bukit Bintang',
  ];

  bool _isLoading = true;
  String _statusMessage = "Locating nearby stores...";
  Position? _userPosition;
  List<Map<String, dynamic>> _nearbyStores = [];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return; // <--- ADD THIS
      setState(() {
        _statusMessage = "Please turn on your phone's GPS.";
        _isLoading = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return; // <--- ADD THIS
        setState(() {
          _statusMessage = "Location permission denied.";
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return; // <--- ADD THIS
      setState(() {
        _statusMessage = "Permissions permanently denied in phone settings.";
        _isLoading = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      _userPosition = position;
      if (widget.ingredientName != "") {
        await _fetchStorePricesFromFirebase();
      }
    } catch (e) {
      if (!mounted) return; // <--- ADD THIS
      setState(() {
        _statusMessage = "Failed to get location.";
        _isLoading = false;
      });
    }
  }

  // --- THE REAL FIREBASE CONNECTION ---
  Future<void> _fetchStorePricesFromFirebase() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "Finding stores...";
      _nearbyStores = [];
    });

    Map<String, String> dosmTranslator = {
      "BAWANG MERAH": "BAWANG KECIL MERAH BIASA IMPORT (INDIA)",
      "CILI PADI": "CILI MERAH - KULAI",
      "CILI MERAH": "CILI MERAH - KULAI",
    };

    String dbSearchKey =
        dosmTranslator[widget.ingredientName] ?? widget.ingredientName;

    try {
      final QuerySnapshot storeDocs = await FirebaseFirestore.instance
          .collection('stores')
          .get();

      // 1. Dictionary to keep the closest store per brand
      Map<String, Map<String, dynamic>> closestStorePerBrand = {};

      for (var doc in storeDocs.docs) {
        Map<String, dynamic> storeData = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> pricesMap = storeData['prices'] ?? {};

        if (pricesMap.containsKey(dbSearchKey)) {
          // --- 2. CALCULATE STRAIGHT LINE DISTANCE ---
          double distanceKm =
              Geolocator.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                storeData['lat'],
                storeData['lng'],
              ) /
              1000;

          bool passesLocationCheck = false;

          if (_selectedLocation == 'My Location') {
            if (distanceKm <= 30.0) passesLocationCheck = true;
          } else {
            String storeAddress = storeData['address'].toString().toUpperCase();
            String storeName = storeData['name'].toString().toUpperCase();
            String targetArea = _selectedLocation.toUpperCase();

            if (storeName.contains(targetArea) ||
                storeAddress.contains(targetArea)) {
              passesLocationCheck = true;
            }
          }

          if (!passesLocationCheck) continue;

          // --- 3. BRAND DEDUPLICATION LOGIC ---
          String brandName = _identifyBrand(storeData['name']);

          Map<String, dynamic> currentStore = {
            "name": storeData['name'],
            "price": (pricesMap[dbSearchKey] as num).toDouble(),
            "distance_km": distanceKm,
            "lat": storeData['lat'],
            "lng": storeData['lng'],
            "brand": brandName,
          };

          // If we haven't seen this brand yet, or this store is closer than the one we found
          if (!closestStorePerBrand.containsKey(brandName) ||
              distanceKm < closestStorePerBrand[brandName]!['distance_km']) {
            closestStorePerBrand[brandName] = currentStore;
          }
        }
      }

      // --- 4. FINAL SORTING ---
      List<Map<String, dynamic>> finalResult = closestStorePerBrand.values
          .toList();

      // Cheapest price first
      finalResult.sort((a, b) => a["price"].compareTo(b["price"]));

      if (!mounted) return;
      setState(() {
        _nearbyStores = finalResult;
        _isLoading = false;
      });
    } catch (e) {
      print("Firebase Error: $e");
      if (!mounted) return;
      setState(() {
        _statusMessage = "Failed to load store prices.";
        _isLoading = false;
      });
    }
  }

  // --- HELPER: BRAND IDENTIFIER ---
  String _identifyBrand(String name) {
    String upperName = name.toUpperCase();
    if (upperName.contains("LOTUS")) return "LOTUS'S";
    if (upperName.contains("AEON")) return "AEON BIG";
    if (upperName.contains("KK")) return "KK MART";
    if (upperName.contains("VILLAGE GROCER")) return "VILLAGE GROCER";
    if (upperName.contains("JAYA GROCER")) return "JAYA GROCER";
    return "OTHER";
  }

  // --- HELPER: MAPBOX MATRIX API ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Prices",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsetsGeometry.all(10),
            child: IngredientSearchBar(
              onPlus: (test) {},
              onSearchChanged: (value) {
                setState(() {
                  widget.ingredientName = value;
                });
                _fetchStorePricesFromFirebase();
              },
              hintText: "Enter ingredient here",
              defaultText: widget.ingredientName,
              havePlusButton: false,
            ),
          ),

          // --- THE NEW DROPDOWN UI ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLocation,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.green,
                ),
                items: _locationOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value == 'My Location'
                          ? '📍 My Current Location'
                          : '🏙️ $value',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null && newValue != _selectedLocation) {
                    setState(() {
                      _selectedLocation = newValue;
                      _isLoading = true; // Show the spinner again
                    });
                    // Re-run the database query with the new location!
                    _fetchStorePricesFromFirebase();
                  }
                },
              ),
            ),
          ),

          // A subtle divider line
          Divider(height: 1, color: Colors.grey[300]),

          // --- THE EXISTING STORE LIST ---
          Expanded(
            child: _isLoading && widget.ingredientName != ""
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _nearbyStores.isEmpty
                ? const Center(
                    child: Text(
                      "No stores found in this area.",
                      style: TextStyle(color: Colors.red),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _nearbyStores.length,
                    itemBuilder: (context, index) {
                      // ... (Keep your exact Card and ListTile code here) ...
                      final store = _nearbyStores[index];
                      bool isCheapest = index == 0;

                      return Card(
                        elevation: isCheapest ? 4 : 1,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isCheapest
                              ? BorderSide(
                                  color: Colors.green.shade300,
                                  width: 2,
                                )
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StoreMapScreen(
                                  storeName: store["name"],
                                  // Make sure these match the keys in your store data!
                                  targetLat: store["lat"],
                                  targetLng: store["lng"],
                                  userLat: _userPosition!.latitude,
                                  userLng: _userPosition!.longitude,
                                  nearbyStores: _nearbyStores,
                                ),
                              ),
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isCheapest
                                ? Colors.green[100]
                                : Colors.grey[200],
                            child: Icon(
                              Icons.storefront,
                              color: isCheapest
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                            ),
                          ),
                          title: Text(
                            store["name"],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${store["distance_km"].toStringAsFixed(1)} km away",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          trailing: Text(
                            "RM ${store["price"].toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isCheapest
                                  ? Colors.green[700]
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
