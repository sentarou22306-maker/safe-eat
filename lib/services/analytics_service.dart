import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_settings.dart';

/// source: 'db' | 'ofa' | 'ocr'
Future<void> logScanEvent({required String source}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool('analytics_consent') ?? false)) return;

  final country = prefs.getString('profile_country')?.trim();
  try {
    await Supabase.instance.client.from('scan_analytics').insert({
      'scanned_date': DateTime.now().toIso8601String().substring(0, 10),
      'app_language': appLanguage.value,
      'user_allergens': userAllergens.value.toList(),
      'source': source,
      'age_range': prefs.getString('profile_age_range'),
      'gender': prefs.getString('profile_gender'),
      if (country != null && country.isNotEmpty) 'country': country,
    });
  } catch (_) {
    // Analytics failure must never affect the user experience
  }
}
