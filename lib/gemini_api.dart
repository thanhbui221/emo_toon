import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiAPI {
  final GenerativeModel model;

  GeminiAPI._(this.model);

  static GeminiAPI? _instance;

  static Future<GeminiAPI> initialize() async {
    if (_instance == null) {
      try {
        // Explicitly set the path to the .env file in the lib directory
        const envPath = 'lib/.env';
        print('envPath: $envPath');  // Debugging line to print the path
        await dotenv.load(fileName: envPath);
        print("Environment variables loaded successfully.");
      } catch (e) {
        print("Error loading .env file: $e");
      }

      final String? apiKey = dotenv.env['API_KEY'];
      if (apiKey == null) {
        throw Exception('No API_KEY environment variable found');
      }

      final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);
      _instance = GeminiAPI._(model);
    }
    return _instance!;
  }

  Future<GenerateContentResponse> generateContent(List<Content> history) async {
    final response = await model.generateContent(history);
    return response;
  }
}
