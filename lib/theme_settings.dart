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
  '卵': {'en': 'Egg', 'emoji': '🥚', 'zh': '鸡蛋', 'ko': '계란'},
  '乳成分': {'en': 'Milk', 'emoji': '🥛', 'zh': '乳制品', 'ko': '유제품'},
  '小麦': {'en': 'Wheat', 'emoji': '🌾', 'zh': '小麦', 'ko': '밀'},
  'そば': {'en': 'Buckwheat', 'emoji': '🍜', 'zh': '荞麦', 'ko': '메밀'},
  '落花生': {'en': 'Peanut', 'emoji': '🥜', 'zh': '花生', 'ko': '땅콩'},
  'えび': {'en': 'Shrimp', 'emoji': '🦐', 'zh': '虾', 'ko': '새우'},
  'かに': {'en': 'Crab', 'emoji': '🦀', 'zh': '螃蟹', 'ko': '게'},
  'くるみ': {'en': 'Walnut', 'emoji': '🌰', 'zh': '核桃', 'ko': '호두'},
  // ── 日本 推奨表示 21品目 ──
  'アーモンド': {'en': 'Almond', 'emoji': '🌰', 'zh': '杏仁', 'ko': '아몬드'},
  'あわび': {'en': 'Abalone', 'emoji': '🐚', 'zh': '鲍鱼', 'ko': '전복'},
  'いか': {'en': 'Squid', 'emoji': '🦑', 'zh': '鱿鱼', 'ko': '오징어'},
  'いくら': {'en': 'Salmon Roe', 'emoji': '🟠', 'zh': '鲑鱼子', 'ko': '연어알'},
  'オレンジ': {'en': 'Orange', 'emoji': '🍊', 'zh': '橙子', 'ko': '오렌지'},
  'カシューナッツ': {'en': 'Cashew', 'emoji': '🌰', 'zh': '腰果', 'ko': '캐슈너트'},
  'キウイフルーツ': {'en': 'Kiwi', 'emoji': '🥝', 'zh': '猕猴桃', 'ko': '키위'},
  '牛肉': {'en': 'Beef', 'emoji': '🐮', 'zh': '牛肉', 'ko': '소고기'},
  'ごま': {'en': 'Sesame', 'emoji': '🌿', 'zh': '芝麻', 'ko': '참깨'},
  'さけ': {'en': 'Salmon', 'emoji': '🐟', 'zh': '三文鱼', 'ko': '연어'},
  'さば': {'en': 'Mackerel', 'emoji': '🐡', 'zh': '鲭鱼', 'ko': '고등어'},
  '大豆': {'en': 'Soybean', 'emoji': '🌱', 'zh': '大豆', 'ko': '대두'},
  '鶏肉': {'en': 'Chicken', 'emoji': '🐔', 'zh': '鸡肉', 'ko': '닭고기'},
  'バナナ': {'en': 'Banana', 'emoji': '🍌', 'zh': '香蕉', 'ko': '바나나'},
  '豚肉': {'en': 'Pork', 'emoji': '🐷', 'zh': '猪肉', 'ko': '돼지고기'},
  'まつたけ': {'en': 'Matsutake', 'emoji': '🍄', 'zh': '松茸', 'ko': '송이버섯'},
  'もも': {'en': 'Peach', 'emoji': '🍑', 'zh': '桃子', 'ko': '복숭아'},
  'やまいも': {'en': 'Yam', 'emoji': '🍠', 'zh': '山药', 'ko': '마'},
  'りんご': {'en': 'Apple', 'emoji': '🍎', 'zh': '苹果', 'ko': '사과'},
  'ゼラチン': {'en': 'Gelatin', 'emoji': '🧊', 'zh': '明胶', 'ko': '젤라틴'},
  'マカダミアナッツ': {'en': 'Macadamia', 'emoji': '🌰', 'zh': '澳洲坚果', 'ko': '마카다미아'},
  // ── EU 追加 ──
  'セロリ': {'en': 'Celery', 'emoji': '🥬', 'zh': '芹菜', 'ko': '셀러리'},
  'からし': {'en': 'Mustard', 'emoji': '🌿', 'zh': '芥末', 'ko': '겨자'},
  '亜硫酸塩': {'en': 'Sulphites', 'emoji': '🧪', 'zh': '亚硫酸盐', 'ko': '아황산염'},
  'ルパン': {'en': 'Lupin', 'emoji': '🌸', 'zh': '羽扇豆', 'ko': '루핀'},
  // ── その他・共通 ──
  '魚類': {'en': 'Fish (general)', 'emoji': '🐟', 'zh': '鱼类', 'ko': '생선류'},
  'とうもろこし': {'en': 'Corn', 'emoji': '🌽', 'zh': '玉米', 'ko': '옥수수'},
  '植物油脂': {'en': 'Vegetable Oil (source unspecified)', 'emoji': '🛢️', 'zh': '植物油（来源不明）', 'ko': '식물성 유지(원료 불명)'},
  'はちみつ': {'en': 'Honey', 'emoji': '🍯', 'zh': '蜂蜜', 'ko': '꿀'},
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
// Language setting
// ---------------------------------------------------------
final ValueNotifier<String> appLanguage = ValueNotifier('en');

String t(String en, String ja, {String? zh, String? ko}) {
  return switch (appLanguage.value) {
    'ja' => ja,
    'zh' => zh ?? en,
    'ko' => ko ?? en,
    _ => en,
  };
}

// ---------------------------------------------------------
// Theme settings
// ---------------------------------------------------------
final ValueNotifier<double> appTextScale = ValueNotifier(1.0);
final ValueNotifier<Color> appThemeColor = ValueNotifier(Colors.green);

// ---------------------------------------------------------
// マイアレルゲンプロファイル
// ---------------------------------------------------------
final ValueNotifier<Set<String>> userAllergens = ValueNotifier({});
final ValueNotifier<Set<String>> customAllergens = ValueNotifier({});

// 食事制限プロファイル（プリセット選択 + カスタマイズ）
final ValueNotifier<Set<String>> activeDietaryPresets = ValueNotifier({});
// 除外カテゴリ: 'presetKey:categoryKey' 形式の文字列セット
final ValueNotifier<Set<String>> removedDietaryCategories = ValueNotifier({});
final ValueNotifier<Set<String>> addedDietaryKeywords = ValueNotifier({});

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

Future<void> loadDietaryPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  activeDietaryPresets.value =
      (prefs.getStringList('active_dietary_presets') ?? []).toSet();
  removedDietaryCategories.value =
      (prefs.getStringList('removed_dietary_categories') ?? []).toSet();
  addedDietaryKeywords.value =
      (prefs.getStringList('added_dietary_keywords') ?? []).toSet();
}

Future<void> saveActiveDietaryPresets(Set<String> presets) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('active_dietary_presets', presets.toList());
  activeDietaryPresets.value = Set.from(presets);
}

Future<void> saveRemovedDietaryCategories(Set<String> removed) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('removed_dietary_categories', removed.toList());
  removedDietaryCategories.value = Set.from(removed);
}

Future<void> saveAddedDietaryKeywords(Set<String> added) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('added_dietary_keywords', added.toList());
  addedDietaryKeywords.value = Set.from(added);
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
// Scan history
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
      title: Text(t('Scan the ingredient label', '原材料表示を撮影', zh: '拍摄成分表', ko: '성분 라벨 스캔')),
      content: Text(
        t(
          'Point your camera at the ingredients list on the back of the package. Make sure the text is clearly visible and well-lit.',
          '商品裏面の原材料表示にカメラを向けてください。\n文字がはっきり見えるよう、明るい場所で撮影してください。',
          zh: '将相机对准包装背面的成分表。\n请在光线充足的环境下拍摄，确保文字清晰可见。',
          ko: '포장 뒷면의 성분표에 카메라를 향해 주세요.\n밝은 곳에서 글씨가 잘 보이도록 촬영해 주세요.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t('Cancel', 'キャンセル', zh: '取消', ko: '취소')),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.camera_alt),
          label: Text(t('Take Photo', '撮影する', zh: '拍照', ko: '촬영')),
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
    tooltip: t('Settings', '設定', zh: '设置', ko: '설정'),
    onPressed: () => context.push('/settings'),
  );
}
