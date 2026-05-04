import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:recipe_app/config/env.dart';

final token = Env.mapboxToken;

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
  mapbox.MapboxMap? mapboxMap;
  mapbox.PointAnnotationManager? annotationManager;
  mapbox.PolylineAnnotationManager? polylineAnnotationManager;

  Future<void> _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    annotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    polylineAnnotationManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();

    _setupPinTapListener();
    _addGroceryStorePins();
  }

  Future<void> _addGroceryStorePins() async {
    final ByteData bytes = await rootBundle.load('assets/marker.png');
    final Uint8List list = bytes.buffer.asUint8List();

    await annotationManager?.deleteAll();
    List<String> usedCoords = [];

    for (var store in widget.nearbyStores) {
      double lat = (store['lat'] as num).toDouble();
      double lng = (store['lng'] as num).toDouble();
      String coordKey = "${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}";

      if (usedCoords.contains(coordKey)) {
        lat += 0.00015;
      }
      usedCoords.add(coordKey);

      annotationManager?.create(
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
          image: list,
          iconSize: 0.2,
          iconOffset: [0.0, -10.0],
          textField: store['name'],
          textSize: 0.0,
        ),
      );
    }
  }

  void _setupPinTapListener() {
    annotationManager?.tapEvents(
      onTap: (mapbox.PointAnnotation clickedPin) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          isScrollControlled: true, // Allows the sheet to be taller
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(32),
            ), // Stitch curve
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              height: 380, // Taller to fit the Stitch Grid
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
                                color: const Color(
                                  0xFF4CAF50,
                                ).withOpacity(0.15),
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
                              clickedPin.textField ?? "Selected Store",
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
                              const Icon(
                                Icons.schedule,
                                color: Color(0xFF006E1C),
                              ),
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
                          borderRadius: BorderRadius.circular(
                            28,
                          ), // Fully rounded
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
                        final lat = clickedPin.geometry.coordinates.lat
                            .toDouble();
                        final lng = clickedPin.geometry.coordinates.lng
                            .toDouble();
                        _drawRouteToStore(lat, lng);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _drawRouteToStore(double destLat, double destLng) async {
    double userLat = widget.userLat;
    double userLng = widget.userLng;
    final String accessToken = token!;

    final url =
        'https://api.mapbox.com/directions/v5/mapbox/driving/$userLng,$userLat;$destLng,$destLat?geometries=geojson&access_token=$accessToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];

        List<mapbox.Position> routePoints = coordinates.map((coord) {
          return mapbox.Position(coord[0], coord[1]);
        }).toList();

        await polylineAnnotationManager?.deleteAll();

        var polylineOptions = mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: routePoints),
          lineColor: Colors.blue.value,
          lineWidth: 5.0,
          lineOpacity: 0.8,
        );

        polylineAnnotationManager?.create(polylineOptions);

        mapboxMap?.setCamera(
          mapbox.CameraOptions(
            padding: mapbox.MbxEdgeInsets(
              top: 100,
              left: 100,
              bottom: 100,
              right: 100,
            ),
          ),
        );
      }
    } catch (e) {
      print("Routing Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(widget.targetLng, widget.targetLat),
              ),
              zoom: 13.0,
            ),
            styleUri: MapboxStyles.MAPBOX_STREETS,
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
