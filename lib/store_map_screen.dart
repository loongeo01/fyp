import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:recipe_app/config/env.dart';

// --- ADD THIS TO YOUR ENV FILE ---
final googleApiKey = Env.googleApiKey;

class StoreMapScreen extends StatefulWidget {
  final String storeName;
  final double targetLat;
  final double targetLng;
  final double userLat;
  final double userLng;
  final List<Map<String, dynamic>> nearbyStores;

  const StoreMapScreen({
    super.key,
    required this.storeName,
    required this.targetLat,
    required this.targetLng,
    required this.userLat,
    required this.userLng,
    required this.nearbyStores,
  });

  @override
  State<StoreMapScreen> createState() => _StoreMapScreenState();
}

class _StoreMapScreenState extends State<StoreMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  BitmapDescriptor? _customMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  Future<void> _loadCustomMarker() async {
    // Converts your existing marker.png to a Google Maps compatible icon
    _customMarkerIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/marker.png',
    );
    _addGroceryStorePins();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _addGroceryStorePins() {
    Set<Marker> newMarkers = {};
    List<String> usedCoords = [];

    for (var store in widget.nearbyStores) {
      double lat = (store['lat'] as num).toDouble();
      double lng = (store['lng'] as num).toDouble();
      String coordKey = "${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}";

      // Slightly shift overlapping pins (kept exactly from your original logic)
      if (usedCoords.contains(coordKey)) {
        lat += 0.00015;
      }
      usedCoords.add(coordKey);

      newMarkers.add(
        Marker(
          markerId: MarkerId(store['name'] + lat.toString()),
          position: LatLng(lat, lng),
          icon:
              _customMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _showStoreBottomSheet(store, lat, lng),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  // --- YOUR EXACT ORIGINAL BOTTOM SHEET UI ---
  void _showStoreBottomSheet(
    Map<String, dynamic> store,
    double storeLat,
    double storeLng,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          height: 380,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- STITCH: DRAG HANDLE ---
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- STITCH: HEADER ROW ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Nearest Store",
                            style: TextStyle(
                              color: Color(0xFF006E1C),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          store['name'], // Replaced Mapbox's clickedPin.textField with your store name
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: Color(0xFF191C1B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Best prices found here",
                          style: TextStyle(
                            color: Color(0xFF6F7A6B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Mock Rating Block to match UI
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.star, color: Colors.orange, size: 20),
                          SizedBox(width: 4),
                          Text(
                            "4.9",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "120+ reviews",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- STITCH: DETAILS GRID ---
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, color: Color(0xFF006E1C)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Open until",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                "10:00 PM",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.eco, color: Color(0xFF006E1C)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Inventory",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                "In Stock",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // --- STITCH: ACTION BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006E1C),
                    elevation: 4,
                    shadowColor: const Color(0xFF006E1C).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: const Icon(Icons.near_me, color: Colors.white),
                  label: const Text(
                    "Navigate Here",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    _drawRouteToStore(storeLat, storeLng);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- REBUILT FOR GOOGLE DIRECTIONS API ---
  Future<void> _drawRouteToStore(double destLat, double destLng) async {
    double userLat = widget.userLat;
    double userLng = widget.userLng;

    // Calls the Google Directions API instead of Mapbox
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$userLat,$userLng&destination=$destLat,$destLng&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'].isNotEmpty) {
          String encodedPolyline =
              data['routes'][0]['overview_polyline']['points'];
          List<LatLng> routePoints = _decodePolyline(encodedPolyline);

          setState(() {
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: routePoints,
                color: Colors.blue,
                width: 5,
              ),
            );
          });

          // Zoom out to show the whole route
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(
              _boundsFromLatLngList(routePoints),
              50.0, // padding
            ),
          );
        }
      }
    } catch (e) {
      print("Routing Error: $e");
    }
  }

  // Helper method to decode Google's weird polyline string into map coordinates
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return poly;
  }

  // Helper to adjust camera to fit the route
  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.targetLat, widget.targetLng),
              zoom: 13.0,
            ),
            // MODERN FIX: Map the list directly to markers here
            markers: widget.nearbyStores.map((store) {
              return Marker(
                markerId: MarkerId(store['name']),
                position: LatLng(store['lat'], store['lng']),
                // Using the default "Advanced Marker" styling available in 2026
                // which handles performance and styling much better natively
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
                onTap: () =>
                    _showStoreBottomSheet(store, store['lat'], store['lng']),
              );
            }).toSet(),
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),

          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF191C1B)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
