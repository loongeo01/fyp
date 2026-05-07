import 'dart:convert';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:http/http.dart' as http; // <-- NEW IMPORT

class AIRecipeService {
  // --- NEW: UNSPLASH IMAGE FETCHER ---
  static Future<String?> _getRealPhoto(String query) async {
    // ⚠️ PASTE YOUR UNSPLASH ACCESS KEY HERE:
    const clientId = 'zaJZVAt1o0_iLsowHW1ICdOQm2LAHOOJTAe4zS8KQek';

    // We ask for 1 landscape photo matching the food name
    final url = Uri.parse(
      'https://api.unsplash.com/search/photos?query=${Uri.encodeComponent(query)}&per_page=1&orientation=landscape&client_id=$clientId',
    );

    try {
      final response = await http.get(url);

      print("Unsplash Status Code: ${response.statusCode}");
      print("Unsplash Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          // Return the URL of the actual image!
          return data['results'][0]['urls']['regular'];
        }
      }
    } catch (e) {
      print("Unsplash Error: $e");
    }
    return null; // Returns null if Unsplash fails, triggering your local fallback
  }

  static Future<List<dynamic>?> generateRecipes({
    required List<String> availableIngredients,
    List<String> previousRecipes = const [],
  }) async {
    try {
      final model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-2.5-flash',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
        systemInstruction: Content.system('''
          You are a world-class chef. Create 3 unique, delicious recipes.
          Do NOT suggest these: ${previousRecipes.join(", ")}.
          
          CRITICAL INSTRUCTION FOR INGREDIENTS:
          You MUST return ONLY the raw ingredient names in UPPERCASE (e.g. "SERAI"). 
          DO NOT include quantities or measurements.
          
          You MUST respond in valid JSON using EXACTLY this schema:
          {
            "recipes": [
              {
                "name": "Ayam Goreng Berempah",
                "search_term": "Ayam Goreng", // <-- NEW: A short, punchy search term for Unsplash
                "time": "45 mins",
                "difficulty": "Medium",
                "ingredients": ["SERAI", "BAWANG MERAH", "CHICKEN"],
                "instructions": ["Step 1...", "Step 2..."]
              }
            ]
          }
        '''),
      );

      final prompt = [
        Content.text('My pantry: ${availableIngredients.join(", ")}'),
      ];
      final response = await model.generateContent(prompt);

      if (response.text != null) {
        String rawText = response.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final Map<String, dynamic> parsedJson = jsonDecode(rawText);
        List<dynamic> recipes = parsedJson["recipes"];

        // --- NEW: THE MAGIC LOOP ---
        // Before giving the recipes to the UI, we fetch the images!
        await Future.wait(
          recipes.map((recipe) async {
            if (recipe["search_term"] != null) {
              // Ask Unsplash for a photo
              String? foundUrl = await _getRealPhoto(recipe["search_term"]);
              recipe["image_url"] = foundUrl;
            }
            recipe["isAI"] = true;
          }),
        );

        return recipes;
      }
      return null;
    } catch (e) {
      print("AI Chef Error: $e");
      return null;
    }
  }
}
