import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_settings.dart';
import '../services/ocr_service.dart' show OcrResult, extractAllergensFromImage, extractAllergensFromImageBytes;
import '../services/allergen_detector.dart';
import '../services/dietary_detector.dart';
import '../services/rate_limit_service.dart';

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
  bool _hasContributed = false;
  bool _isSubmittingContribution = false;

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

  Future<void> _submitContribution() async {
    final janCode = widget.product['janCode']?.toString() ?? '';
    final allergens = (widget.product['ingredients'] as List?)
        ?.map((e) => e.toString()).toList() ?? [];
    final ingredientText = widget.product['_ocrIngredientText']?.toString() ?? '';
    final preview = ingredientText.length > 200
        ? ingredientText.substring(0, 200)
        : ingredientText;

    setState(() => _isSubmittingContribution = true);
    try {
      await Supabase.instance.client.from('allergen_corrections').insert({
        'jan_code': janCode,
        'allergens': allergens,
        'note': 'Label scan: $preview',
        'submitted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_approved': false,
      });
      if (mounted) setState(() => _hasContributed = true);
      unawaited(refundOcrUse()); // 貢献してくれたらスキャン回数を返金
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('Submission failed. Please try again.',
              '送信に失敗しました。再度お試しください。',
              zh: '提交失败，请重试。',
              ko: '제출에 실패했습니다. 다시 시도해 주세요.')),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingContribution = false);
    }
  }

  Widget _buildContributionCard() {
    final janCode = widget.product['janCode']?.toString() ?? '';
    final ingredientText = widget.product['_ocrIngredientText']?.toString() ?? '';
    if (janCode.isEmpty || janCode == '未登録' || ingredientText.isEmpty) {
      return const SizedBox.shrink();
    }
    final allergenCount = (widget.product['ingredients'] as List?)?.length ?? 0;

    if (_hasContributed) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t('Thank you! Your contribution is under review.',
                    '送信しました。確認後に反映されます。',
                    zh: '感谢您的贡献！审核后将予以反映。',
                    ko: '감사합니다! 검토 후 반영됩니다.'),
                style: TextStyle(color: Colors.green.shade700, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism, color: Colors.teal.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('Help improve the database',
                      'データベース改善に協力する',
                      zh: '帮助改善数据库',
                      ko: '데이터베이스 개선에 기여'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            allergenCount > 0
                ? t(
                    'Your label scan found $allergenCount allergen(s). Submit anonymously to help future travelers.',
                    'ラベルスキャンで$allergenCount種のアレルゲンを検出しました。匿名送信で旅行者を助けましょう。',
                    zh: '您的标签扫描发现了 $allergenCount 种过敏原。匿名提交，帮助未来的旅行者。',
                    ko: '라벨 스캔으로 $allergenCount개의 알레르겐을 발견했습니다. 익명으로 제출하여 미래 여행자를 도와주세요.',
                  )
                : t(
                    'No allergens detected on label. Submit to help future travelers.',
                    'ラベルからアレルゲンは検出されませんでした。送信して旅行者を助けましょう。',
                    zh: '标签上未检测到过敏原。提交以帮助未来的旅行者。',
                    ko: '라벨에서 알레르겐이 검출되지 않았습니다. 제출하여 여행자를 도와주세요.',
                  ),
            style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            t('✦ This scan won\'t count against your daily limit.',
                '✦ 貢献するとこのスキャンは回数にカウントされません。',
                zh: '✦ 贡献后，此次扫描不计入每日限额。',
                ko: '✦ 기여하면 이 스캔은 일일 횟수에 포함되지 않습니다.'),
            style: TextStyle(fontSize: 11, color: Colors.teal.shade600, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isSubmittingContribution ? null : _submitContribution,
            icon: _isSubmittingContribution
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(t('Submit anonymously', '匿名で送信', zh: '匿名提交', ko: '익명으로 제출')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
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
                        ko: '공용 시설에서 함께 제조:',
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
                  ko: '⚠️ 제조 공정상 미량 혼입될 가능성이 있습니다.',
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
                      t('Vegetable oil detected', '植物油脂が含まれています', zh: '检测到植物油', ko: '식물성 유지 검출'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(
                        'The label lists "vegetable oil" without specifying the source. It may contain soy, rapeseed, sesame, or other allergens.',
                        '「植物油脂」と記載されていますが原料が特定されていません。大豆・菜種・ごまなどのアレルゲンを含む可能性があります。',
                        zh: '标签标注"植物油"但未注明来源，可能含有大豆、芥花油、芝麻等过敏原。',
                        ko: '라벨에 "식물성 유지"라고 표시되어 있지만 원료가 명시되지 않았습니다. 대두, 유채, 참깨 등의 알레르겐이 포함될 수 있습니다.',
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
                                ko: '라벨에서 알레르겐이 검출되지 않았습니다.',
                              )
                            : t(
                                'Allergens found on label:',
                                'ラベルから検出されたアレルゲン:',
                                zh: '标签上检测到的过敏原：',
                                ko: '라벨에서 검출된 알레르겐:',
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
                              ko: '일치합니다! 두 출처가 동일합니다.',
                            )
                          : t('Discrepancy detected', '不一致が検出されました', zh: '发现不一致', ko: '불일치 감지'),
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
                        ko: '데이터베이스와 포장 표시의 알레르겐 정보가 일치합니다. 이 정보는 신뢰성이 높습니다.',
                      )
                    : t(
                        'The package label and database show different allergens. Please read the actual package carefully.',
                        'パッケージ表示とデータベースの情報が異なります。実際のパッケージを注意深くご確認ください。',
                        zh: '包装标签与数据库的信息不同，请仔细查看实际包装。',
                        ko: '포장 표시와 데이터베이스 정보가 다릅니다. 실제 포장을 주의 깊게 확인하세요.',
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
                      ko: '라벨에만 있음: ${onlyInOcr.join(', ')}',
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                if (onlyInDb.isNotEmpty)
                  Text(
                    t(
                      'In database only: ${onlyInDb.join(', ')}',
                      'データベースのみに記載: ${onlyInDb.join('、')}',
                      zh: '仅数据库有: ${onlyInDb.join('、')}',
                      ko: '데이터베이스에만 있음: ${onlyInDb.join(', ')}',
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
        ko: '라벨을 성공적으로 읽었습니다. 아래에서 스캔 텍스트를 확인하세요.',
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
        ko: '아래에서 전체 스캔 텍스트를 확인할 수 있습니다.',
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
                  label: Text(t('Retake Photo', '撮り直す', zh: '重新拍摄', ko: '다시 촬영')),
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
                              zh: '查看原材料名栏', ko: '원재료명 섹션 보기')
                          : t('View scanned text', '読み取ったテキストを確認する',
                              zh: '查看扫描文字', ko: '스캔 텍스트 보기'),
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
                        t('Extracted', '抽出済', zh: '已提取', ko: '추출됨'),
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
                      t('Full scanned text', '全文', zh: '完整扫描文字', ko: '전체 스캔 텍스트'),
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
            '⚠️ Label scanning may miss some text. Always check the actual label.',
            '⚠️ ラベルスキャンはすべてのテキストを正確に読み取れない場合があります。必ず実際のラベルをご確認ください。',
            zh: '⚠️ 标签扫描可能无法完全识别所有文字，请务必查看实际标签。',
            ko: '⚠️ 라벨 스캔은 일부 텍스트를 놓칠 수 있습니다. 반드시 실제 라벨을 확인하세요.',
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
          t('Full ingredient list', '原材料一覧', zh: '完整成分表', ko: '전체 원재료 목록'),
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
          t('Verified Database', '認証データベース', zh: '认证数据库', ko: '인증 데이터베이스'),
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
          t('Unknown source', '不明なソース', zh: '未知来源', ko: '알 수 없는 출처'),
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

  String _getIngredientText() {
    // Priority: 1) OCR scan text, 2) raw OFA ingredient text, 3) ingredient/allergen tag list
    if (_ocrResult?.ingredientText.isNotEmpty ?? false) {
      return _ocrResult!.ingredientText;
    }
    final stored = widget.product['_ocrIngredientText']?.toString() ?? '';
    if (stored.isNotEmpty) return stored;
    final ofaRaw = widget.product['_ingredientText']?.toString() ?? '';
    if (ofaRaw.isNotEmpty) return ofaRaw;
    return (widget.product['ingredients'] as List? ?? [])
        .map((e) => e.toString())
        .join(' ');
  }

  Widget _buildDietaryStatusRow(DietaryCheckResult result) {
    final ok = result.ok;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(result.preset.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              result.preset.label(appLanguage.value),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ok ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: ok ? Colors.green.shade300 : Colors.red.shade300),
              ),
              child: Text(
                ok
                    ? t('OK', 'OK', zh: '符合', ko: 'OK')
                    : t('⚠ Not suitable', '⚠ 非対応',
                        zh: '⚠ 不适合', ko: '⚠ 부적합'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: ok ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        if (!ok && result.matches.isNotEmpty) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              result.matches.take(5).join('、'),
              style: TextStyle(fontSize: 11, color: Colors.red.shade700),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDietaryCard() {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: activeDietaryPresets,
      builder: (context, active, _) {
        if (active.isEmpty) return const SizedBox.shrink();
        return ValueListenableBuilder<Set<String>>(
          valueListenable: removedDietaryCategories,
          builder: (context, removed, _) {
            return ValueListenableBuilder<Set<String>>(
              valueListenable: addedDietaryKeywords,
              builder: (context, customKw, _) {
                final text = _getIngredientText();
                final results = checkDietaryPresets(text, active, removed);
                final customMatches = checkCustomKeywords(text, customKw);
                final hasConcern =
                    results.any((r) => !r.ok) || customMatches.isNotEmpty;
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Card(
                      color: hasConcern
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  hasConcern
                                      ? Icons.no_food_outlined
                                      : Icons.check_circle_outline,
                                  color: hasConcern
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t('Dietary Check', '食事制限チェック',
                                      zh: '饮食检查', ko: '식이 확인'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: hasConcern
                                        ? Colors.red.shade800
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...results.asMap().entries.map((e) => Padding(
                                  padding: EdgeInsets.only(
                                      top: e.key > 0 ? 8 : 0),
                                  child: _buildDietaryStatusRow(e.value),
                                )),
                            if (customMatches.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('⚠️',
                                      style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    t('Custom', 'カスタム制限',
                                        zh: '自定义限制',
                                        ko: '맞춤 제한'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.red.shade300),
                                    ),
                                    child: Text(
                                      t('⚠ Found', '⚠ 検出',
                                          zh: '⚠ 已检出',
                                          ko: '⚠ 검출'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 24, top: 3),
                                child: Text(
                                  customMatches.take(5).join('、'),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red.shade700),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              t(
                                'Based on ingredient text. Always verify with the actual label.',
                                '原材料テキストに基づく結果です。必ず実際のラベルを確認してください。',
                                zh: '基于成分文本的结果，请务必核对实际标签。',
                                ko: '성분 텍스트 기반 결과입니다. 반드시 실제 라벨을 확인하세요。',
                              ),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
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
                                      t('WARNING', '警告', zh: '警告', ko: '경고'),
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
                                        ko: '포함 알레르겐: ${matched.map((k) => allergenDictionary[k]?['ko'] ?? k).join(', ')}',
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
                                  t('No allergens detected.', 'アレルゲンは検出されませんでした。', zh: '未检测到已知过敏原。', ko: '알레르겐이 검출되지 않았습니다.'),
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
                  t('Verify with package label', 'ラベルで確認する', zh: '用包装标签验证', ko: '포장 라벨로 확인'),
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
            _buildDietaryCard(),
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
                  t('Barcode (JAN)', 'JANコード', zh: '条形码（JAN）', ko: '바코드 (JAN)'),
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
            if (widget.product['_source'] == 'ocr') ...[
              const SizedBox(height: 12),
              _buildContributionCard(),
            ],
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
