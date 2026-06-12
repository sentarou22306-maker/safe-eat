import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme_settings.dart';

class OcrResult {
  final String rawText;
  final Set<String> foundAllergens;
  const OcrResult({required this.rawText, required this.foundAllergens});
}

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
