import 'dart:convert';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:http/http.dart' as http;
import 'package:recipe_app/config/env.dart';

class AIRecipeService {
  // --- NEW: THE MASTER INGREDIENT LIST ---
  // We define this here so the AI knows EXACTLY what exists in your database.
  static const List<String> _masterIngredients = [
    "BAWANG MERAH",
    "BAWANG BESAR",
    "BAWANG PUTIH",
    "HALIA",
    "SERAI",
    "LENGKUAS",
    "TOMATO",
    "LOBAK MERAH",
    "SAWI",
    "KOBIS",
    "TIMUN",
    "TERUNG",
    "CILI MERAH",
    "CILI PADI",
    "UBI KENTANG",
    "BROKOLI",
    "AYAM",
    "DAGING",
    "TELUR",
    "IKAN KEMBUNG",
    "IKAN SIAKAP",
    "UDANG",
    "SOTONG",
    "IKAN BILIS",
    "BERAS",
    "MINYAK MASAK",
    "GULA",
    "TEPUNG GANDUM",
    "SANTAN",
    "GARAM",
    "KICAP MANIS",
    "SOS TIRAM",
    "CILI KERING",
    "SERBUK KUNYIT",
    "SERBUK KARI AYAM",
  ];

  static Future<String?> _getRealPhoto(String query) async {
    final clientId = Env.clientID;

    final url = Uri.parse(
      'https://api.unsplash.com/search/photos?query=${Uri.encodeComponent(query)}&per_page=1&orientation=landscape&client_id=$clientId',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['urls']['regular'];
        }
      }
    } catch (e) {
      print("Unsplash Error: $e");
    }
    return null;
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
          temperature:
              0.2, // LOWER TEMPERATURE: Makes the AI less "creative" and more obedient to rules
        ),
        systemInstruction: Content.system('''
          You are a world-class chef constrainted to a very specific pantry. 
          Create 3 unique, delicious recipes.
          Do NOT suggest these: ${previousRecipes.join(", ")}.
          
          CRITICAL INSTRUCTION FOR INGREDIENTS:
          1. You MUST ONLY construct your recipes using ingredients from this exact allowed list:
          [${_masterIngredients.join(", ")}]
          2. DO NOT invent, suggest, or use ANY outside ingredients (e.g. no olive oil, no black pepper, no butter) unless it is on the allowed list. 
          3. You MUST return ONLY the raw ingredient names in UPPERCASE exactly as they appear in the list.
          4. DO NOT include quantities or measurements in the ingredients array.
          
          You MUST respond in valid JSON using EXACTLY this schema:
          {
            "recipes": [
              {
                "name": "Ayam Goreng Berempah",
                "search_term": "Ayam Goreng",
                "time": "45 mins",
                "difficulty": "Medium",
                "ingredients": ["SERAI", "BAWANG MERAH", "AYAM"],
                "instructions": ["Step 1...", "Step 2..."]
              }
            ]
          }
        '''),
      );

      final prompt = [
        Content.text(
          'My pantry currently has: ${availableIngredients.join(", ")}. Please give me 3 recipes using my pantry items mixed ONLY with the allowed list.',
        ),
      ];

      final response = await model.generateContent(prompt);

      if (response.text != null) {
        String rawText = response.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final Map<String, dynamic> parsedJson = jsonDecode(rawText);
        List<dynamic> recipes = parsedJson["recipes"];

        await Future.wait(
          recipes.map((recipe) async {
            if (recipe["search_term"] != null) {
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
