import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart'; // For rootBundle
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
  // --- ADDED: This connects the data from your list to the map ---
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

    // --- CRITICAL: You must call the listener setup here! ---
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
          // --- THE GHOST TEXT TRICK ---
          // We keep the name so the Bottom Sheet can read it...
          textField: store['name'],
          // ...but set size to 0 so it stays invisible on the map!
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
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: 220,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // Now this will correctly show the store name!
                    clickedPin.textField ?? "Selected Store",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Best prices for your ingredients found here.",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        // Use the coordinates of the specific pin tapped
                        final lat = clickedPin.geometry.coordinates.lat
                            .toDouble();
                        final lng = clickedPin.geometry.coordinates.lng
                            .toDouble();
                        _drawRouteToStore(lat, lng);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Navigate Here",
                        style: TextStyle(color: Colors.white),
                      ),
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
    // 1. Use the coordinates we passed from the price list screen!
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

        // Apply prefixes to Position
        List<mapbox.Position> routePoints = coordinates.map((coord) {
          return mapbox.Position(coord[0], coord[1]);
        }).toList();

        await polylineAnnotationManager?.deleteAll();

        // Apply prefixes to PolylineAnnotationOptions and LineString
        var polylineOptions = mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: routePoints),
          lineColor: Colors.blue.value,
          lineWidth: 5.0,
          lineOpacity: 0.8,
        );

        polylineAnnotationManager?.create(polylineOptions);

        // Auto-zoom to show the whole route
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
      // A Stack allows us to put the map on the bottom, and UI on top
      body: Stack(
        children: [
          // --- LAYER 1: THE FULL SCREEN MAP ---
          MapWidget(
            key: const ValueKey("mapWidget"),
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              // Start the camera over Petaling Jaya
              center: Point(
                coordinates: Position(widget.targetLng, widget.targetLat),
              ),
              zoom: 13.0,
            ),
            styleUri: MapboxStyles.MAPBOX_STREETS, // The default map style
          ),

          // --- LAYER 2: FLOATING UI ---
          // A floating back button in the top left corner
          Positioned(
            top: 50, // Pushes it down below the phone's status bar
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
