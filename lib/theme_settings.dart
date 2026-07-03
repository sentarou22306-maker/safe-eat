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
  '卵': {'en': 'Egg', 'emoji': '🥚', 'zh': '鸡蛋'},
  '乳成分': {'en': 'Milk', 'emoji': '🥛', 'zh': '乳制品'},
  '小麦': {'en': 'Wheat', 'emoji': '🌾', 'zh': '小麦'},
  'そば': {'en': 'Buckwheat', 'emoji': '🍜', 'zh': '荞麦'},
  '落花生': {'en': 'Peanut', 'emoji': '🥜', 'zh': '花生'},
  'えび': {'en': 'Shrimp', 'emoji': '🦐', 'zh': '虾'},
  'かに': {'en': 'Crab', 'emoji': '🦀', 'zh': '螃蟹'},
  'くるみ': {'en': 'Walnut', 'emoji': '🌰', 'zh': '核桃'},
  // ── 日本 推奨表示 21品目 ──
  'アーモンド': {'en': 'Almond', 'emoji': '🌰', 'zh': '杏仁'},
  'あわび': {'en': 'Abalone', 'emoji': '🐚', 'zh': '鲍鱼'},
  'いか': {'en': 'Squid', 'emoji': '🦑', 'zh': '鱿鱼'},
  'いくら': {'en': 'Salmon Roe', 'emoji': '🟠', 'zh': '鲑鱼子'},
  'オレンジ': {'en': 'Orange', 'emoji': '🍊', 'zh': '橙子'},
  'カシューナッツ': {'en': 'Cashew', 'emoji': '🌰', 'zh': '腰果'},
  'キウイフルーツ': {'en': 'Kiwi', 'emoji': '🥝', 'zh': '猕猴桃'},
  '牛肉': {'en': 'Beef', 'emoji': '🐮', 'zh': '牛肉'},
  'ごま': {'en': 'Sesame', 'emoji': '🌿', 'zh': '芝麻'},
  'さけ': {'en': 'Salmon', 'emoji': '🐟', 'zh': '三文鱼'},
  'さば': {'en': 'Mackerel', 'emoji': '🐡', 'zh': '鲭鱼'},
  '大豆': {'en': 'Soybean', 'emoji': '🌱', 'zh': '大豆'},
  '鶏肉': {'en': 'Chicken', 'emoji': '🐔', 'zh': '鸡肉'},
  'バナナ': {'en': 'Banana', 'emoji': '🍌', 'zh': '香蕉'},
  '豚肉': {'en': 'Pork', 'emoji': '🐷', 'zh': '猪肉'},
  'まつたけ': {'en': 'Matsutake', 'emoji': '🍄', 'zh': '松茸'},
  'もも': {'en': 'Peach', 'emoji': '🍑', 'zh': '桃子'},
  'やまいも': {'en': 'Yam', 'emoji': '🍠', 'zh': '山药'},
  'りんご': {'en': 'Apple', 'emoji': '🍎', 'zh': '苹果'},
  'ゼラチン': {'en': 'Gelatin', 'emoji': '🧊', 'zh': '明胶'},
  'マカダミアナッツ': {'en': 'Macadamia', 'emoji': '🌰', 'zh': '澳洲坚果'},
  // ── EU 追加 ──
  'セロリ': {'en': 'Celery', 'emoji': '🥬', 'zh': '芹菜'},
  'からし': {'en': 'Mustard', 'emoji': '🌿', 'zh': '芥末'},
  '亜硫酸塩': {'en': 'Sulphites', 'emoji': '🧪', 'zh': '亚硫酸盐'},
  'ルパン': {'en': 'Lupin', 'emoji': '🌸', 'zh': '羽扇豆'},
  // ── その他・共通 ──
  '魚類': {'en': 'Fish (general)', 'emoji': '🐟', 'zh': '鱼类'},
  'とうもろこし': {'en': 'Corn', 'emoji': '🌽', 'zh': '玉米'},
  '植物油脂': {'en': 'Vegetable Oil (source unspecified)', 'emoji': '🛢️', 'zh': '植物油（来源不明）'},
  'はちみつ': {'en': 'Honey', 'emoji': '🍯', 'zh': '蜂蜜'},
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
String t(String en, String ja, {String? zh}) {
  return switch (appLanguage.value) {
    'ja' => ja,
    'zh' => zh ?? en,
    _ => en,
  };
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
      title: Text(t('Scan the ingredient label', '原材料表示を撮影', zh: '拍摄成分表')),
      content: Text(
        t(
          'Point your camera at the ingredients list on the back of the package. Make sure the text is clearly visible and well-lit.',
          '商品裏面の原材料表示にカメラを向けてください。\n文字がはっきり見えるよう、明るい場所で撮影してください。',
          zh: '将相机对准包装背面的成分表。\n请在光线充足的环境下拍摄，确保文字清晰可见。',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t('Cancel', 'キャンセル', zh: '取消')),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.camera_alt),
          label: Text(t('Take Photo', '撮影する', zh: '拍照')),
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
