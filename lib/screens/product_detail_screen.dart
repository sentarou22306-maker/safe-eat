import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme_settings.dart';
import '../services/ocr_service.dart' show OcrResult, extractAllergensFromImage, extractAllergensFromImageBytes;

// 🌟変更：StatefulWidgetに進化させました！
class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  OcrResult? _ocrResult;
  bool _isOcrRunning = false;

  Future<void> _verifyWithOcr() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;

    setState(() => _isOcrRunning = true);
    try {
      OcrResult result;
      if (kIsWeb) {
        final bytes = await photo.readAsBytes();
        result = await extractAllergensFromImageBytes(bytes);
      } else {
        result = await extractAllergensFromImage(photo.path);
      }
      if (mounted) setState(() => _ocrResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('Could not read image.', '画像の読み取りに失敗しました。'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOcrRunning = false);
    }
  }

  List<Widget> _buildCrossContaminationCard() {
    final allergens = _ocrResult?.crossContaminationAllergens ?? {};
    if (allergens.isEmpty) return [];
    return [
      const SizedBox(height: 8),
      Card(
        color: Colors.orange.shade50,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.factory_outlined, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t(
                        'Made in shared facility with:',
                        '同じ製造環境で以下を扱っています:',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: allergens.map((a) {
                  final info = allergenDictionary[a];
                  return Chip(
                    label: Text(
                      '${info?['emoji'] ?? '⚠️'} $a',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    backgroundColor: Colors.orange.shade100,
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                t(
                  '⚠️ Trace amounts may be present due to shared manufacturing.',
                  '⚠️ 製造工程上、微量混入の可能性があります。',
                ),
                style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildVegetableOilCard() {
    if (_ocrResult?.hasUnspecifiedVegetableOil != true) return [];
    return [
      const SizedBox(height: 8),
      Card(
        color: Colors.yellow.shade50,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🛢️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Vegetable oil detected', '植物油脂が含まれています'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(
                        'The label lists "vegetable oil" without specifying the source. It may contain soy, rapeseed, sesame, or other allergens.',
                        '「植物油脂」と記載されていますが原料が特定されていません。大豆・菜種・ごまなどのアレルゲンを含む可能性があります。',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.yellow.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildOcrVerificationCard(List<String> dbIngredients) {
    final ocrAllergens = _ocrResult!.foundAllergens;

    // DBにデータがない場合：OCR発見結果のみ表示
    if (dbIngredients.isEmpty) {
      return [
        const SizedBox(height: 8),
        Card(
          color: ocrAllergens.isEmpty
              ? Colors.green.shade50
              : Colors.blue.shade50,
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      ocrAllergens.isEmpty
                          ? Icons.check_circle_rounded
                          : Icons.document_scanner_rounded,
                      color: ocrAllergens.isEmpty
                          ? Colors.green
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ocrAllergens.isEmpty
                            ? t(
                                'No allergens detected on label.',
                                'ラベルからアレルゲンは検出されませんでした。',
                              )
                            : t(
                                'Allergens found on label:',
                                'ラベルから検出されたアレルゲン:',
                              ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ocrAllergens.isEmpty
                              ? Colors.green.shade800
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (ocrAllergens.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ocrAllergens.map((a) {
                      final info = allergenDictionary[a];
                      return Chip(
                        label: Text(
                            '${info?['emoji'] ?? '⚠️'} $a (${info?['en'] ?? a})'),
                        backgroundColor: Colors.blue.shade100,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  t(
                    '⚠️ OCR may not detect all text accurately. Always check the actual label.',
                    '⚠️ OCRはすべてのテキストを正確に読み取れない場合があります。必ず実際のラベルをご確認ください。',
                  ),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // DBにデータがある場合：照合結果を表示
    final dbAllergens = allergenDictionary.keys
        .where((key) => dbIngredients.any((i) => i.contains(key)))
        .toSet();
    final onlyInOcr = ocrAllergens.difference(dbAllergens);
    final onlyInDb = dbAllergens.difference(ocrAllergens);
    final isConsistent = onlyInOcr.isEmpty && onlyInDb.isEmpty;

    return [
      const SizedBox(height: 8),
      Card(
        color: isConsistent ? Colors.green.shade50 : Colors.orange.shade50,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isConsistent
                        ? Icons.verified_rounded
                        : Icons.compare_arrows_rounded,
                    color: isConsistent ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isConsistent
                          ? t(
                              'Consistent! Both sources agree.',
                              '一致！データベースとラベルが同じです。',
                            )
                          : t('Discrepancy detected', '不一致が検出されました'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isConsistent
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isConsistent
                    ? t(
                        'The database and the package label show the same allergen information. This information is likely reliable.',
                        'データベースとパッケージ表示のアレルゲン情報が一致しています。この情報は信頼性が高いと考えられます。',
                      )
                    : t(
                        'The package label and database show different allergens. Please read the actual package carefully.',
                        'パッケージ表示とデータベースの情報が異なります。実際のパッケージを注意深くご確認ください。',
                      ),
                style: TextStyle(
                  fontSize: 12,
                  color: isConsistent
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
              if (!isConsistent) ...[
                const SizedBox(height: 8),
                if (onlyInOcr.isNotEmpty)
                  Text(
                    t(
                      'Found on label only: ${onlyInOcr.join(', ')}',
                      'ラベルのみに記載: ${onlyInOcr.join('、')}',
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                if (onlyInDb.isNotEmpty)
                  Text(
                    t(
                      'In database only: ${onlyInDb.join(', ')}',
                      'データベースのみに記載: ${onlyInDb.join('、')}',
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
              const SizedBox(height: 6),
              Text(
                t(
                  '⚠️ OCR may not detect all text accurately.',
                  '⚠️ OCRはすべてのテキストを正確に読み取れない場合があります。',
                ),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  bool _matchesAllergen(String ingredient, String allergenJp) {
    final lower = ingredient.toLowerCase();
    if (lower.contains(allergenJp.toLowerCase())) return true;
    final en = allergenDictionary[allergenJp]?['en']?.toLowerCase() ?? '';
    return en.isNotEmpty && lower.contains(en);
  }

  Map<String, String> _translateIngredient(String jpIngredient) {
    if (allergenDictionary.containsKey(jpIngredient)) {
      return allergenDictionary[jpIngredient]!;
    }
    // OFA生テキストのサブ文字列マッチで辞書エントリを探す
    for (final entry in allergenDictionary.entries) {
      if (jpIngredient.contains(entry.key)) return entry.value;
    }
    return {'en': jpIngredient, 'emoji': '🔍'};
  }

  Widget _buildSafetyBanner(List<String> matched, bool hasAllergenProfile) {
    if (!hasAllergenProfile) return const SizedBox.shrink();
    final isDanger = matched.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDanger ? Colors.red.shade600 : Colors.green.shade600,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isDanger ? Icons.dangerous_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isDanger
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('⚠ DANGER  危険', '⚠ 危険  DANGER'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        matched.join('  '),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Text(
                    t('✓ SAFE — No matched allergens', '✓ 安全 — 登録アレルゲンは含まれていません'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    saveToGlobalHistory(widget.product);
    if (widget.product['_autoVerify'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _verifyWithOcr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // StatefulWidgetの中では「widget.〇〇」でデータを取り出します
    final nameJp = widget.product['name_jp']?.toString() ?? '商品名不明';
    final nameEn = widget.product['name_en']?.toString() ?? '';

    // 🌟 表の画像（image_front）があれば優先し、なければ古い image を使う
    final imageUrl =
        widget.product['image_front']?.toString() ??
        widget.product['image']?.toString() ??
        '';

    final janCode = widget.product['janCode']?.toString() ?? '未登録';

    final List<dynamic> rawIngredients = widget.product['ingredients'] ?? [];
    final ingredients = rawIngredients
        .expand((e) => e.toString().replaceAll('、', ',').split(','))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '商品詳細 / Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [buildGlobalSettingsButton(context)],
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<Set<String>>(
              valueListenable: userAllergens,
              builder: (context, myAllergens, _) {
                final allAllergens = {...myAllergens, ...customAllergens.value};
                if (ingredients.isEmpty) return const SizedBox.shrink();
                final matched = ingredients
                    .where((e) => allAllergens.any((a) => _matchesAllergen(e, a)))
                    .toList();
                return Column(
                  children: [
                    _buildSafetyBanner(matched, allAllergens.isNotEmpty),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
            if (widget.product['_source'] == 'ocr') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t(
                          'This information was extracted from the package image using OCR and may not be 100% accurate. Always verify by reading the actual package label.',
                          'この情報は商品パッケージの画像からOCRで読み取ったものです。正確性を保証しません。必ず実際のパッケージ表示をご確認ください。',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              height: 200,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.broken_image,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                            ),
                          )
                        : const Icon(
                            Icons.image_not_supported,
                            size: 80,
                            color: Colors.grey,
                          ),
                    const SizedBox(height: 16),
                    Text(
                      nameJp,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (nameEn.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          nameEn,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<Set<String>>(
              valueListenable: userAllergens,
              builder: (context, myAllergens, _) {
                final allMyAllergens = {...myAllergens, ...customAllergens.value};
                final matched = ingredients
                    .where((e) => allMyAllergens.any((a) => _matchesAllergen(e, a)))
                    .toList();
                return Column(
                  children: [
                    if (matched.isNotEmpty)
                      Card(
                        color: Colors.red.shade50,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.dangerous_outlined,
                                color: Colors.red,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'WARNING / 警告',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Contains your allergens: ${matched.join(', ')}\nあなたのアレルゲンが含まれています',
                                      style: TextStyle(
                                        color: Colors.red.shade800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (matched.isNotEmpty) const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 28,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'アレルギー情報 / Allergens',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 1),
                            if (ingredients.isEmpty) ...[
                              Text(
                                t(
                                  'No allergen data registered for this product.',
                                  'この商品のアレルゲン情報はまだ登録されていません。',
                                ),
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              if (widget.product['_source'] != 'ocr') ...[
                                ElevatedButton.icon(
                                  onPressed:
                                      _isOcrRunning ? null : _verifyWithOcr,
                                  icon: _isOcrRunning
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.document_scanner_outlined),
                                  label: Text(
                                    t(
                                      'Scan label for allergen info',
                                      'ラベルをスキャンしてアレルゲンを確認する',
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade700,
                                    foregroundColor: Colors.white,
                                    minimumSize:
                                        const Size(double.infinity, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t(
                                    '⚠️ OCR results are for reference only.',
                                    '⚠️ OCR読み取り結果は参考情報です。',
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ] else
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 12.0,
                                children: ingredients.map((jpIngredient) {
                                  final translation = _translateIngredient(
                                    jpIngredient,
                                  );
                                  final enName = translation['en']!;
                                  final emoji = translation['emoji']!;
                                  final isMatch = allMyAllergens
                                      .any((a) => _matchesAllergen(jpIngredient, a));

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMatch
                                          ? Colors.red.shade100
                                          : Colors.orange.shade50,
                                      border: Border.all(
                                        color: isMatch
                                            ? Colors.red.shade400
                                            : Colors.orange.shade200,
                                        width: isMatch ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        isMatch
                                            ? const Icon(
                                                Icons.warning_rounded,
                                                color: Colors.red,
                                                size: 18,
                                              )
                                            : Text(
                                                emoji,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                ),
                                              ),
                                        const SizedBox(width: 8),
                                        Text(
                                          jpIngredient == enName
                                              ? enName
                                              : '$jpIngredient ($enName)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isMatch
                                                ? Colors.red.shade800
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (widget.product['_source'] != 'ocr' &&
                ingredients.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isOcrRunning ? null : _verifyWithOcr,
                icon: _isOcrRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.document_scanner_outlined,
                        color: Colors.teal,
                      ),
                label: Text(
                  t('Verify with package label', 'ラベルで確認する'),
                  style: const TextStyle(color: Colors.teal),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.teal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
            if (_ocrResult != null) ...[
      ..._buildOcrVerificationCard(ingredients),
      ..._buildCrossContaminationCard(),
      ..._buildVegetableOilCard(),
    ],
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.black54,
                ),
                title: const Text(
                  'JANコード / Barcode',
                  style: TextStyle(fontSize: 14),
                ),
                trailing: Text(
                  janCode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push('/allergen_report', extra: janCode),
              icon: const Icon(Icons.flag_outlined, color: Colors.grey),
              label: const Text(
                'Report Allergen Issue / アレルゲン情報を訂正',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'Disclaimer / 免責事項',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'The allergy information provided is for reference only and may not be 100% accurate or up to date. Please ALWAYS check the actual product packaging before consumption.\n\n'
                    '提供されるアレルギー情報は参考用であり、正確性や最新性を保証しません。お召し上がり前に必ず商品パッケージの表示をご確認ください。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
