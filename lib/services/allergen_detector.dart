import '../theme_settings.dart';

/// Returns the allergen dictionary key that matches [ingredient],
/// or null if no allergen is found.
/// Tries exact match first, then substring match.
String? extractAllergenKey(String ingredient) {
  if (allergenDictionary.containsKey(ingredient)) return ingredient;
  for (final key in allergenDictionary.keys) {
    if (ingredient.contains(key)) return key;
  }
  return null;
}

/// Extracts a deduplicated set of allergen keys from a list of ingredient strings.
Set<String> extractAllergenKeys(List<String> ingredients) {
  final keys = <String>{};
  for (final ingredient in ingredients) {
    final key = extractAllergenKey(ingredient);
    if (key != null) keys.add(key);
  }
  return keys;
}
