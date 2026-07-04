import 'package:shared_preferences/shared_preferences.dart';

Future<int> getDailyOcrLimit() async {
  final prefs = await SharedPreferences.getInstance();
  final hasAge = prefs.getString('profile_age_range') != null;
  final hasGender = prefs.getString('profile_gender') != null;
  final hasCountry =
      (prefs.getString('profile_country') ?? '').trim().isNotEmpty;
  final hasConsent = prefs.getBool('analytics_consent') ?? false;

  int limit = 5;
  if (hasAge) limit = 10;
  if (hasAge && hasGender) limit = 18;
  if (hasAge && hasGender && hasCountry) limit = 30;
  if (hasConsent) limit += 5;
  return limit;
}

String _todayKey() =>
    'ocr_count_${DateTime.now().toIso8601String().substring(0, 10)}';

Future<int> getRemainingOcrScans() async {
  final prefs = await SharedPreferences.getInstance();
  final limit = await getDailyOcrLimit();
  final used = prefs.getInt(_todayKey()) ?? 0;
  return (limit - used).clamp(0, limit);
}

Future<bool> canRunOcr() async => (await getRemainingOcrScans()) > 0;

Future<void> recordOcrUse() async {
  final prefs = await SharedPreferences.getInstance();
  final key = _todayKey();
  await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
}

// 貢献送信時にスキャン1回分を返金する
Future<void> refundOcrUse() async {
  final prefs = await SharedPreferences.getInstance();
  final key = _todayKey();
  final current = prefs.getInt(key) ?? 0;
  if (current > 0) await prefs.setInt(key, current - 1);
}
