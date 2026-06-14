import 'dart:convert';
import 'dart:typed_data';
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

Set<String> _extractAllergens(String text) =>
    allergenDictionary.keys.where((jp) => text.contains(jp)).toSet();

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

/// ウェブ専用：OCR.space API（日本語対応）
Future<OcrResult> extractAllergensFromImageBytes(Uint8List imageBytes) async {
  final base64Image = base64Encode(imageBytes);
  try {
    final response = await http
        .post(
          Uri.parse('https://api.ocr.space/parse/image'),
          headers: {'apikey': 'helloworld'},
          body: {
            'base64Image': 'data:image/jpeg;base64,$base64Image',
            'language': 'jpn',
            'isOverlayRequired': 'false',
            'detectOrientation': 'true',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final parsedResults = data['ParsedResults'] as List?;
      if (parsedResults != null && parsedResults.isNotEmpty) {
        final rawText = parsedResults[0]['ParsedText']?.toString() ?? '';
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
