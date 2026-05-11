import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recipe_app/app_images.dart';
import 'pantry_provider.dart';

class PriceAlertsScreen extends StatefulWidget {
  const PriceAlertsScreen({super.key});

  @override
  State<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends State<PriceAlertsScreen> {
  Future<double> _fetchCurrentLowestPrice(String ingredient) async {
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

    String dbKey = dosmTranslator[ingredient] ?? ingredient;
    double lowest = double.infinity;

    try {
      QuerySnapshot stores = await FirebaseFirestore.instance
          .collection('stores')
          .get();
      for (var doc in stores.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> prices = data['prices'] ?? {};
        if (prices.containsKey(dbKey)) {
          var pData = prices[dbKey];
          double p = pData is Map
              ? (pData['price'] as num).toDouble()
              : (pData as num).toDouble();
          if (p < lowest) lowest = p;
        }
      }
    } catch (e) {
      debugPrint("Error fetching lowest price: $e");
    }
    return lowest;
  }

  void _showAddAlertDialog(BuildContext context) {
    final provider = context.read<PantryProvider>();
    final TextEditingController priceController = TextEditingController();
    String selectedIngredient = "";
    bool isFetchingPrice = false;

    final List<String> availableItems = provider.masterIngredients
        .map((e) => e['name'].toString().toUpperCase())
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD78A1F).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.push_pin,
                      color: Color(0xFFD78A1F),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "New Price Alert",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF191C1B),
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return availableItems.where((String option) {
                        return option.contains(
                          textEditingValue.text.toUpperCase(),
                        );
                      });
                    },
                    onSelected: (String selection) async {
                      selectedIngredient = selection;

                      setStateDialog(() => isFetchingPrice = true);
                      double lowestPrice = await _fetchCurrentLowestPrice(
                        selection,
                      );

                      setStateDialog(() {
                        isFetchingPrice = false;
                        if (lowestPrice != double.infinity) {
                          priceController.text = lowestPrice.toStringAsFixed(2);
                        }
                      });
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onEditingComplete) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF191C1B),
                            ),
                            decoration: InputDecoration(
                              hintText: "Search ingredient...",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.normal,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAF8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF006E1C),
                              ),
                            ),
                          );
                        },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF006E1C),
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      prefixText: "RM ",
                      prefixStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006E1C),
                        fontSize: 18,
                      ),
                      hintText: "Target Price",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAF8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: isFetchingPrice
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF006E1C),
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(priceController.text);
                    if (val != null && selectedIngredient.isNotEmpty) {
                      provider.setTargetPrice(selectedIngredient, val);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006E1C),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Save Alert",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetPrices = context.watch<PantryProvider>().targetPrices;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          "Price Alerts",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF006E1C),
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF191C1B)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF006E1C).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF006E1C), size: 24),
              onPressed: () => _showAddAlertDialog(context),
            ),
          ),
        ],
      ),
      body: targetPrices.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                100,
              ), // Extra padding at bottom
              // Add 1 for the header
              itemCount: targetPrices.length + 1,
              itemBuilder: (context, index) {
                // --- INDEX 0: THE PREMIUM HEADER ---
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF006E1C), Color(0xFF0A4F1A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF006E1C).withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.trending_down,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Active Deals Tracker",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "We'll silently check nearby stores and notify you when prices drop.",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // --- INDEX 1+: THE ALERT CARDS ---
                String itemName = targetPrices.keys.elementAt(index - 1);
                double price = targetPrices[itemName]!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF142814).withOpacity(0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // The sleek Squircle Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: Builder(
                              builder: (context) {
                                String? imageUrl = context
                                    .read<PantryProvider>()
                                    .getImageUrl(itemName);
                                if (imageUrl != null && imageUrl.isNotEmpty) {
                                  return CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        Image.asset(
                                          AppImages.getIngredientImage(
                                            itemName,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                  );
                                }
                                return Image.asset(
                                  AppImages.getIngredientImage(itemName),
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Information
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF191C1B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.trending_down,
                                    size: 14,
                                    color: const Color(0xFFD78A1F),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Target: RM ${price.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD78A1F),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Delete Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () => context
                                .read<PantryProvider>()
                                .removeTargetPrice(itemName),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              size: 64,
              color: Color(0xFFBECAB9),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No active alerts",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tap the + icon above to start tracking\nan ingredient's price.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6F7A6B),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
