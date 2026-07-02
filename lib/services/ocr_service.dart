import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme_settings.dart';

class OcrResult {
  final String rawText;
  final Set<String> foundAllergens;
  final Set<String> crossContaminationAllergens;
  final bool hasUnspecifiedVegetableOil;

  const OcrResult({
    required this.rawText,
    required this.foundAllergens,
    this.crossContaminationAllergens = const {},
    this.hasUnspecifiedVegetableOil = false,
  });
}

Set<String> _extractAllergens(String text) {
  final lower = text.toLowerCase();
  final found = allergenDictionary.entries
      .where((e) =>
          text.contains(e.key) ||
          lower.contains(e.value['en']!.toLowerCase()))
      .map((e) => e.key)
      .toSet();
  for (final custom in customAllergens.value) {
    if (lower.contains(custom.toLowerCase())) found.add(custom);
  }
  return found;
}

Set<String> _extractCrossContamination(String text) {
  final result = <String>{};
  final sentences = text.split(RegExp(r'[。\n]'));
  for (final sentence in sentences) {
    final hasCross = crossContaminationPhrases.any(sentence.contains);
    if (hasCross) {
      for (final jp in allergenDictionary.keys) {
        if (sentence.contains(jp)) result.add(jp);
      }
    }
  }
  return result;
}

bool _detectUnspecifiedOil(String text) =>
    vegetableOilKeywords.any(text.contains);

/// モバイル専用：ML Kit でネイティブ OCR
Future<OcrResult> extractAllergensFromImage(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.japanese);
  try {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await recognizer.processImage(inputImage);
    final rawText = recognized.text;
    return OcrResult(
      rawText: rawText,
      foundAllergens: _extractAllergens(rawText),
      crossContaminationAllergens: _extractCrossContamination(rawText),
      hasUnspecifiedVegetableOil: _detectUnspecifiedOil(rawText),
    );
  } finally {
    await recognizer.close();
  }
}

/// ウェブ専用：Google Cloud Vision API（日本語・英語対応）
Future<OcrResult> extractAllergensFromImageBytes(Uint8List imageBytes) async {
  final apiKey = dotenv.env['GOOGLE_VISION_API_KEY'] ?? '';
  final base64Image = base64Encode(imageBytes);
  try {
    final response = await http
        .post(
          Uri.parse(
            'https://vision.googleapis.com/v1/images:annotate?key=$apiKey',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requests': [
              {
                'image': {'content': base64Image},
                'features': [
                  {'type': 'DOCUMENT_TEXT_DETECTION'},
                ],
                'imageContext': {
                  'languageHints': ['ja', 'en'],
                },
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final responses = data['responses'] as List?;
      if (responses != null && responses.isNotEmpty) {
        final rawText =
            (responses[0]['fullTextAnnotation']?['text'] ??
                responses[0]['textAnnotations']?[0]?['description'] ??
                '') as String;
        return OcrResult(
          rawText: rawText,
          foundAllergens: _extractAllergens(rawText),
          crossContaminationAllergens: _extractCrossContamination(rawText),
          hasUnspecifiedVegetableOil: _detectUnspecifiedOil(rawText),
        );
      }
    }
  } catch (_) {}
  return const OcrResult(rawText: '', foundAllergens: {});
}
