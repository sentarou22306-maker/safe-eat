import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme_settings.dart';

class OcrResult {
  final String rawText;
  final Set<String> foundAllergens;
  const OcrResult({required this.rawText, required this.foundAllergens});
}

/// モバイル専用：ML Kit でネイティブ OCR
Future<OcrResult> extractAllergensFromImage(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.japanese);
  try {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await recognizer.processImage(inputImage);
    final rawText = recognized.text;
    final foundAllergens = allergenDictionary.keys
        .where((jp) => rawText.contains(jp))
        .toSet();
    return OcrResult(rawText: rawText, foundAllergens: foundAllergens);
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
        final foundAllergens = allergenDictionary.keys
            .where((jp) => rawText.contains(jp))
            .toSet();
        return OcrResult(rawText: rawText, foundAllergens: foundAllergens);
      }
    }
  } catch (_) {}
  return const OcrResult(rawText: '', foundAllergens: {});
}
