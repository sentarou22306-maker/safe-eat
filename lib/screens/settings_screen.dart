import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_settings.dart';
import '../services/rate_limit_service.dart';
import '../services/dietary_detector.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Safety tab
  final _customAllergenController = TextEditingController();
  final _customDietaryController = TextEditingController();

  // Profile tab
  bool _analyticsConsent = false;
  String? _ageRange;
  String? _gender;
  final _countryController = TextEditingController();
  int _ocrLimit = 5;

  static const _mandatoryAllergens = [
    '卵', '乳成分', '小麦', 'そば', '落花生', 'えび', 'かに', 'くるみ',
  ];

  static const _otherAllergenCategories = [
    ('🇯🇵 Recommended 21  推奨21品目', [
      'アーモンド', 'あわび', 'いか', 'いくら', 'オレンジ', 'カシューナッツ',
      'キウイフルーツ', '牛肉', 'ごま', 'さけ', 'さば', '大豆', '鶏肉', 'バナナ',
      '豚肉', 'まつたけ', 'もも', 'やまいも', 'りんご', 'ゼラチン', 'マカダミアナッツ',
    ]),
    ('🇪🇺 EU Additions  EU追加', ['セロリ', 'からし', '亜硫酸塩', 'ルパン']),
    ('🌐 Other  その他', ['魚類', 'とうもろこし', '植物油脂']),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _analyticsConsent = prefs.getBool('analytics_consent') ?? false;
        _ageRange = prefs.getString('profile_age_range');
        _gender = prefs.getString('profile_gender');
        _countryController.text = prefs.getString('profile_country') ?? '';
      });
      getDailyOcrLimit().then((limit) {
        if (mounted) setState(() => _ocrLimit = limit);
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customAllergenController.dispose();
    _customDietaryController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final oldLimit = _ocrLimit;
    final limit = await getDailyOcrLimit();
    if (!mounted) return;
    setState(() => _ocrLimit = limit);
    if (limit > oldLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(
            '🎉 Label scan limit increased to $limit / day!',
            '🎉 スキャン上限が$limit回/日になりました！',
            zh: '🎉 扫描上限已提升至每日 $limit 次！',
            ko: '🎉 라벨 스캔 상한이 하루 $limit 회로 늘었습니다！',
          )),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Tab 1: Safety ─────────────────────────────────────────────

  Widget _buildSafetyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─ 食事制限 ────────────────────────────────────────────
        _sectionHeader(
          t('Dietary Preferences', '食事制限', zh: '饮食偏好', ko: '식이 선호'),
          Icons.restaurant_outlined,
        ),
        const SizedBox(height: 4),
        Text(
          t(
            'Select a preset, then remove categories you\'re OK with.',
            'プリセットを選択後、食べられるカテゴリをタップして除外できます。',
            zh: '选择预设，然后点击您可以接受的类别以排除它。',
            ko: '프리셋을 선택한 뒤, 먹을 수 있는 카테고리를 탭하여 제외하세요.',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _buildPresetChips(),
        _buildActivePresetCustomization(),
        _buildCustomDietarySection(),

        const Divider(height: 40, thickness: 1),

        // ─ アレルゲン ───────────────────────────────────────────
        _sectionHeader(
          t('Allergens', 'アレルゲン', zh: '过敏原', ko: '알레르겐'),
          Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 4),
        Text(
          t(
            'Tap to select. You will be warned when a product contains them.',
            'タップして選択してください。商品に含まれる場合に警告が表示されます。',
            zh: '点击选择过敏原，检测到时会发出警告。',
            ko: '탭하여 선택하세요. 제품에 포함된 경우 경고가 표시됩니다.',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Text(
          t('Mandatory 8  義務8品目', '義務表示 8品目', zh: '必标8项', ko: '의무 표시 8품목'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Set<String>>(
          valueListenable: userAllergens,
          builder: (context, selected, _) =>
              _buildMandatoryAllergenChips(selected),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Set<String>>(
          valueListenable: userAllergens,
          builder: (context, selected, _) =>
              _buildOtherAllergenExpansion(selected),
        ),
        const Divider(height: 32, thickness: 1),
        Row(
          children: [
            Icon(Icons.add_circle_outline,
                color: appThemeColor.value, size: 22),
            const SizedBox(width: 8),
            Text(
              t('Custom Allergens', 'カスタムアレルゲン',
                  zh: '自定义过敏原', ko: '맞춤 알레르겐'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t(
            'Add allergens not listed above.',
            'リストにないアレルゲンを追加できます。',
            zh: '添加列表中没有的过敏原。',
            ko: '위 목록에 없는 알레르겐을 추가하세요.',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<Set<String>>(
          valueListenable: customAllergens,
          builder: (context, custom, _) =>
              _buildCustomAllergenSection(custom),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Dietary preset chips ──────────────────────────────────────

  Widget _buildPresetChips() {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: activeDietaryPresets,
      builder: (context, active, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kDietaryPresets.values.map((preset) {
            final isSelected = active.contains(preset.key);
            return FilterChip(
              label: Text(
                '${preset.emoji} ${preset.label(appLanguage.value)}',
                style: const TextStyle(fontSize: 13),
              ),
              selected: isSelected,
              selectedColor: Colors.green.shade100,
              checkmarkColor: Colors.green.shade700,
              side: isSelected
                  ? BorderSide(color: Colors.green.shade400)
                  : BorderSide(color: Colors.grey.shade300),
              labelStyle: TextStyle(
                color: isSelected ? Colors.green.shade800 : Colors.black87,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) async {
                final newSet = Set<String>.from(active);
                if (selected) {
                  newSet.add(preset.key);
                } else {
                  newSet.remove(preset.key);
                  // Clean up removed categories for this preset when deselected
                  final newRemoved =
                      Set<String>.from(removedDietaryCategories.value)
                        ..removeWhere(
                            (e) => e.startsWith('${preset.key}:'));
                  await saveRemovedDietaryCategories(newRemoved);
                }
                await saveActiveDietaryPresets(newSet);
              },
            );
          }).toList(),
        );
      },
    );
  }

  // ── Preset customization (per active preset) ──────────────────

  Widget _buildActivePresetCustomization() {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: activeDietaryPresets,
      builder: (context, active, _) {
        if (active.isEmpty) return const SizedBox.shrink();
        return ValueListenableBuilder<Set<String>>(
          valueListenable: removedDietaryCategories,
          builder: (context, removed, _) {
            return Column(
              children: active.map((key) {
                final preset = kDietaryPresets[key];
                if (preset == null) return const SizedBox.shrink();
                final activeCount = preset.categories
                    .where((c) => !removed.contains('$key:${c.key}'))
                    .length;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      leading: Text(preset.emoji,
                          style: const TextStyle(fontSize: 20)),
                      title: Text(
                        preset.label(appLanguage.value),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        t(
                          '$activeCount categor${activeCount == 1 ? 'y' : 'ies'} active',
                          '$activeCount カテゴリ有効',
                          zh: '$activeCount 个类别有效',
                          ko: '$activeCount 카테고리 활성',
                        ),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.green.shade200),
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.green.shade200),
                      ),
                      backgroundColor: Colors.green.shade50,
                      collapsedBackgroundColor: Colors.green.shade50,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t(
                                  'Tap a category to exclude it (mark as OK for you)',
                                  'カテゴリをタップして除外（自分はOK）',
                                  zh: '点击类别以排除（标记为自己可以接受）',
                                  ko: '카테고리를 탭하여 제외(자신은 OK로 표시)',
                                ),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: preset.categories.map((cat) {
                                  final catId = '$key:${cat.key}';
                                  final isRemoved = removed.contains(catId);
                                  return GestureDetector(
                                    onTap: () async {
                                      final newRemoved =
                                          Set<String>.from(removed);
                                      if (isRemoved) {
                                        newRemoved.remove(catId);
                                      } else {
                                        newRemoved.add(catId);
                                      }
                                      await saveRemovedDietaryCategories(
                                          newRemoved);
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isRemoved
                                            ? Colors.grey.shade100
                                            : Colors.green.shade100,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isRemoved
                                              ? Colors.grey.shade300
                                              : Colors.green.shade400,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(cat.emoji,
                                              style: const TextStyle(
                                                  fontSize: 15)),
                                          const SizedBox(width: 6),
                                          Text(
                                            cat.label(appLanguage.value),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isRemoved
                                                  ? Colors.grey.shade400
                                                  : Colors.green.shade800,
                                              decoration: isRemoved
                                                  ? TextDecoration
                                                      .lineThrough
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            isRemoved
                                                ? Icons.add_circle_outline
                                                : Icons.check_circle,
                                            size: 14,
                                            color: isRemoved
                                                ? Colors.grey.shade400
                                                : Colors.green.shade600,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  // ── Custom dietary keyword additions ──────────────────────────

  Widget _buildCustomDietarySection() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Theme(
        data:
            Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading:
              const Icon(Icons.add_circle_outline, color: Colors.teal),
          title: Text(
            t('Add individual restriction', '個別の成分を追加',
                zh: '添加个别成分限制', ko: '개별 성분 추가'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: ValueListenableBuilder<Set<String>>(
            valueListenable: addedDietaryKeywords,
            builder: (context, added, _) => added.isEmpty
                ? const SizedBox.shrink()
                : Text('${added.length} item(s)',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: addedDietaryKeywords,
                    builder: (context, added, _) {
                      if (added.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: added
                              .map((kw) => Chip(
                                    label: Text(kw,
                                        style: const TextStyle(fontSize: 12)),
                                    backgroundColor: Colors.teal.shade50,
                                    side: BorderSide(
                                        color: Colors.teal.shade200),
                                    deleteIcon: Icon(Icons.close,
                                        size: 14,
                                        color: Colors.teal.shade400),
                                    onDeleted: () async {
                                      final newSet =
                                          Set<String>.from(added)
                                            ..remove(kw);
                                      await saveAddedDietaryKeywords(
                                          newSet);
                                    },
                                  ))
                              .toList(),
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customDietaryController,
                          decoration: InputDecoration(
                            hintText: t(
                              'e.g. 大豆, コーン',
                              '例: 大豆、コーン',
                              zh: '例如：大豆、玉米',
                              ko: '예: 대두, 옥수수',
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _addCustomDietaryKeyword(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addCustomDietaryKeyword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        child: Text(t('Add', '追加', zh: '添加', ko: '추가')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomDietaryKeyword() async {
    final kw = _customDietaryController.text.trim();
    if (kw.isEmpty) return;
    final focusScope = FocusScope.of(context);
    final newSet =
        Set<String>.from(addedDietaryKeywords.value)..add(kw);
    await saveAddedDietaryKeywords(newSet);
    _customDietaryController.clear();
    focusScope.unfocus();
  }

  // ── Allergen chips ────────────────────────────────────────────

  Widget _buildMandatoryAllergenChips(Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _mandatoryAllergens.map((jp) {
        final info = allergenDictionary[jp]!;
        final displayName = info[appLanguage.value] ?? info['en']!;
        final isSelected = selected.contains(jp);
        return FilterChip(
          label: Text(
            '${info['emoji']!} $jp / $displayName',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          selected: isSelected,
          selectedColor: Colors.red.shade100,
          checkmarkColor: Colors.red.shade700,
          side: isSelected
              ? BorderSide(color: Colors.red.shade400, width: 1.5)
              : BorderSide(color: Colors.grey.shade300),
          labelStyle: TextStyle(
            color: isSelected ? Colors.red.shade800 : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
          onSelected: (val) {
            final newSet = Set<String>.from(selected);
            val ? newSet.add(jp) : newSet.remove(jp);
            saveUserAllergens(newSet);
          },
        );
      }).toList(),
    );
  }

  Widget _buildOtherAllergenExpansion(Set<String> selected) {
    final selectedCount = selected
        .where((k) =>
            !_mandatoryAllergens.contains(k) &&
            allergenDictionary.containsKey(k))
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(
            t('More allergens', 'その他のアレルゲン',
                zh: '更多过敏原', ko: '기타 알레르겐'),
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: selectedCount > 0
              ? Text(
                  t('$selectedCount selected', '$selectedCount 個選択中',
                      zh: '已选 $selectedCount 项', ko: '$selectedCount 개 선택됨'),
                  style: TextStyle(
                      fontSize: 11, color: appThemeColor.value),
                )
              : null,
          children: _otherAllergenCategories.map((cat) {
            final (label, keys) = cat;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        )),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: keys.map((jp) {
                      final info = allergenDictionary[jp];
                      if (info == null) return const SizedBox.shrink();
                      final displayName =
                          info[appLanguage.value] ?? info['en']!;
                      final isSelected = selected.contains(jp);
                      return FilterChip(
                        label: Text(
                          '${info['emoji']!} $jp / $displayName',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.green.shade100,
                        checkmarkColor: Colors.green.shade700,
                        side: isSelected
                            ? BorderSide(color: Colors.green.shade400)
                            : BorderSide(color: Colors.grey.shade300),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.green.shade800
                              : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          final newSet = Set<String>.from(selected);
                          val ? newSet.add(jp) : newSet.remove(jp);
                          saveUserAllergens(newSet);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomAllergenSection(Set<String> custom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (custom.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: custom
                .map((name) => Chip(
                      label: Text('⚠️ $name'),
                      backgroundColor: Colors.purple.shade50,
                      side: BorderSide(color: Colors.purple.shade200),
                      deleteIcon: Icon(Icons.close,
                          size: 16, color: Colors.purple.shade400),
                      onDeleted: () => removeCustomAllergen(name),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customAllergenController,
                decoration: InputDecoration(
                  hintText: t(
                    'e.g. Pistachio, Pine nut',
                    '例: ピスタチオ、松の実',
                    zh: '例如：开心果、松仁',
                    ko: '예: 피스타치오, 잣',
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _addCustomAllergen(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addCustomAllergen,
              style: ElevatedButton.styleFrom(
                backgroundColor: appThemeColor.value,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              child: Text(t('Add', '追加', zh: '添加', ko: '추가')),
            ),
          ],
        ),
      ],
    );
  }

  void _addCustomAllergen() {
    final name = _customAllergenController.text.trim();
    if (name.isEmpty) return;
    addCustomAllergen(name);
    _customAllergenController.clear();
    FocusScope.of(context).unfocus();
  }

  // ── Tab 2: Profile ────────────────────────────────────────────

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.document_scanner_outlined,
                  color: Colors.green.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Daily label scan limit', 'ラベルスキャン上限',
                          zh: '每日标签扫描上限', ko: '하루 라벨 스캔 상한'),
                      style: TextStyle(
                          fontSize: 12, color: Colors.green.shade700),
                    ),
                    Text(
                      t('$_ocrLimit scans / day', '$_ocrLimit 回 / 日',
                          zh: '$_ocrLimit 次 / 天', ko: '하루 $_ocrLimit 회'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t(
            'Fill in more attributes to increase your daily label scan limit.',
            '項目を埋めるほどスキャン上限が増えます。',
            zh: '填写越多，每日扫描上限越高。',
            ko: '항목을 더 입력할수록 하루 스캔 상한이 늘어납니다.',
          ),
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Divider(height: 32, thickness: 1),
        Text(t('Age range', '年代', zh: '年龄段', ko: '연령대'),
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildAgeChips(),
        const SizedBox(height: 20),
        Text(t('Gender', '性別', zh: '性别', ko: '성별'),
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildGenderChips(),
        const SizedBox(height: 20),
        Text(t('Country of origin', '出身国', zh: '国籍', ko: '출신 국가'),
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _countryController,
          decoration: InputDecoration(
            hintText: t(
              'e.g. South Korea, France',
              '例: 韓国、フランス',
              zh: '例如：韩国、法国',
              ko: '예: 한국, 프랑스',
            ),
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (val) async {
            final trimmed = val.trim();
            final focusScope = FocusScope.of(context);
            final prefs = await SharedPreferences.getInstance();
            if (trimmed.isNotEmpty) {
              await prefs.setString('profile_country', trimmed);
            } else {
              await prefs.remove('profile_country');
            }
            if (mounted) focusScope.unfocus();
            await _saveProfile();
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildAgeChips() {
    const values = ['10s', '20s', '30s', '40s', '50s', '60s+'];
    const labelsEn = ['10s', '20s', '30s', '40s', '50s', '60s+'];
    const labelsJa = ['10代', '20代', '30代', '40代', '50代', '60代以上'];
    const labelsZh = ['10多岁', '20多岁', '30多岁', '40多岁', '50多岁', '60岁以上'];
    const labelsKo = ['10대', '20대', '30대', '40대', '50대', '60대 이상'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(values.length, (i) {
        final val = values[i];
        final label = switch (appLanguage.value) {
          'ja' => labelsJa[i],
          'zh' => labelsZh[i],
          'ko' => labelsKo[i],
          _ => labelsEn[i],
        };
        final isSelected = _ageRange == val;
        return ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 13)),
          selected: isSelected,
          selectedColor: Colors.green.shade100,
          checkmarkColor: Colors.green.shade700,
          side: isSelected
              ? BorderSide(color: Colors.green.shade400)
              : BorderSide(color: Colors.grey.shade300),
          labelStyle: TextStyle(
            color: isSelected ? Colors.green.shade800 : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (selected) async {
            setState(() => _ageRange = selected ? val : null);
            final prefs = await SharedPreferences.getInstance();
            if (selected) {
              await prefs.setString('profile_age_range', val);
            } else {
              await prefs.remove('profile_age_range');
            }
            await _saveProfile();
          },
        );
      }),
    );
  }

  Widget _buildGenderChips() {
    const values = ['male', 'female', 'other', 'no_answer'];
    const labelsEn = ['Male', 'Female', 'Other', 'Prefer not to say'];
    const labelsJa = ['男性', '女性', 'その他', '回答しない'];
    const labelsZh = ['男', '女', '其他', '不愿透露'];
    const labelsKo = ['남성', '여성', '기타', '비공개'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(values.length, (i) {
        final val = values[i];
        final label = switch (appLanguage.value) {
          'ja' => labelsJa[i],
          'zh' => labelsZh[i],
          'ko' => labelsKo[i],
          _ => labelsEn[i],
        };
        final isSelected = _gender == val;
        return ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 13)),
          selected: isSelected,
          selectedColor: Colors.green.shade100,
          checkmarkColor: Colors.green.shade700,
          side: isSelected
              ? BorderSide(color: Colors.green.shade400)
              : BorderSide(color: Colors.grey.shade300),
          labelStyle: TextStyle(
            color: isSelected ? Colors.green.shade800 : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (selected) async {
            setState(() => _gender = selected ? val : null);
            final prefs = await SharedPreferences.getInstance();
            if (selected) {
              await prefs.setString('profile_gender', val);
            } else {
              await prefs.remove('profile_gender');
            }
            await _saveProfile();
          },
        );
      }),
    );
  }

  // ── Tab 3: Display ────────────────────────────────────────────

  Widget _buildDisplayTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader(t('Language', '言語', zh: '语言', ko: '언어'),
            Icons.language),
        const SizedBox(height: 4),
        ValueListenableBuilder<String>(
          valueListenable: appLanguage,
          builder: (context, lang, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _langButton('English', 'en', lang),
              _langButton('日本語', 'ja', lang),
              _langButton('中文', 'zh', lang),
              _langButton('한국어', 'ko', lang),
            ],
          ),
        ),
        const Divider(height: 40, thickness: 1),
        _sectionHeader(
            t('Text Size', '文字サイズ', zh: '文字大小', ko: '글자 크기'),
            Icons.text_fields),
        ValueListenableBuilder<double>(
          valueListenable: appTextScale,
          builder: (context, scale, _) => Slider(
            value: scale,
            min: 0.8,
            max: 1.5,
            divisions: 7,
            label: 'x${scale.toStringAsFixed(1)}',
            activeColor: appThemeColor.value,
            onChanged: (val) => appTextScale.value = val,
          ),
        ),
        const Divider(height: 40, thickness: 1),
        _sectionHeader(
            t('Theme Color', 'テーマカラー', zh: '主题颜色', ko: '테마 색상'),
            Icons.palette),
        const SizedBox(height: 8),
        ValueListenableBuilder<Color>(
          valueListenable: appThemeColor,
          builder: (context, color, _) => Wrap(
            spacing: 16,
            children: [
              _colorButton(Colors.green, color),
              _colorButton(Colors.blue, color),
              _colorButton(Colors.orange, color),
              _colorButton(Colors.purple, color),
              _colorButton(Colors.pink, color),
              _colorButton(Colors.black87, color),
            ],
          ),
        ),
        const Divider(height: 40, thickness: 1),
        _sectionHeader(
            t('Privacy', 'プライバシー', zh: '隐私', ko: '개인정보'),
            Icons.privacy_tip_outlined),
        SwitchListTile(
          value: _analyticsConsent,
          onChanged: (v) async {
            setState(() => _analyticsConsent = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('analytics_consent', v);
          },
          activeThumbColor: appThemeColor.value,
          title: Text(
            t('Share anonymous scan statistics', '匿名のスキャン統計を共有する',
                zh: '共享匿名扫描统计', ko: '익명 스캔 통계 공유'),
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            t(
              'No personal info included. Helps improve allergen coverage.',
              '個人情報は含まれません。アレルゲン情報の改善に役立てます。',
              zh: '不含个人信息，用于改善过敏原覆盖范围。',
              ko: '개인정보는 포함되지 않습니다. 알레르겐 정보 개선에 활용됩니다.',
            ),
            style: const TextStyle(fontSize: 12),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading:
              const Icon(Icons.article_outlined, color: Colors.grey),
          title: Text(
            t('Privacy Policy', 'プライバシーポリシー',
                zh: '隐私政策', ko: '개인정보 처리방침'),
            style: const TextStyle(fontSize: 14),
          ),
          trailing:
              const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => context.push('/privacy_policy'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.gavel_outlined, color: Colors.grey),
          title: Text(
            t('Terms of Service', '利用規約', zh: '服务条款', ko: '이용약관'),
            style: const TextStyle(fontSize: 14),
          ),
          trailing:
              const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => context.push('/tos'),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: appThemeColor.value, size: 22),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _langButton(String label, String code, String current) {
    final isSelected = current == code;
    return ElevatedButton(
      onPressed: () {
        appLanguage.value = code;
        setState(() {});
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? appThemeColor.value : Colors.grey.shade300,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
      ),
      child: Text(label),
    );
  }

  Widget _colorButton(Color color, Color current) {
    final isSelected = current == color;
    return GestureDetector(
      onTap: () => setState(() => appThemeColor.value = color),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black45 : Colors.transparent,
            width: 3,
          ),
        ),
        child: CircleAvatar(backgroundColor: color, radius: 20),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(t('Settings', '設定', zh: '设置', ko: '설정')),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(
                  icon: const Icon(Icons.shield_outlined),
                  text: t('Safety', '安全設定', zh: '安全', ko: '안전'),
                ),
                Tab(
                  icon: const Icon(Icons.person_outline),
                  text: t('Profile', 'プロフィール', zh: '档案', ko: '프로필'),
                ),
                Tab(
                  icon: const Icon(Icons.tune),
                  text: t('Display', '表示', zh: '显示', ko: '표시'),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: Text(t('Done', '完了', zh: '完成', ko: '완료')),
            backgroundColor: appThemeColor.value,
            foregroundColor: Colors.white,
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSafetyTab(),
              _buildProfileTab(),
              _buildDisplayTab(),
            ],
          ),
        );
      },
    );
  }
}
