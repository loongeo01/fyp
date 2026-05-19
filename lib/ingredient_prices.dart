import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:recipe_app/app_images.dart';
import 'package:recipe_app/pantry_provider.dart';
import 'package:recipe_app/searchBar.dart';
import 'package:recipe_app/store_map_screen.dart';
import 'package:recipe_app/price_alerts_screen.dart'; // <--- NEW IMPORT
import 'premium_ingredient_wrap.dart';

class IngredientPrices extends StatefulWidget {
  final String ingredientName;
  final List<String> initialBasket;

  const IngredientPrices({
    super.key,
    this.ingredientName = "",
    this.initialBasket = const [],
  });

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

  final List<String> _basket = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialBasket.isNotEmpty) {
      _basket.addAll(widget.initialBasket.map((e) => e.toUpperCase()));
    } else if (widget.ingredientName.isNotEmpty) {
      _basket.add(widget.ingredientName.toUpperCase());
    }

    _determinePosition();
  }

  void _addToBasket(String item) {
    String cleanItem = item.trim().toUpperCase();
    if (cleanItem.isNotEmpty && !_basket.contains(cleanItem)) {
      setState(() {
        _basket.insert(0, cleanItem);
        _isLoading = true;
      });
      _fetchStorePrices();
    }
  }

  void _removeFromBasket(String item) {
    setState(() {
      _basket.remove(item);
      if (_basket.isEmpty) {
        _nearbyStores = [];
        _isLoading = false;
      } else {
        _isLoading = true;
      }
    });
    if (_basket.isNotEmpty) {
      _fetchStorePrices();
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
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
        if (!mounted) return;
        setState(() {
          _statusMessage = "Location permission denied.";
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _statusMessage = "Permissions permanently denied in phone settings.";
        _isLoading = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      _userPosition = position;
      if (_basket.isNotEmpty) {
        await _fetchStorePrices();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = "Failed to get location.";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStorePrices() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "Calculating basket totals...";
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

    try {
      final QuerySnapshot storeDocs = await FirebaseFirestore.instance
          .collection('stores')
          .get();

      Map<String, Map<String, dynamic>> closestStorePerBrand = {};

      for (var doc in storeDocs.docs) {
        Map<String, dynamic> storeData = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> pricesMap = storeData['prices'] ?? {};

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

        double totalBasketPrice = 0.0;
        int foundCount = 0;
        List<String> missingItems = [];

        // Fetching breakdown for UI
        List<Map<String, dynamic>> foundItems = [];

        for (String item in _basket) {
          String dbSearchKey = dosmTranslator[item] ?? item;

          if (pricesMap.containsKey(dbSearchKey)) {
            var priceData = pricesMap[dbSearchKey];
            double itemPrice = 0.0;
            String itemUnit = "";

            if (priceData is Map) {
              itemPrice = (priceData['price'] as num).toDouble();
              itemUnit = priceData['unit']?.toString() ?? "";
            } else {
              itemPrice = (priceData as num).toDouble();
            }

            totalBasketPrice += itemPrice;
            foundCount++;

            foundItems.add({
              "name": item,
              "price": itemPrice,
              "unit": itemUnit,
            });
          } else {
            missingItems.add(item);
          }
        }

        if (foundCount == 0) continue;

        String brandName = _identifyBrand(storeData['name']);

        Map<String, dynamic> currentStore = {
          "name": storeData['name'],
          "total_price": totalBasketPrice,
          "found_count": foundCount,
          "found_items": foundItems,
          "missing_items": missingItems,
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

      List<Map<String, dynamic>> finalResult = closestStorePerBrand.values
          .toList();

      finalResult.sort((a, b) {
        int countCompare = b["found_count"].compareTo(a["found_count"]);
        if (countCompare != 0) return countCompare;
        return a["total_price"].compareTo(b["total_price"]);
      });

      if (!mounted) return;
      setState(() {
        _nearbyStores = finalResult;
        _isLoading = false;
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
          "Smart Basket",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -0.5,
            color: Color(0xFF006E1C),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF191C1B)),
        // --- NEW: PIN ICON ACTION ---
        actions: [
          IconButton(
            icon: const Icon(Icons.push_pin_outlined, color: Color(0xFF006E1C)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PriceAlertsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    onPlus: (value) => _addToBasket(value),
                    onSearchChanged: (value) {},
                    hintText: "Add ingredient to basket...",
                    havePlusButton: true,
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
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
                                _isLoading = true;
                              });
                              _fetchStorePrices();
                            }
                          },
                        ),
                      ),
                    ),
                    Text(
                      "${_basket.length} Items in Basket",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6F7A6B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                PremiumIngredientWrap(
                  ingredients: _basket,
                  maxHeight: 90.0,
                  onDeleted: (item) => _removeFromBasket(item),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8E2)),

          Expanded(
            child: _isLoading && _basket.isNotEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF006E1C)),
                  )
                : _basket.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_basket_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Your basket is empty",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : _nearbyStores.isEmpty
                ? Center(
                    child: Text(
                      "No stores have these items.",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: _nearbyStores.length,
                    itemBuilder: (context, index) {
                      return StoreReceiptCard(
                        store: _nearbyStores[index],
                        isBestOption: index == 0,
                        totalBasketSize: _basket.length,
                        userPosition: _userPosition!,
                        allNearbyStores: _nearbyStores,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class StoreReceiptCard extends StatefulWidget {
  final Map<String, dynamic> store;
  final bool isBestOption;
  final int totalBasketSize;
  final Position userPosition;
  final List<Map<String, dynamic>> allNearbyStores;

  const StoreReceiptCard({
    super.key,
    required this.store,
    required this.isBestOption,
    required this.totalBasketSize,
    required this.userPosition,
    required this.allNearbyStores,
  });

  @override
  State<StoreReceiptCard> createState() => _StoreReceiptCardState();
}

class _StoreReceiptCardState extends State<StoreReceiptCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    int found = widget.store["found_count"];
    List<String> missing = widget.store["missing_items"] as List<String>;
    List<Map<String, dynamic>> foundItems =
        widget.store["found_items"] as List<Map<String, dynamic>>;

    // Watch the global target prices
    final targetPrices = context.watch<PantryProvider>().targetPrices;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: widget.isBestOption
            ? Border.all(
                color: const Color(0xFF006E1C).withOpacity(0.5),
                width: 2.0,
              )
            : Border.all(color: Colors.grey.shade100, width: 1.0),
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
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image(
                        image: AppImages.getStoreImageProvider(
                          widget.store["brand"] ?? "Store",
                        ),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "RM ${widget.store["total_price"].toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: Color(0xFF006E1C),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            "Basket Total",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Icon(
                    found == widget.totalBasketSize
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 16,
                    color: found == widget.totalBasketSize
                        ? const Color(0xFF006E1C)
                        : const Color(0xFFD78A1F),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Found $found of ${widget.totalBasketSize} items",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: found == widget.totalBasketSize
                          ? const Color(0xFF006E1C)
                          : const Color(0xFFD78A1F),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.map_outlined,
                    size: 14,
                    color: Color(0xFF6F7A6B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${widget.store["distance_km"].toStringAsFixed(1)} km",
                    style: const TextStyle(
                      color: Color(0xFF6F7A6B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              if (_isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF2F4F2), thickness: 1.5),
                const SizedBox(height: 12),

                const Text(
                  "RECEIPT BREAKDOWN",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6F7A6B),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                ...foundItems.map((item) {
                  // --- NEW: CHECK IF ITEM IS TRACKED ---
                  bool isTracked = targetPrices.containsKey(item["name"]);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // THE INGREDIENT NAME + BADGE
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item["name"],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF191C1B),
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isTracked)
                                Container(
                                  margin: const EdgeInsets.only(left: 3),
                                  child: Icon(
                                    Icons.push_pin,
                                    size: 13,
                                    color: Color(0xFFD78A1F),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // THE PRICE
                        Row(
                          children: [
                            Text(
                              "RM ${item["price"].toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006E1C),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(173, 16, 122, 39),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(
                                  item["unit"].toString().isNotEmpty
                                      ? '${item["unit"]}'
                                      : '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),

                if (missing.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD78A1F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Color(0xFFD78A1F),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Not available here: ${missing.join(", ")}",
                            style: const TextStyle(
                              color: Color(0xFFD78A1F),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoreMapScreen(
                            storeName: widget.store["name"],
                            targetLat: widget.store["lat"],
                            targetLng: widget.store["lng"],
                            userLat: widget.userPosition.latitude,
                            userLng: widget.userPosition.longitude,
                            nearbyStores: widget.allNearbyStores,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.directions,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Get Directions",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006E1C),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
