import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme_settings.dart';
import '../services/ocr_service.dart' show OcrResult, extractAllergensFromImage, extractAllergensFromImageBytes;
import '../services/allergen_detector.dart';

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
  bool _showRawText = false;

  Future<void> _verifyWithOcr() async {
    final confirmed = await showOcrGuideDialog(context);
    if (!confirmed || !mounted) return;

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
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
              t('Could not read image.', '画像の読み取りに失敗しました。', zh: '图像读取失败。'),
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
                        zh: '该产品在共用设施中与以下物质共同生产：',
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
                  zh: '⚠️ 由于共用生产设备，可能含有微量成分。',
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
                      t('Vegetable oil detected', '植物油脂が含まれています', zh: '检测到植物油'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(
                        'The label lists "vegetable oil" without specifying the source. It may contain soy, rapeseed, sesame, or other allergens.',
                        '「植物油脂」と記載されていますが原料が特定されていません。大豆・菜種・ごまなどのアレルゲンを含む可能性があります。',
                        zh: '标签标注"植物油"但未注明来源，可能含有大豆、芥花油、芝麻等过敏原。',
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
                                zh: '标签上未检测到过敏原。',
                              )
                            : t(
                                'Allergens found on label:',
                                'ラベルから検出されたアレルゲン:',
                                zh: '标签上检测到的过敏原：',
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
                    '⚠️ Label scanning may miss some text. Always check the actual label.',
                    '⚠️ ラベルスキャンはすべてのテキストを正確に読み取れない場合があります。必ず実際のラベルをご確認ください。',
                    zh: '⚠️ 标签扫描可能无法完全识别所有文字，请务必查看实际标签。',
                    ko: '⚠️ 라벨 스캔은 일부 텍스트를 놓칠 수 있습니다. 반드시 실제 라벨을 확인하세요.',
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
                              zh: '一致！两个来源信息相同。',
                            )
                          : t('Discrepancy detected', '不一致が検出されました', zh: '发现不一致'),
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
                        zh: '数据库与包装标签显示的过敏原信息相同，可信度较高。',
                      )
                    : t(
                        'The package label and database show different allergens. Please read the actual package carefully.',
                        'パッケージ表示とデータベースの情報が異なります。実際のパッケージを注意深くご確認ください。',
                        zh: '包装标签与数据库的信息不同，请仔细查看实际包装。',
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
                      zh: '仅标签上有: ${onlyInOcr.join('、')}',
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                if (onlyInDb.isNotEmpty)
                  Text(
                    t(
                      'In database only: ${onlyInDb.join(', ')}',
                      'データベースのみに記載: ${onlyInDb.join('、')}',
                      zh: '仅数据库有: ${onlyInDb.join('、')}',
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
              const SizedBox(height: 6),
              Text(
                t(
                  '⚠️ Label scanning may miss some text.',
                  '⚠️ ラベルスキャンはすべてのテキストを正確に読み取れない場合があります。',
                  zh: '⚠️ 标签扫描可能无法完全识别所有文字。',
                  ko: '⚠️ 라벨 스캔은 일부 텍스트를 놓칠 수 있습니다.',
                ),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildOcrSourceSection() {
    final rawText = widget.product['_ocrRawText']?.toString() ?? '';
    final ingredientText =
        widget.product['_ocrIngredientText']?.toString() ?? rawText;
    final sectionExtracted = ingredientText.isNotEmpty && ingredientText != rawText;
    final ingredients = widget.product['ingredients'] as List? ?? [];
    final hasText = rawText.trim().isNotEmpty;
    final hasAllergens = ingredients.isNotEmpty;

    Color cardColor;
    Color borderColor;
    IconData icon;
    Color iconColor;
    String headline;
    String subtext;

    if (!hasText) {
      cardColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade300;
      icon = Icons.camera_alt_outlined;
      iconColor = Colors.grey.shade600;
      headline = t('Could not read any text', 'テキストを読み取れませんでした', zh: '无法读取任何文字', ko: '텍스트를 읽을 수 없었습니다');
      subtext = t(
        'Hold the camera still, ensure good lighting, and aim directly at the ingredient list.',
        'カメラをしっかり固定し、明るい場所で原材料表示の部分を真正面から撮影してください。',
        zh: '请保持相机稳定，在光线充足的环境下，正对成分表进行拍摄。',
        ko: '카메라를 안정적으로 잡고 밝은 곳에서 성분표를 정면으로 촬영해 주세요.',
      );
    } else if (!hasAllergens) {
      cardColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      icon = Icons.check_circle_outline_rounded;
      iconColor = Colors.green.shade700;
      headline = t(
        'No allergens from your profile detected',
        'あなたのアレルゲンは検出されませんでした',
        zh: '未检测到您档案中的过敏原',
        ko: '프로필의 알레르겐이 검출되지 않았습니다',
      );
      subtext = t(
        'The label was read successfully. Tap below to verify the scanned text matches the ingredient list.',
        'ラベルの読み取りに成功しました。以下で読み取ったテキストを確認してください。',
        zh: '标签读取成功。点击下方查看扫描文字是否与成分表一致。',
      );
    } else {
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.red.shade700;
      headline = t('Allergens detected on label', 'ラベルからアレルゲンを検出しました', zh: '标签上检测到过敏原', ko: '라벨에서 알레르겐이 검출되었습니다');
      subtext = t(
        'Tap below to verify the full scanned text.',
        '以下で読み取ったテキスト全文を確認できます。',
        zh: '点击下方查看完整扫描文字。',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtext,
                          style: TextStyle(
                            fontSize: 12,
                            color: iconColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Re-scan button when OCR failed
              if (!hasText) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isOcrRunning ? null : _verifyWithOcr,
                  icon: _isOcrRunning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(t('Retake Photo', '撮り直す', zh: '重新拍摄')),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Text accordion (only when OCR read something)
        if (hasText) ...[
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _showRawText = !_showRawText),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.text_snippet_outlined,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sectionExtracted
                          ? t('View ingredients section', '原材料名セクションを確認する',
                              zh: '查看原材料名栏')
                          : t('View scanned text', '読み取ったテキストを確認する',
                              zh: '查看扫描文字'),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                  if (sectionExtracted)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t('Extracted', '抽出済', zh: '已提取'),
                        style: TextStyle(
                            fontSize: 10, color: Colors.green.shade800),
                      ),
                    ),
                  Icon(
                    _showRawText ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
          if (_showRawText) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredientText,
                    style: const TextStyle(fontSize: 12, height: 1.7),
                  ),
                  if (sectionExtracted) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    Text(
                      t('Full scanned text', '全文', zh: '完整扫描文字'),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rawText,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.6,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 4),
        Text(
          t(
            '⚠️ OCR may not detect all text accurately. Always check the actual label.',
            '⚠️ OCRはすべてのテキストを正確に読み取れない場合があります。必ず実際のラベルをご確認ください。',
            zh: '⚠️ OCR识别结果可能不完全准确，请务必查看实际标签。',
          ),
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildRawIngredientsAccordion(List<String> ingredients) {
    final rawText = ingredients.join(', ');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          t('Full ingredient list', '原材料一覧', zh: '完整成分表'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(rawText,
                style: const TextStyle(fontSize: 12, height: 1.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge() {
    final source = widget.product['_source']?.toString();
    if (source == 'ocr') return const SizedBox.shrink(); // OCR has its own section

    final (icon, label, bg, fg) = switch (source) {
      'db' => (
          Icons.verified_rounded,
          t('Verified Database', '認証データベース', zh: '认证数据库'),
          Colors.green.shade50,
          Colors.green.shade700,
        ),
      'ofa' => (
          Icons.public_rounded,
          'Open Food Facts',
          Colors.blue.shade50,
          Colors.blue.shade700,
        ),
      _ => (
          Icons.help_outline_rounded,
          t('Unknown source', '不明なソース', zh: '未知来源'),
          Colors.grey.shade100,
          Colors.grey.shade600,
        ),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyBanner(List<String> matched, bool hasAllergenProfile) {
    if (!hasAllergenProfile) {
      return GestureDetector(
        onTap: () => context.push('/settings'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.person_add_outlined, color: Colors.grey.shade600, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t(
                    'Register allergens to see if this product is safe for you.',
                    'アレルゲンを登録すると、この商品の安全判定ができます。',
                    zh: '注册过敏原，即可查看该商品是否适合您。',
                    ko: '알레르겐을 등록하면 이 제품이 안전한지 확인할 수 있습니다.',
                  ),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      );
    }

    final isDanger = matched.isNotEmpty;
    final semanticLabel = isDanger
        ? 'DANGER: This product contains allergens you are allergic to: ${matched.map((k) => allergenDictionary[k]?['en'] ?? k).join(', ')}'
        : 'SAFE: No allergens from your profile detected in this product';
    return Semantics(
      label: semanticLabel,
      child: Container(
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
                        t('⚠ DANGER  危険', '⚠ 危険  DANGER', zh: '⚠ 危险  DANGER', ko: '⚠ 위험  DANGER'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        matched.map((k) {
                          if (appLanguage.value == 'ja') return k;
                          return allergenDictionary[k]?[appLanguage.value] ??
                              allergenDictionary[k]?['en'] ?? k;
                        }).join('  '),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Text(
                    t('✓ SAFE — No matched allergens', '✓ 安全 — 登録アレルゲンは含まれていません', zh: '✓ 安全 — 未检测到过敏原', ko: '✓ 안전 — 등록된 알레르겐 미검출'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
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

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          t('Details', '商品詳細', zh: '商品详情', ko: '상품 상세'),
          style: const TextStyle(fontWeight: FontWeight.bold),
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
                final allergenKeys = extractAllergenKeys(ingredients);
                final matched = allergenKeys
                    .where((k) => allAllergens.contains(k))
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
              _buildOcrSourceSection(),
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
            const SizedBox(height: 8),
            _buildSourceBadge(),
            const SizedBox(height: 8),
            ValueListenableBuilder<Set<String>>(
              valueListenable: userAllergens,
              builder: (context, myAllergens, _) {
                final allMyAllergens = {...myAllergens, ...customAllergens.value};
                final allergenKeys = extractAllergenKeys(ingredients);
                final matched = allergenKeys
                    .where((k) => allMyAllergens.contains(k))
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
                                    Text(
                                      t('WARNING', '警告', zh: '警告'),
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t(
                                        'Contains: ${matched.map((k) => allergenDictionary[k]?['en'] ?? k).join(', ')}',
                                        '含有アレルゲン: ${matched.join('、')}',
                                        zh: '含有过敏原: ${matched.map((k) => allergenDictionary[k]?['zh'] ?? k).join('、')}',
                                      ),
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
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t('Allergens', 'アレルギー情報', zh: '过敏原信息', ko: '알레르겐 정보'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 1),
                            if (ingredients.isEmpty) ...[
                              // OCR source: status is shown above in _buildOcrSourceSection
                              if (widget.product['_source'] != 'ocr') ...[
                                Text(
                                  t(
                                    'No allergen data registered for this product.',
                                    'この商品のアレルゲン情報はまだ登録されていません。',
                                    zh: '该商品暂无过敏原数据。',
                                    ko: '이 제품의 알레르겐 정보가 아직 등록되어 있지 않습니다.',
                                  ),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
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
                                      zh: '扫描标签获取过敏原信息',
                                      ko: '라벨을 스캔하여 알레르겐 확인',
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
                                    '⚠️ Label scan results are for reference only.',
                                    '⚠️ ラベルスキャン結果は参考情報です。',
                                    zh: '⚠️ 标签扫描结果仅供参考。',
                                    ko: '⚠️ 라벨 스캔 결과는 참고 정보입니다.',
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ] else ...[
                              if (allergenKeys.isEmpty)
                                Text(
                                  t('No allergens detected.', 'アレルゲンは検出されませんでした。', zh: '未检测到已知过敏原。'),
                                  style: const TextStyle(color: Colors.grey),
                                )
                              else
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 12.0,
                                  children: allergenKeys.map((allergenKey) {
                                    final info = allergenDictionary[allergenKey]!;
                                    final displayName = appLanguage.value == 'ja'
                                        ? allergenKey
                                        : (info[appLanguage.value] ?? info['en']!);
                                    final emoji = info['emoji']!;
                                    final isMatch = allMyAllergens.contains(allergenKey);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
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
                                              ? const Icon(Icons.warning_rounded,
                                                  color: Colors.red, size: 18)
                                              : Text(emoji,
                                                  style: const TextStyle(fontSize: 18)),
                                          const SizedBox(width: 8),
                                          Text(
                                            appLanguage.value == 'ja'
                                                ? allergenKey
                                                : '$allergenKey / $displayName',
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
                              if (widget.product['_source'] == 'ofa') ...[
                                const SizedBox(height: 8),
                                _buildRawIngredientsAccordion(ingredients),
                              ],
                            ],
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
                  t('Verify with package label', 'ラベルで確認する', zh: '用包装标签验证'),
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
                title: Text(
                  t('Barcode (JAN)', 'JANコード', zh: '条形码（JAN）'),
                  style: const TextStyle(fontSize: 14),
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
              label: Text(
                t('Report Allergen Issue', 'アレルゲン情報を訂正',
                    zh: '纠正过敏原信息', ko: '알레르겐 정보 수정'),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        t('Disclaimer', '免責事項', zh: '免责声明', ko: '면책사항'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'The allergy information provided is for reference only and may not be 100% accurate or up to date. Please ALWAYS check the actual product packaging before consumption.',
                      '提供されるアレルギー情報は参考用であり、正確性や最新性を保証しません。お召し上がり前に必ず商品パッケージの表示をご確認ください。',
                      zh: '所提供的过敏原信息仅供参考，不保证100%准确或最新。食用前请务必确认实际商品包装上的标注。',
                      ko: '제공되는 알레르기 정보는 참고용이며 100% 정확하거나 최신임을 보장하지 않습니다. 드시기 전에 반드시 실제 상품 포장의 표시를 확인하세요.',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
    );
  }
}
