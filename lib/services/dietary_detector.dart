// Dietary preset system: presets → categories → keywords

class DietaryPresetCategory {
  final String key;
  final String emoji;
  final String labelEn;
  final String labelJa;
  final String labelZh;
  final String labelKo;
  final Map<String, String> keywords; // search_text → display_name_ja

  const DietaryPresetCategory({
    required this.key,
    required this.emoji,
    required this.labelEn,
    required this.labelJa,
    required this.labelZh,
    required this.labelKo,
    required this.keywords,
  });

  String label(String lang) => switch (lang) {
        'ja' => labelJa,
        'zh' => labelZh,
        'ko' => labelKo,
        _ => labelEn,
      };
}

class DietaryPreset {
  final String key;
  final String emoji;
  final String labelEn;
  final String labelJa;
  final String labelZh;
  final String labelKo;
  final List<DietaryPresetCategory> categories;

  const DietaryPreset({
    required this.key,
    required this.emoji,
    required this.labelEn,
    required this.labelJa,
    required this.labelZh,
    required this.labelKo,
    required this.categories,
  });

  String label(String lang) => switch (lang) {
        'ja' => labelJa,
        'zh' => labelZh,
        'ko' => labelKo,
        _ => labelEn,
      };

  // Returns keywords for active (non-removed) categories only.
  // removedCategories entries are formatted as 'presetKey:categoryKey'.
  Map<String, String> activeKeywords(Set<String> removedCategories) {
    final result = <String, String>{};
    for (final cat in categories) {
      if (!removedCategories.contains('$key:${cat.key}')) {
        result.addAll(cat.keywords);
      }
    }
    return result;
  }
}

class DietaryCheckResult {
  final DietaryPreset preset;
  final Set<String> matches; // display names of matched keywords
  const DietaryCheckResult({required this.preset, required this.matches});
  bool get ok => matches.isEmpty;
}

// ─── Keyword maps ─────────────────────────────────────────────────────────────

const _kwMeat = <String, String>{
  '豚肉': '豚肉', 'ポーク': '豚肉', '豚骨': '豚骨',
  '牛肉': '牛肉', 'ビーフ': '牛肉',
  '鶏肉': '鶏肉', 'チキン': '鶏肉',
  '羊肉': '羊肉', 'ラム肉': '羊肉', 'マトン': '羊肉', '馬肉': '馬肉',
  'チキンエキス': 'チキンエキス', 'ポークエキス': 'ポークエキス',
  'ビーフエキス': 'ビーフエキス', '骨エキス': '骨エキス',
  'チキンブイヨン': 'チキンブイヨン', 'ビーフブイヨン': 'ビーフブイヨン',
  'ラード': 'ラード', '豚脂': '豚脂', '牛脂': '牛脂', '鶏油': '鶏油',
  '動物性油脂': '動物性油脂',
};

const _kwSeafood = <String, String>{
  'さけ': 'さけ（鮭）', 'さば': 'さば（鯖）', 'いか': 'いか', 'いくら': 'いくら',
  'あわび': 'あわび', 'えび': 'えび', 'かに': 'かに',
  'かつお節': 'かつお節', '鰹節': 'かつお節', '煮干し': '煮干し', 'いわし': 'いわし',
  '魚介': '魚介類', '魚醤': '魚醤', 'アンチョビ': 'アンチョビ', '魚粉': '魚粉',
  '魚エキス': '魚エキス', 'かつおエキス': 'かつおエキス',
};

const _kwDairy = <String, String>{
  '乳成分': '乳成分', '牛乳': '牛乳', '脱脂粉乳': '脱脂粉乳', '全粉乳': '全粉乳',
  'バター': 'バター', 'チーズ': 'チーズ', 'クリーム': 'クリーム', 'ヨーグルト': 'ヨーグルト',
  'カゼイン': 'カゼイン', 'ホエイ': 'ホエイ', '乳清': '乳清', '乳たんぱく': '乳たんぱく',
  '乳糖': '乳糖', 'ラクトース': 'ラクトース',
};

const _kwEgg = <String, String>{
  '卵': '卵', '全卵': '全卵', '卵白': '卵白', '卵黄': '卵黄',
};

const _kwOtherAnimal = <String, String>{
  'はちみつ': 'はちみつ', 'ハチミツ': 'はちみつ',
  'ゼラチン': 'ゼラチン', 'コラーゲン': 'コラーゲン',
  'コチニール': 'コチニール色素', 'L-シスチン': 'L-シスチン',
};

const _kwPork = <String, String>{
  '豚肉': '豚肉', 'ポーク': '豚肉', '豚骨': '豚骨',
  'ラード': 'ラード', '豚脂': '豚脂', 'ポークエキス': 'ポークエキス',
};

const _kwAlcohol = <String, String>{
  '酒精': '酒精（アルコール）', 'アルコール': 'アルコール', 'エタノール': 'エタノール',
  '醸造アルコール': '醸造アルコール', '日本酒': '日本酒', 'みりん': 'みりん',
  '清酒': '清酒', 'ワイン': 'ワイン', '洋酒': '洋酒', '焼酎': '焼酎', 'ブランデー': 'ブランデー',
};

const _kwGluten = <String, String>{
  '小麦': '小麦', '小麦粉': '小麦粉', '薄力粉': '薄力粉', '強力粉': '強力粉',
  '中力粉': '中力粉', '小麦でん粉': '小麦でん粉', '小麦たんぱく': '小麦たんぱく',
  'グルテン': 'グルテン', '小麦グルテン': '小麦グルテン',
  'セモリナ': 'セモリナ', 'デュラム': 'デュラム',
  '大麦': '大麦', '麦芽': '麦芽', '大麦エキス': '大麦エキス', 'ライ麦': 'ライ麦',
};

const _kwBeef = <String, String>{
  '牛肉': '牛肉', 'ビーフ': '牛肉', '牛脂': '牛脂',
  'ビーフエキス': 'ビーフエキス', 'ビーフブイヨン': 'ビーフブイヨン', '牛骨': '牛骨',
};

// ─── Category singletons ──────────────────────────────────────────────────────

const catMeat = DietaryPresetCategory(
  key: 'meat', emoji: '🥩',
  labelEn: 'Meat', labelJa: '肉類', labelZh: '肉类', labelKo: '육류',
  keywords: _kwMeat,
);
const catSeafood = DietaryPresetCategory(
  key: 'seafood', emoji: '🐟',
  labelEn: 'Seafood', labelJa: '魚介類', labelZh: '海鲜', labelKo: '해산물',
  keywords: _kwSeafood,
);
const catDairy = DietaryPresetCategory(
  key: 'dairy', emoji: '🥛',
  labelEn: 'Dairy', labelJa: '乳製品', labelZh: '乳制品', labelKo: '유제품',
  keywords: _kwDairy,
);
const catEgg = DietaryPresetCategory(
  key: 'egg', emoji: '🥚',
  labelEn: 'Eggs', labelJa: '卵', labelZh: '鸡蛋', labelKo: '달걀',
  keywords: _kwEgg,
);
const catOtherAnimal = DietaryPresetCategory(
  key: 'other_animal', emoji: '🍯',
  labelEn: 'Other animal-derived', labelJa: 'その他（動物由来）',
  labelZh: '其他动物源', labelKo: '기타 동물성',
  keywords: _kwOtherAnimal,
);
const catPork = DietaryPresetCategory(
  key: 'pork', emoji: '🐷',
  labelEn: 'Pork', labelJa: '豚肉・豚由来', labelZh: '猪肉', labelKo: '돼지고기',
  keywords: _kwPork,
);
const catAlcohol = DietaryPresetCategory(
  key: 'alcohol', emoji: '🍶',
  labelEn: 'Alcohol', labelJa: 'アルコール類', labelZh: '酒精类', labelKo: '알코올',
  keywords: _kwAlcohol,
);
const catGluten = DietaryPresetCategory(
  key: 'gluten', emoji: '🌾',
  labelEn: 'Gluten (wheat/barley)', labelJa: 'グルテン（小麦・大麦）',
  labelZh: '麸质（小麦/大麦）', labelKo: '글루텐 (밀/보리)',
  keywords: _kwGluten,
);
const catBeef = DietaryPresetCategory(
  key: 'beef', emoji: '🐄',
  labelEn: 'Beef', labelJa: '牛肉・牛由来', labelZh: '牛肉', labelKo: '소고기',
  keywords: _kwBeef,
);

// ─── Preset catalogue ─────────────────────────────────────────────────────────

const kDietaryPresets = <String, DietaryPreset>{
  'vegan': DietaryPreset(
    key: 'vegan', emoji: '🌿',
    labelEn: 'Vegan', labelJa: 'ヴィーガン', labelZh: '纯素食', labelKo: '비건',
    categories: [catMeat, catSeafood, catDairy, catEgg, catOtherAnimal],
  ),
  'vegetarian': DietaryPreset(
    key: 'vegetarian', emoji: '🥗',
    labelEn: 'Vegetarian', labelJa: 'ベジタリアン', labelZh: '素食', labelKo: '채식',
    categories: [catMeat, catSeafood],
  ),
  'halal': DietaryPreset(
    key: 'halal', emoji: '☪️',
    labelEn: 'Halal', labelJa: 'ハラール', labelZh: '清真', labelKo: '할랄',
    categories: [catPork, catAlcohol],
  ),
  'gluten_free': DietaryPreset(
    key: 'gluten_free', emoji: '🌾',
    labelEn: 'Gluten-free', labelJa: 'グルテンフリー', labelZh: '无麸质', labelKo: '글루텐프리',
    categories: [catGluten],
  ),
  'no_beef': DietaryPreset(
    key: 'no_beef', emoji: '🐄',
    labelEn: 'No Beef', labelJa: '牛肉NG', labelZh: '不吃牛肉', labelKo: '소고기 제외',
    categories: [catBeef],
  ),
  'no_pork': DietaryPreset(
    key: 'no_pork', emoji: '🐷',
    labelEn: 'No Pork', labelJa: '豚肉NG', labelZh: '不吃猪肉', labelKo: '돼지고기 제외',
    categories: [catPork],
  ),
};

// ─── Detection ────────────────────────────────────────────────────────────────

List<DietaryCheckResult> checkDietaryPresets(
  String text,
  Set<String> activePresets,
  Set<String> removedCategories,
) {
  if (text.trim().isEmpty) return [];
  return activePresets
      .map((k) => kDietaryPresets[k])
      .whereType<DietaryPreset>()
      .map((preset) {
        final effective = preset.activeKeywords(removedCategories);
        final matches = <String>{};
        for (final e in effective.entries) {
          if (text.contains(e.key)) matches.add(e.value);
        }
        return DietaryCheckResult(preset: preset, matches: matches);
      })
      .toList();
}

Set<String> checkCustomKeywords(String text, Set<String> keywords) {
  if (text.trim().isEmpty || keywords.isEmpty) return {};
  return keywords.where(text.contains).toSet();
}
