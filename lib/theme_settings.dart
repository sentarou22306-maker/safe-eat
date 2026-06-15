import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  'はちみつ': {'en': 'Honey', 'emoji': '🍯'},
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
final ValueNotifier<Set<String>> customAllergens = ValueNotifier({});

Future<void> loadAppSettings() async {
  final prefs = await SharedPreferences.getInstance();
  appLanguage.value = prefs.getString('app_language') ?? 'en';
  appTextScale.value = prefs.getDouble('app_text_scale') ?? 1.0;
  final colorVal = prefs.getInt('app_theme_color');
  if (colorVal != null) appThemeColor.value = Color(colorVal);

  appLanguage.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('app_language', appLanguage.value);
  });
  appTextScale.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('app_text_scale', appTextScale.value);
  });
  appThemeColor.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('app_theme_color', appThemeColor.value.toARGB32());
  });
}

Future<void> loadUserAllergens() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getStringList('user_allergens') ?? [];
  userAllergens.value = saved.toSet();
}

Future<void> saveUserAllergens(Set<String> allergens) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('user_allergens', allergens.toList());
  userAllergens.value = Set.from(allergens);
}

Future<void> loadCustomAllergens() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getStringList('custom_allergens') ?? [];
  customAllergens.value = saved.toSet();
}

Future<void> addCustomAllergen(String name) async {
  final prefs = await SharedPreferences.getInstance();
  final current = Set<String>.from(customAllergens.value)..add(name);
  await prefs.setStringList('custom_allergens', current.toList());
  customAllergens.value = current;
}

Future<void> removeCustomAllergen(String name) async {
  final prefs = await SharedPreferences.getInstance();
  final current = Set<String>.from(customAllergens.value)..remove(name);
  await prefs.setStringList('custom_allergens', current.toList());
  customAllergens.value = current;
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

Future<bool> showOcrGuideDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.photo_camera_outlined,
        size: 52,
        color: Colors.teal,
      ),
      title: Text(t('Scan the ingredient label', '原材料表示を撮影')),
      content: Text(
        t(
          'Point your camera at the ingredients list on the back of the package. Make sure the text is clearly visible and well-lit.',
          '商品裏面の原材料表示にカメラを向けてください。\n文字がはっきり見えるよう、明るい場所で撮影してください。',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t('Cancel', 'キャンセル')),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.camera_alt),
          label: Text(t('Take Photo', '撮影する')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

Widget buildGlobalSettingsButton(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.settings),
    tooltip: t('Settings', '設定'),
    onPressed: () => context.push('/settings'),
  );
}
