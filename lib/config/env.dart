import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get mapboxToken {
    final token = dotenv.env['MAPBOX_TOKEN'];
    if (token == null || token.isEmpty) {
      throw Exception("MAPBOX_TOKEN not found");
    }
    return token;
  }
}
