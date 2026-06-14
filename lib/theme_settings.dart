import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------
// アレルゲン辞書（全画面で共有）
// ---------------------------------------------------------
// 日本 特定原材料（義務8品目）＋ 準ずるもの21品目 ＋ EU・米国追加分
const Map<String, Map<String, String>> allergenDictionary = {
  // ── 日本 義務表示 8品目 ──
  '卵': {'en': 'Egg', 'emoji': '🥚'},
  '乳成分': {'en': 'Milk', 'emoji': '🥛'},
  '小麦': {'en': 'Wheat', 'emoji': '🌾'},
  'そば': {'en': 'Buckwheat', 'emoji': '🍜'},
  '落花生': {'en': 'Peanut', 'emoji': '🥜'},
  'えび': {'en': 'Shrimp', 'emoji': '🦐'},
  'かに': {'en': 'Crab', 'emoji': '🦀'},
  'くるみ': {'en': 'Walnut', 'emoji': '🌰'},
  // ── 日本 推奨表示 21品目 ──
  'アーモンド': {'en': 'Almond', 'emoji': '🌰'},
  'あわび': {'en': 'Abalone', 'emoji': '🐚'},
  'いか': {'en': 'Squid', 'emoji': '🦑'},
  'いくら': {'en': 'Salmon Roe', 'emoji': '🟠'},
  'オレンジ': {'en': 'Orange', 'emoji': '🍊'},
  'カシューナッツ': {'en': 'Cashew', 'emoji': '🌰'},
  'キウイフルーツ': {'en': 'Kiwi', 'emoji': '🥝'},
  '牛肉': {'en': 'Beef', 'emoji': '🐮'},
  'ごま': {'en': 'Sesame', 'emoji': '🌿'},
  'さけ': {'en': 'Salmon', 'emoji': '🐟'},
  'さば': {'en': 'Mackerel', 'emoji': '🐡'},
  '大豆': {'en': 'Soybean', 'emoji': '🌱'},
  '鶏肉': {'en': 'Chicken', 'emoji': '🐔'},
  'バナナ': {'en': 'Banana', 'emoji': '🍌'},
  '豚肉': {'en': 'Pork', 'emoji': '🐷'},
  'まつたけ': {'en': 'Matsutake', 'emoji': '🍄'},
  'もも': {'en': 'Peach', 'emoji': '🍑'},
  'やまいも': {'en': 'Yam', 'emoji': '🍠'},
  'りんご': {'en': 'Apple', 'emoji': '🍎'},
  'ゼラチン': {'en': 'Gelatin', 'emoji': '🧊'},
  'マカダミアナッツ': {'en': 'Macadamia', 'emoji': '🌰'},
  // ── EU 追加 ──
  'セロリ': {'en': 'Celery', 'emoji': '🥬'},
  'からし': {'en': 'Mustard', 'emoji': '🌿'},
  '亜硫酸塩': {'en': 'Sulphites', 'emoji': '🧪'},
  'ルパン': {'en': 'Lupin', 'emoji': '🌸'},
  // ── その他・共通 ──
  '魚類': {'en': 'Fish (general)', 'emoji': '🐟'},
  'とうもろこし': {'en': 'Corn', 'emoji': '🌽'},
  '植物油脂': {'en': 'Vegetable Oil (source unspecified)', 'emoji': '🛢️'},
};

// 植物油関連キーワード（原料が特定できない可能性があるもの）
const List<String> vegetableOilKeywords = [
  '植物油脂',
  '植物油',
  '加工油脂',
];

// 同一製造工程・コンタミネーション検出フレーズ
const List<String> crossContaminationPhrases = [
  '同じ製造ライン',
  '同じ設備',
  '共通の設備',
  '同一の設備',
  '同一工場',
  '同じ工場',
  '製造工場では',
  '本製品製造工場では',
  'を含む製品を製造',
  'を含む食品と共通',
  'を使用した設備',
  '微量混入',
  'コンタミ',
];

// ---------------------------------------------------------
// 🌟 司令塔0：言語設定 (NEW!)
// ---------------------------------------------------------
final ValueNotifier<String> appLanguage = ValueNotifier('en'); // 初期値は英語

// 🪄 魔法の翻訳ヘルパー関数
// 使い方: t('Hello', 'こんにちは') と書くと、設定に合わせて文字が切り替わります！
String t(String en, String ja) {
  return appLanguage.value == 'en' ? en : ja;
}

// ---------------------------------------------------------
// 🌟 司令塔1：デザイン（テーマカラーと文字サイズ）
// ---------------------------------------------------------
final ValueNotifier<double> appTextScale = ValueNotifier(1.0);
final ValueNotifier<Color> appThemeColor = ValueNotifier(Colors.green);

// ---------------------------------------------------------
// マイアレルゲンプロファイル
// ---------------------------------------------------------
final ValueNotifier<Set<String>> userAllergens = ValueNotifier({});

Future<void> loadUserAllergens() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getStringList('user_allergens') ?? [];
  userAllergens.value = saved.toSet();
}

Future<void> _saveUserAllergens(Set<String> allergens) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('user_allergens', allergens.toList());
  userAllergens.value = Set.from(allergens);
}

// ---------------------------------------------------------
// 🌟 司令塔2：履歴データ
// ---------------------------------------------------------
final ValueNotifier<List<Map<String, dynamic>>> globalHistory = ValueNotifier(
  [],
);

Future<void> loadGlobalHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final historyStrings = prefs.getStringList('scan_history') ?? [];
  globalHistory.value = historyStrings
      .map((e) => jsonDecode(e) as Map<String, dynamic>)
      .toList();
}

Future<void> saveToGlobalHistory(Map<String, dynamic> product) async {
  final prefs = await SharedPreferences.getInstance();
  List<String> historyStrings = prefs.getStringList('scan_history') ?? [];

  final currentJan = product['janCode']?.toString() ?? '';
  historyStrings.removeWhere(
    (item) => jsonDecode(item)['janCode'] == currentJan,
  );

  historyStrings.insert(0, jsonEncode(product));

  if (historyStrings.length > 10) {
    historyStrings = historyStrings.sublist(0, 10);
  }

  await prefs.setStringList('scan_history', historyStrings);
  globalHistory.value = historyStrings
      .map((e) => jsonDecode(e) as Map<String, dynamic>)
      .toList();
}

// ---------------------------------------------------------
// 🎨 UI：どの画面からでも呼び出せる共通の設定ボタンと画面
// ---------------------------------------------------------

Widget buildGlobalSettingsButton(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.language), // 🌐 アイコンを地球儀に変更！
    tooltip: t('Settings', '設定'),
    onPressed: () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) =>
              SettingsBottomSheet(scrollController: scrollController),
        ),
      );
    },
  );
}

class SettingsBottomSheet extends StatefulWidget {
  final ScrollController? scrollController;
  const SettingsBottomSheet({super.key, this.scrollController});

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            t('My Allergens / マイアレルゲン', 'マイアレルゲン / My Allergens'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            t(
              'Select your allergens to get warnings on product pages.',
              'アレルゲンを選ぶと、商品ページで自動警告が表示されます。',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<Set<String>>(
            valueListenable: userAllergens,
            builder: (context, selected, _) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allergenDictionary.entries.map((entry) {
                  final jp = entry.key;
                  final emoji = entry.value['emoji']!;
                  final isSelected = selected.contains(jp);
                  return FilterChip(
                    label: Text('$emoji $jp'),
                    selected: isSelected,
                    selectedColor: Colors.red.shade100,
                    checkmarkColor: Colors.red,
                    side: isSelected
                        ? BorderSide(color: Colors.red.shade300)
                        : null,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.red.shade800
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      final newSet = Set<String>.from(selected);
                      if (val) {
                        newSet.add(jp);
                      } else {
                        newSet.remove(jp);
                      }
                      _saveUserAllergens(newSet);
                    },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          // 🌐 言語切り替えボタン (NEW!)
          Text(
            t('Language / 言語', '言語 / Language'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    appLanguage.value = 'en';
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appLanguage.value == 'en'
                        ? appThemeColor.value
                        : Colors.grey.shade300,
                    foregroundColor: appLanguage.value == 'en'
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
                    backgroundColor: appLanguage.value == 'ja'
                        ? appThemeColor.value
                        : Colors.grey.shade300,
                    foregroundColor: appLanguage.value == 'ja'
                        ? Colors.white
                        : Colors.black87,
                  ),
                  child: const Text('日本語'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            t('Text Size / 文字サイズ', '文字サイズ / Text Size'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: appTextScale.value,
            min: 0.8,
            max: 1.5,
            divisions: 7,
            label: 'x${appTextScale.value.toStringAsFixed(1)}',
            activeColor: appThemeColor.value,
            onChanged: (val) {
              setState(() {});
              appTextScale.value = val;
            },
          ),
          const SizedBox(height: 16),
          Text(
            t('Theme Color / テーマカラー', 'テーマカラー / Theme Color'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _colorButton(Color color) {
    final isSelected = appThemeColor.value == color;
    return GestureDetector(
      onTap: () {
        setState(() {});
        appThemeColor.value = color;
      },
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
