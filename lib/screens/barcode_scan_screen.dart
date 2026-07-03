import 'dart:async' show Future, TimeoutException, unawaited;
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
import '../services/analytics_service.dart';
import '../services/ocr_service.dart' show OcrResult, extractAllergensFromImage, extractAllergensFromImageBytes;

enum ScanMode { fast, accurate }

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  bool isScanned = false;
  bool _isLoading = false;
  ScanMode _scanMode = ScanMode.fast;
  final TextEditingController _janCodeController = TextEditingController();

  Future<void> _searchProduct(String janCode) async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

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
        unawaited(logScanEvent(source: 'db'));
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
          unawaited(logScanEvent(source: 'ofa'));
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
        setState(() => _isLoading = false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => isScanned = false);
        });
      }
    }
  }

  Future<void> _scanWithOcr(String janCode) async {
    if (!mounted) return;
    final confirmed = await showOcrGuideDialog(context);
    if (!confirmed || !mounted) return;

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
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
      unawaited(logScanEvent(source: 'ocr'));
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

  Widget _buildModeToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _modeChip(ScanMode.fast, Icons.bolt_rounded, t('Fast', '高速'), Colors.amber.shade700),
        const SizedBox(width: 4),
        _modeChip(ScanMode.accurate, Icons.verified_user_rounded, t('Accurate', '精度'), Colors.teal),
      ],
    );
  }

  Widget _modeChip(ScanMode mode, IconData icon, String label, Color activeColor) {
    final isActive = _scanMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _scanMode = mode),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              _buildModeToggle(),
              buildGlobalSettingsButton(context),
            ],
          ),
          body: Stack(
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
              // Dim overlay with transparent cutout for the scan zone
              Positioned.fill(
                child: CustomPaint(painter: _ScanOverlayPainter()),
              ),
              // Corner-bracket frame showing where to aim
              Center(
                child: CustomPaint(
                  size: const Size(260, 170),
                  painter: _ScanFramePainter(),
                ),
              ),
              if (_isLoading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x99000000),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Searching... / 検索中...',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
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

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameW = 260.0;
    const frameH = 170.0;
    final left = (size.width - frameW) / 2;
    final top = (size.height - frameH) / 2;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(Rect.fromLTWH(left, top, frameW, frameH))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = const Color(0x99000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - len, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
