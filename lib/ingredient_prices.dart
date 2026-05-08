import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recipe_app/app_images.dart';
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

    String searchKey = widget.ingredientName.toUpperCase();
    String dbSearchKey = dosmTranslator[searchKey] ?? searchKey;

    try {
      // 1. Fetch the 'stores' collection you populated with your Python script
      final QuerySnapshot storeDocs = await FirebaseFirestore.instance
          .collection('stores')
          .get();

      // Dictionary to keep the closest store per brand
      Map<String, Map<String, dynamic>> closestStorePerBrand = {};

      for (var doc in storeDocs.docs) {
        Map<String, dynamic> storeData = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> pricesMap = storeData['prices'] ?? {};

        // Only process stores that actually sell this ingredient
        if (pricesMap.containsKey(dbSearchKey)) {
          // 2. Calculate Distance
          double distanceKm =
              Geolocator.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                storeData['lat'],
                storeData['lng'],
              ) /
              1000;

          bool passesLocationCheck = false;

          // 3. Location Filtering logic
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

          // 4. Deduplication logic (Closest store for Lotus, Aeon, etc.)
          String brandName = _identifyBrand(storeData['name']);

          // --- THE CHANGE: Extract both price and unit from the Map ---
          var priceData = pricesMap[dbSearchKey];
          double itemPrice = 0.0;
          String itemUnit = "";

          // Safety check in case some older data is still formatted as just a number
          if (priceData is Map) {
            itemPrice = (priceData['price'] as num).toDouble();
            itemUnit = priceData['unit']?.toString() ?? "";
          } else {
            itemPrice = (priceData as num).toDouble();
          }

          Map<String, dynamic> currentStore = {
            "name": storeData['name'],
            "price": itemPrice, // <--- Updated
            "unit": itemUnit, // <--- ADDED UNIT HERE
            "distance_km": distanceKm,
            "lat": storeData['lat'],
            "lng": storeData['lng'],
            "brand": brandName,
          };

          if (!closestStorePerBrand.containsKey(brandName) ||
              distanceKm < closestStorePerBrand[brandName]!['distance_km']) {
            closestStorePerBrand[brandName] = currentStore;
          }
        }
      }

      // Convert map values back to a list
      List<Map<String, dynamic>> finalResult = closestStorePerBrand.values
          .toList();

      // 5. Final Sort: Cheapest price first
      finalResult.sort((a, b) => a["price"].compareTo(b["price"]));

      if (!mounted) return;
      setState(() {
        _nearbyStores = finalResult;
        _isLoading = false; // STOP THE SPINNER!
      });
    } catch (e) {
      debugPrint("Firebase Error: $e");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          "Nearby Results",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- STITCH: FLOATING SEARCH & LOCATION UI ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
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
                    onPlus: (test) {},
                    onSearchChanged: (value) {
                      setState(() {
                        widget.ingredientName = value;
                      });
                      _fetchStorePricesFromFirebase();
                    },
                    hintText: "Search ingredients...",
                    defaultText: widget.ingredientName,
                    havePlusButton: false,
                  ),
                ),
                const SizedBox(height: 16),
                // Modern Location Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ), // Tighter vertical padding for Dropdown
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLocation,
                          icon: const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF006E1C),
                              size: 18,
                            ),
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF191C1B),
                          ),
                          items: _locationOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  Icon(
                                    value == 'My Location'
                                        ? Icons.my_location
                                        : Icons.location_city,
                                    color: const Color(0xFF006E1C),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(value),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null &&
                                newValue != _selectedLocation) {
                              setState(() {
                                _selectedLocation = newValue;
                                _isLoading =
                                    true; // Show the spinner while searching
                              });
                              // Re-run the Firebase query with the new location
                              _fetchStorePricesFromFirebase();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // --- STITCH: PREMIUM RESULT CARDS ---
          Expanded(
            child: _isLoading && widget.ingredientName != ""
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF006E1C)),
                  )
                : _nearbyStores.isEmpty
                ? Center(
                    child: Text(
                      "No stores found.",
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: _nearbyStores.length,
                    itemBuilder: (context, index) {
                      final store = _nearbyStores[index];
                      bool isCheapest = index == 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isCheapest
                              ? Border.all(
                                  color: const Color(
                                    0xFF006E1C,
                                  ).withOpacity(0.3),
                                  width: 1.5,
                                )
                              : Border.all(
                                  color: Colors.grey.shade100,
                                  width: 1.0,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF142814).withOpacity(0.04),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StoreMapScreen(
                                  storeName: store["name"],
                                  targetLat: store["lat"],
                                  targetLng: store["lng"],
                                  userLat: _userPosition!.latitude,
                                  userLng: _userPosition!.longitude,
                                  nearbyStores: _nearbyStores,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // --- UPGRADED: STORE BRAND LOGO ---
                                SizedBox(
                                  width:
                                      90, // Made wider for rectangular logos like Lotus's
                                  height:
                                      40, // Shorter height so it doesn't take up too much vertical space
                                  child: Align(
                                    alignment: Alignment
                                        .centerLeft, // Aligns the logo to the left edge
                                    child: Image(
                                      image: AppImages.getStoreImageProvider(
                                        store["brand"] ?? "Store",
                                      ),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          // --- UPGRADED: PREMIUM RICH TEXT PRICE & UNIT ---
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                // The "Hero" Price (Big, Bold, Green)
                                                TextSpan(
                                                  text:
                                                      "RM ${store["price"].toStringAsFixed(2)}",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight
                                                        .w900, // Extra bold
                                                    fontSize: 19,
                                                    color: Color(0xFF006E1C),
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                                // The "Subtitle" Unit (Smaller, Muted Grey/Green)
                                                if (store["unit"] != null &&
                                                    store["unit"]
                                                        .toString()
                                                        .isNotEmpty)
                                                  TextSpan(
                                                    text: " / ${store["unit"]}",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      color: Color(
                                                        0xFF6F7A6B,
                                                      ), // Matches your distance text color
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          const Icon(
                                            Icons.map_outlined,
                                            size: 14,
                                            color: Color(0xFF6F7A6B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${store["distance_km"].toStringAsFixed(1)} km",
                                            style: const TextStyle(
                                              color: Color(0xFF6F7A6B),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: CircleAvatar(
                                              radius: 2,
                                              backgroundColor: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            isCheapest
                                                ? "In Stock"
                                                : "Low Stock",
                                            style: TextStyle(
                                              color: isCheapest
                                                  ? const Color(0xFF006E1C)
                                                  : Colors.orange,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
