import 'dart:convert';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_settings.dart';

class OcrResult {
  final String rawText;
  final String ingredientText; // 原材料名セクションのみ（見つからない場合は全文）
  final Set<String> foundAllergens;
  final Set<String> crossContaminationAllergens;
  final bool hasUnspecifiedVegetableOil;

  const OcrResult({
    required this.rawText,
    required this.ingredientText,
    required this.foundAllergens,
    this.crossContaminationAllergens = const {},
    this.hasUnspecifiedVegetableOil = false,
  });
}

/// 「原材料名：〜」から次のセクションヘッダーまでを切り出す。
/// 見つからなければ全文をそのまま返す。
String extractIngredientSection(String fullText) {
  final headerMatch =
      RegExp(r'原材料名\s*[:：]?\s*').firstMatch(fullText);
  if (headerMatch == null) return fullText;

  final afterHeader = fullText.substring(headerMatch.end);

  // 原材料名の後に現れる一般的なセクションヘッダー
  final nextSection = RegExp(
    r'(内容量|賞味期限|消費期限|保存方法|製造者|製造所|販売者|輸入者|原産国|原産地|栄養成分|アレルギー情報|添加物)',
  );
  final nextMatch = nextSection.firstMatch(afterHeader);
  final extracted = nextMatch == null
      ? afterHeader
      : afterHeader.substring(0, nextMatch.start);
  return extracted.trim().isEmpty ? fullText : extracted.trim();
}

Set<String> _extractAllergens(String ingredientText) {
  final lower = ingredientText.toLowerCase();
  final found = allergenDictionary.entries
      .where((e) =>
          ingredientText.contains(e.key) ||
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
    final ingredientText = extractIngredientSection(rawText);
    return OcrResult(
      rawText: rawText,
      ingredientText: ingredientText,
      foundAllergens: _extractAllergens(ingredientText),
      crossContaminationAllergens: _extractCrossContamination(rawText),
      hasUnspecifiedVegetableOil: _detectUnspecifiedOil(rawText),
    );
  } finally {
    await recognizer.close();
  }
}

/// ウェブ専用：Supabase Edge Function 経由で Google Cloud Vision を呼び出す
Future<OcrResult> extractAllergensFromImageBytes(Uint8List imageBytes) async {
  final base64Image = base64Encode(imageBytes);
  try {
    final response = await Supabase.instance.client.functions.invoke(
      'ocr',
      body: {'imageBase64': base64Image},
    );
    if (response.status == 200) {
      final data = response.data as Map<String, dynamic>;
      final responses = data['responses'] as List?;
      if (responses != null && responses.isNotEmpty) {
        final rawText =
            (responses[0]['fullTextAnnotation']?['text'] ??
                responses[0]['textAnnotations']?[0]?['description'] ??
                '') as String;
        final ingredientText = extractIngredientSection(rawText);
        return OcrResult(
          rawText: rawText,
          ingredientText: ingredientText,
          foundAllergens: _extractAllergens(ingredientText),
          crossContaminationAllergens: _extractCrossContamination(rawText),
          hasUnspecifiedVegetableOil: _detectUnspecifiedOil(rawText),
        );
      }
    }
  } catch (_) {}
  return const OcrResult(rawText: '', ingredientText: '', foundAllergens: {});
}
