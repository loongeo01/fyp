import 'dart:convert';
import 'package:http/http.dart' as http;

class PriceService {
  // The base URL for the OpenDOSM API
  static const String baseUrl = 'https://api.data.gov.my/data-catalogue';

  // A function to fetch the price of a specific ingredient
  static Future<String> getEstimatedPrice(String ingredientName) async {
    try {
      // Note: This is a structured example. We will need to find the exact
      // dataset ID on OpenDOSM for the PriceCatcher data.
      final url = Uri.parse(
        '$baseUrl?id=pricecatcher_prices&item=$ingredientName&state=Selangor',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        // 1. Convert the raw text response into a Dart Map (JSON)
        final data = json.decode(response.body);

        // 2. Extract the price value from the DOSM data structure
        // (We will adjust this logic once we see the exact DOSM JSON format)
        double averagePrice = data['average_price'] ?? 0.0;

        return "RM ${averagePrice.toStringAsFixed(2)}";
      } else {
        return "Price Unavailable";
      }
    } catch (e) {
      print("API Error: $e");
      return "Price Unavailable";
    }
  }
}
