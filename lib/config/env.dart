import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get googleApiKey {
    final token = dotenv.env['googleApiKey'];
    if (token == null || token.isEmpty) {
      throw Exception("googleApiKey not found");
    }
    return token;
  }

  static String get clientID {
    final token = dotenv.env['clientID'];
    if (token == null || token.isEmpty) {
      throw Exception("clientID not found");
    }
    return token;
  }
}
