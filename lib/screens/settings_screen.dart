import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_settings.dart';
import '../services/rate_limit_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _customController = TextEditingController();
  final _countryController = TextEditingController();
  bool _analyticsConsent = false;
  String? _ageRange;
  String? _gender;
  int _ocrLimit = 5;

  @override
  void initState() {
    super.initState();
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
    _customController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _addCustomAllergen() {
    final name = _customController.text.trim();
    if (name.isEmpty) return;
    addCustomAllergen(name);
    _customController.clear();
    FocusScope.of(context).unfocus();
  }

  static const _categories = [
    ('🇯🇵 Mandatory 8  義務8品目', ['卵', '乳成分', '小麦', 'そば', '落花生', 'えび', 'かに', 'くるみ']),
    ('🇯🇵 Recommended 21  推奨21品目', ['アーモンド', 'あわび', 'いか', 'いくら', 'オレンジ', 'カシューナッツ', 'キウイフルーツ', '牛肉', 'ごま', 'さけ', 'さば', '大豆', '鶏肉', 'バナナ', '豚肉', 'まつたけ', 'もも', 'やまいも', 'りんご', 'ゼラチン', 'マカダミアナッツ']),
    ('🇪🇺 EU Additions  EU追加', ['セロリ', 'からし', '亜硫酸塩', 'ルパン']),
    ('🌐 Other  その他', ['魚類', 'とうもろこし', '植物油脂']),
  ];

  Widget _buildAllergenChips(Set<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _categories.map((cat) {
        final (label, keys) = cat;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keys.map((jp) {
                final info = allergenDictionary[jp];
                if (info == null) return const SizedBox.shrink();
                final displayName = info[appLanguage.value] ?? info['en']!;
                final emoji = info['emoji']!;
                final isSelected = selected.contains(jp);
                return FilterChip(
                  label: Text(
                    '$emoji $jp / $displayName',
                    style: const TextStyle(fontSize: 12),
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
                  onSelected: (val) {
                    final newSet = Set<String>.from(selected);
                    if (val) {
                      newSet.add(jp);
                    } else {
                      newSet.remove(jp);
                    }
                    saveUserAllergens(newSet);
                  },
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
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
            '🎉 OCR limit increased to $limit scans/day!',
            '🎉 OCR上限が$limit回/日になりました！',
            zh: '🎉 OCR上限已提升至每日 $limit 次！',
          )),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildAgeChips() {
    const values = ['10s', '20s', '30s', '40s', '50s', '60s+'];
    const labelsEn = ['10s', '20s', '30s', '40s', '50s', '60s+'];
    const labelsJa = ['10代', '20代', '30代', '40代', '50代', '60代以上'];
    const labelsZh = ['10多岁', '20多岁', '30多岁', '40多岁', '50多岁', '60岁以上'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(values.length, (i) {
        final val = values[i];
        final label = switch (appLanguage.value) {
          'ja' => labelsJa[i],
          'zh' => labelsZh[i],
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(values.length, (i) {
        final val = values[i];
        final label = switch (appLanguage.value) {
          'ja' => labelsJa[i],
          'zh' => labelsZh[i],
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

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: appThemeColor.value, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
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
            title: Text(t('Settings', '設定', zh: '设置')),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: Text(t('Done', '完了', zh: '完成')),
            backgroundColor: appThemeColor.value,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── My Allergens ──────────────────────────────────
              _sectionHeader(
                t('My Allergens', 'マイアレルゲン', zh: '我的过敏原'),
                Icons.warning_amber_rounded,
              ),
              Text(
                t(
                  'Tap to select your allergens. You will be warned when a product contains them.',
                  'タップしてアレルゲンを選択してください。商品に含まれる場合に警告が表示されます。',
                  zh: '点击选择您的过敏原，检测到时会发出警告。',
                ),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<Set<String>>(
                valueListenable: userAllergens,
                builder: (context, selected, _) {
                  return _buildAllergenChips(selected);
                },
              ),

              const Divider(height: 40, thickness: 1),

              // ── Custom Allergens ──────────────────────────────
              _sectionHeader(
                t('Custom Allergens', 'カスタムアレルゲン', zh: '自定义过敏原'),
                Icons.add_circle_outline,
              ),
              Text(
                t(
                  'Add allergens not listed above. They will also be detected in label scans.',
                  'リストにないアレルゲンを追加できます。ラベルスキャン時にも検出されます。',
                  zh: '添加上方列表中没有的过敏原，扫描标签时也会检测。',
                ),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<Set<String>>(
                valueListenable: customAllergens,
                builder: (context, custom, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (custom.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: custom
                              .map(
                                (name) => Chip(
                                  label: Text('⚠️ $name'),
                                  backgroundColor: Colors.purple.shade50,
                                  side: BorderSide(
                                    color: Colors.purple.shade200,
                                  ),
                                  deleteIcon: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.purple.shade400,
                                  ),
                                  onDeleted: () => removeCustomAllergen(name),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customController,
                              decoration: InputDecoration(
                                hintText: t(
                                  'e.g. Pistachio, Pine nut',
                                  '例: ピスタチオ、松の実',
                                  zh: '例如：开心果、松仁',
                                ),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
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
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Text(t('Add', '追加', zh: '添加')),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const Divider(height: 40, thickness: 1),

              // ── Language ──────────────────────────────────────
              _sectionHeader(t('Language', '言語', zh: '语言'), Icons.language),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () { appLanguage.value = 'en'; setState(() {}); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lang == 'en' ? appThemeColor.value : Colors.grey.shade300,
                        foregroundColor: lang == 'en' ? Colors.white : Colors.black87,
                      ),
                      child: const Text('English'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () { appLanguage.value = 'ja'; setState(() {}); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lang == 'ja' ? appThemeColor.value : Colors.grey.shade300,
                        foregroundColor: lang == 'ja' ? Colors.white : Colors.black87,
                      ),
                      child: const Text('日本語'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () { appLanguage.value = 'zh'; setState(() {}); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lang == 'zh' ? appThemeColor.value : Colors.grey.shade300,
                        foregroundColor: lang == 'zh' ? Colors.white : Colors.black87,
                      ),
                      child: const Text('中文'),
                    ),
                  ),
                ],
              ),

              const Divider(height: 40, thickness: 1),

              // ── Text Size ─────────────────────────────────────
              _sectionHeader(t('Text Size', '文字サイズ', zh: '文字大小'), Icons.text_fields),
              ValueListenableBuilder<double>(
                valueListenable: appTextScale,
                builder: (context, scale, _) {
                  return Slider(
                    value: scale,
                    min: 0.8,
                    max: 1.5,
                    divisions: 7,
                    label: 'x${scale.toStringAsFixed(1)}',
                    activeColor: appThemeColor.value,
                    onChanged: (val) {
                      appTextScale.value = val;
                    },
                  );
                },
              ),

              const Divider(height: 40, thickness: 1),

              // ── Theme Color ───────────────────────────────────
              _sectionHeader(t('Theme Color', 'テーマカラー', zh: '主题颜色'), Icons.palette),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                children: [
                  _colorButton(Colors.green),
                  _colorButton(Colors.blue),
                  _colorButton(Colors.orange),
                  _colorButton(Colors.purple),
                  _colorButton(Colors.pink),
                  _colorButton(Colors.black87),
                ],
              ),
              const Divider(height: 40, thickness: 1),

              // ── My Profile ────────────────────────────────────
              _sectionHeader(
                t('My Profile', 'マイプロフィール', zh: '我的档案'),
                Icons.person_outline,
              ),
              Text(
                t(
                  'Optional. More attributes = higher daily OCR scan limit.',
                  '任意。設定するほど1日のOCRスキャン上限が増えます。',
                  zh: '可选。填写越多，每日OCR扫描上限越高。',
                ),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text(
                t('Age range', '年代', zh: '年龄段'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildAgeChips(),
              const SizedBox(height: 16),
              Text(
                t('Gender', '性別', zh: '性别'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildGenderChips(),
              const SizedBox(height: 16),
              Text(
                t('Country of origin', '出身国', zh: '国籍'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _countryController,
                decoration: InputDecoration(
                  hintText: t(
                    'e.g. United States, Australia',
                    '例: United States、Australia',
                    zh: '例如：中国、日本',
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('profile_country', val.trim());
                  await _saveProfile();
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.document_scanner_outlined,
                        color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      t('Daily OCR limit: $_ocrLimit scans',
                          'OCR上限：$_ocrLimit回/日', zh: '每日OCR上限：$_ocrLimit 次'),
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 40, thickness: 1),

              // ── Privacy ───────────────────────────────────────
              _sectionHeader(t('Privacy', 'プライバシー', zh: '隐私'), Icons.privacy_tip_outlined),
              SwitchListTile(
                value: _analyticsConsent,
                onChanged: (v) async {
                  setState(() => _analyticsConsent = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('analytics_consent', v);
                },
                activeThumbColor: appThemeColor.value,
                title: Text(
                  t('Share anonymous scan statistics', '匿名のスキャン統計を共有する', zh: '共享匿名扫描统计'),
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  t(
                    'No personal info included. Helps improve allergen coverage.',
                    '個人情報は含まれません。アレルゲン情報の改善に役立てます。',
                    zh: '不含个人信息，用于改善过敏原覆盖范围。',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.article_outlined, color: Colors.grey),
                title: Text(
                  t('Privacy Policy', 'プライバシーポリシー', zh: '隐私政策'),
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => context.push('/privacy_policy'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gavel_outlined, color: Colors.grey),
                title: Text(
                  t('Terms of Service', '利用規約', zh: '服务条款'),
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => context.push('/tos'),
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _colorButton(Color color) {
    final isSelected = appThemeColor.value == color;
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
}
