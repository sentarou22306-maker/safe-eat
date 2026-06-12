import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../theme_settings.dart';
import '../services/ocr_service.dart' show OcrResult, extractAllergensFromImage, extractAllergensFromImageBytes;

enum ScanMode { fast, accurate, register }

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  bool isScanned = false;
  ScanMode? _scanMode;
  final TextEditingController _janCodeController = TextEditingController();

  Future<void> _searchProduct(String janCode) async {
    FocusScope.of(context).unfocus();

    // 登録モード：DBを検索せずアレルゲン報告画面へ直行
    if (_scanMode == ScanMode.register) {
      if (!mounted) return;
      await context.push('/allergen_report', extra: janCode);
      if (mounted) setState(() => isScanned = false);
      return;
    }

    try {
      // products と allergen_corrections を並列取得
      final supabase = Supabase.instance.client;
      Map<String, dynamic>? productRow;
      Map<String, dynamic>? correctionRow;
      try {
        final results = await Future.wait<Map<String, dynamic>?>([
          supabase
              .from('products')
              .select()
              .eq('jan_code', janCode)
              .eq('is_approved', true)
              .maybeSingle(),
          supabase
              .from('allergen_corrections')
              .select()
              .eq('jan_code', janCode)
              .eq('is_approved', true)
              .maybeSingle(),
        ]);
        productRow = results[0];
        correctionRow = results[1];
      } catch (_) {
        // Supabase 接続失敗時は OFA にフォールバック
      }

      if (!mounted) return;

      // 承認済み訂正データがあればアレルゲンリストを上書き
      final List<String>? correctedAllergens = correctionRow != null
          ? List<String>.from(correctionRow['allergens'] ?? [])
          : null;

      if (productRow != null) {
        final productData = <String, dynamic>{
          'janCode': productRow['jan_code'],
          'name_jp': productRow['name_jp'] ?? '',
          'name_en': productRow['name_en'] ?? '',
          'image_front': productRow['image_url'] ?? '',
          'ingredients': correctedAllergens ??
              List<String>.from(productRow['allergens'] ?? []),
        };
        if (_scanMode == ScanMode.accurate) {
          productData['_autoVerify'] = true;
        }
        await context.push('/product_detail', extra: productData);
        return;
      }

      // OFA API にフォールバック
      final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$janCode.json',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['status'] == 1 && data['product'] != null) {
          final p = data['product'] as Map<String, dynamic>;
          final String rawIngredients =
              p['ingredients_text_ja']?.toString() ??
              p['ingredients_text']?.toString() ??
              '';
          final String cleanIngredients = rawIngredients.replaceAll('、', ',');

          final Map<String, dynamic> apiProduct = {
            'janCode': janCode,
            'name_jp':
                p['product_name_ja']?.toString() ??
                p['product_name']?.toString() ??
                'Unknown Product',
            'name_en': p['product_name_en']?.toString() ?? '',
            'image': p['image_url']?.toString() ?? '',
            'ingredients': correctedAllergens ??
                (cleanIngredients.isNotEmpty ? [cleanIngredients] : []),
            if (_scanMode == ScanMode.accurate) '_autoVerify': true,
          };

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t('Loaded from global database.', '外部データから取得しました。'),
              ),
            ),
          );
          await context.push('/product_detail', extra: apiProduct);
          return;
        }
      }

      if (!mounted) return;

      // 見つからない場合：自動でOCRへ移行
      _showSnackBar(
        t(
          'Not in database. Scanning package label...',
          'データベースにありません。ラベルをスキャンします...',
        ),
      );
      await _scanWithOcr(janCode);
    } on TimeoutException {
      _showSnackBar(
        t('Connection timeout. Please check your network.', '通信がタイムアウトしました。'),
      );
    } on SocketException {
      _showSnackBar(t('No internet connection.', 'ネットワークに接続できません。'));
    } catch (e) {
      _showSnackBar(e.toString());
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => isScanned = false);
        });
      }
    }
  }

  Future<void> _scanWithOcr(String janCode) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;

    _showSnackBar(t('Reading text from image...', '画像からテキストを読み取り中...'));
    try {
      OcrResult result;
      if (kIsWeb) {
        final bytes = await photo.readAsBytes();
        result = await extractAllergensFromImageBytes(bytes);
      } else {
        result = await extractAllergensFromImage(photo.path);
      }
      if (!mounted) return;
      await context.push('/product_detail', extra: {
        'janCode': janCode,
        'name_jp': t('(OCR Scan Result)', '（OCR読み取り結果）'),
        'name_en': '(OCR Scan Result)',
        'ingredients': result.foundAllergens.toList(),
        '_source': 'ocr',
        '_ocrRawText': result.rawText,
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          t('Could not read image text.', '画像テキストの読み取りに失敗しました。'),
        );
      }
    }
  }

  Widget _buildModeSelectionBody() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('Choose Scan Mode', 'スキャンモードを選択'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'Select how you want to scan.',
                '商品のスキャン方法を選んでください。',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () => setState(() => _scanMode = ScanMode.fast),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: Colors.amber.shade800,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('Fast Mode', '最速モード'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t(
                                'JAN code only. Auto-scans label if not found.',
                                'JANコードのみ。未登録の場合は自動でラベルをスキャン。',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _scanMode = ScanMode.accurate),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.teal,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('Accurate Mode', '精度重視モード'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t(
                                'JAN code + label scan. Cross-verifies for higher reliability.',
                                'JANコード＋ラベルをスキャン。照合して信頼性を高めます。',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _scanMode = ScanMode.register),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.edit_document,
                          color: Colors.blue.shade700,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('Registration Mode', '登録モード'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t(
                                'Scan barcode to report allergen info directly.',
                                'バーコードをスキャンしてアレルゲン情報を直接報告。',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _janCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 スキャン画面にも言語を監視するカメラを追加！
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              t('Scan Barcode', 'バーコードをスキャン'),
              style: const TextStyle(fontSize: 18),
            ),
            actions: [
              if (_scanMode != null) ...[
                GestureDetector(
                  onTap: () => setState(() {
                    _scanMode = null;
                    isScanned = false;
                  }),
                  child: Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _scanMode == ScanMode.fast
                          ? Colors.amber.shade700
                          : _scanMode == ScanMode.accurate
                              ? Colors.teal
                              : Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _scanMode == ScanMode.fast
                              ? Icons.bolt_rounded
                              : _scanMode == ScanMode.accurate
                                  ? Icons.verified_user_rounded
                                  : Icons.edit_document,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _scanMode == ScanMode.fast
                              ? t('Fast', '最速')
                              : _scanMode == ScanMode.accurate
                                  ? t('Accurate', '精度')
                                  : t('Register', '登録'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.bug_report,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                  onPressed: () {
                    if (!isScanned) {
                      setState(() => isScanned = true);
                      _searchProduct('4902443526917');
                    }
                  },
                ),
              ],
              buildGlobalSettingsButton(context),
            ],
          ),
          body: _scanMode == null
              ? _buildModeSelectionBody()
              : Stack(
                  children: [
              MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && !isScanned) {
                    final String code = barcodes.first.rawValue ?? '';
                    if (code.isNotEmpty) {
                      setState(() => isScanned = true);
                      _searchProduct(code);
                    }
                  }
                },
              ),
              Positioned(
                bottom: 40,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t(
                            'Manual Input (If camera fails)',
                            '手動入力（カメラが使えない場合）',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _janCodeController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: t(
                                    'Enter Barcode (JAN)',
                                    'JANコードを入力',
                                  ),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final code = _janCodeController.text.trim();
                                if (code.isNotEmpty && !isScanned) {
                                  setState(() => isScanned = true);
                                  _searchProduct(code);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appThemeColor.value,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                t('Search', '検索'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                  ],
                ),
        );
      },
    );
  }
}
