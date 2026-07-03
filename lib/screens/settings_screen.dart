import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _customController = TextEditingController();
  bool _analyticsConsent = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _analyticsConsent = prefs.getBool('analytics_consent') ?? false;
      });
    });
  }

  @override
  void dispose() {
    _customController.dispose();
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
                final en = info['en']!;
                final emoji = info['emoji']!;
                final isSelected = selected.contains(jp);
                return FilterChip(
                  label: Text(
                    '$emoji $jp / $en',
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
            title: Text(t('Settings', '設定')),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: Text(t('Done', '完了')),
            backgroundColor: appThemeColor.value,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── My Allergens ──────────────────────────────────
              _sectionHeader(
                t('My Allergens', 'マイアレルゲン'),
                Icons.warning_amber_rounded,
              ),
              Text(
                t(
                  'Tap to select your allergens. You will be warned when a product contains them.',
                  'タップしてアレルゲンを選択してください。商品に含まれる場合に警告が表示されます。',
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
                t('Custom Allergens', 'カスタムアレルゲン'),
                Icons.add_circle_outline,
              ),
              Text(
                t(
                  'Add allergens not listed above. They will also be detected in label scans.',
                  'リストにないアレルゲンを追加できます。ラベルスキャン時にも検出されます。',
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
                            child: Text(t('Add', '追加')),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const Divider(height: 40, thickness: 1),

              // ── Language ──────────────────────────────────────
              _sectionHeader(t('Language', '言語'), Icons.language),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        appLanguage.value = 'en';
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lang == 'en'
                            ? appThemeColor.value
                            : Colors.grey.shade300,
                        foregroundColor: lang == 'en'
                            ? Colors.white
                            : Colors.black87,
                      ),
                      child: const Text('English'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        appLanguage.value = 'ja';
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lang == 'ja'
                            ? appThemeColor.value
                            : Colors.grey.shade300,
                        foregroundColor: lang == 'ja'
                            ? Colors.white
                            : Colors.black87,
                      ),
                      child: const Text('日本語'),
                    ),
                  ),
                ],
              ),

              const Divider(height: 40, thickness: 1),

              // ── Text Size ─────────────────────────────────────
              _sectionHeader(t('Text Size', '文字サイズ'), Icons.text_fields),
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
              _sectionHeader(t('Theme Color', 'テーマカラー'), Icons.palette),
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

              // ── Privacy ───────────────────────────────────────
              _sectionHeader(t('Privacy', 'プライバシー'), Icons.privacy_tip_outlined),
              SwitchListTile(
                value: _analyticsConsent,
                onChanged: (v) async {
                  setState(() => _analyticsConsent = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('analytics_consent', v);
                },
                activeThumbColor: appThemeColor.value,
                title: Text(
                  t('Share anonymous scan statistics', '匿名のスキャン統計を共有する'),
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  t(
                    'No personal info included. Helps improve allergen coverage.',
                    '個人情報は含まれません。アレルゲン情報の改善に役立てます。',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                contentPadding: EdgeInsets.zero,
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
