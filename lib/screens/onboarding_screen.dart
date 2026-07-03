import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_settings.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _categories = [
    (
      '🇯🇵 Mandatory 8 / 義務8品目',
      ['卵', '乳成分', '小麦', 'そば', '落花生', 'えび', 'かに', 'くるみ'],
    ),
    (
      '🇯🇵 Recommended 21 / 推奨21品目',
      [
        'アーモンド', 'あわび', 'いか', 'いくら', 'オレンジ',
        'カシューナッツ', 'キウイフルーツ', '牛肉', 'ごま', 'さけ',
        'さば', '大豆', '鶏肉', 'バナナ', '豚肉',
        'まつたけ', 'もも', 'やまいも', 'りんご', 'ゼラチン', 'マカダミアナッツ',
      ],
    ),
    (
      '🌐 EU & Other / EU・その他',
      ['セロリ', 'からし', '亜硫酸塩', 'ルパン', '魚類', 'とうもろこし', '植物油脂'],
    ),
  ];

  void _nextPage() {
    if (_currentPage == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showDisclaimerSheet();
    }
  }

  Future<void> _showDisclaimerSheet() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool analyticsConsent = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(ctx).padding.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 12),
                Text(
                  t('Important Notice', '重要なご注意', zh: '重要提示'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t(
                      'The allergen information provided by this app is for reference only and may not be 100% accurate or up to date.\n\nAlways check the actual product packaging before consumption. Do not rely solely on this app for severe or life-threatening allergies.',
                      'このアプリが提供するアレルゲン情報は参考用であり、正確性・最新性を保証しません。\n\nお召し上がり前に必ず商品パッケージの表示をご確認ください。重篤なアレルギーをお持ちの方は、このアプリのみに依存しないでください。',
                      zh: '本应用提供的过敏原信息仅供参考，不保证100%准确或最新。\n\n食用前请务必确认实际商品包装上的标注。严重过敏人群请勿仅依赖本应用。',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // Analytics consent toggle (opt-in, default off)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    value: analyticsConsent,
                    onChanged: (v) => setSheetState(() => analyticsConsent = v),
                    activeThumbColor: Colors.green,
                    title: Text(
                      t(
                        'Share anonymous scan statistics',
                        '匿名のスキャン統計を共有する',
                        zh: '共享匿名扫描统计',
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      t(
                        'No personal info included. Helps improve the app.',
                        '個人情報は含まれません。アプリ改善に役立てます。',
                        zh: '不含个人信息，用于改善应用。',
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, analyticsConsent),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      t('I Understand — Get Started 🚀', '理解しました — 始める 🚀', zh: '我已了解 — 开始使用 🚀'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != null) _finish(analyticsConsent: confirmed);
  }

  Future<void> _finish({bool analyticsConsent = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    await prefs.setBool('disclaimer_shown', true);
    await prefs.setBool('analytics_consent', analyticsConsent);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (_currentPage + 1) / 2,
                  minHeight: 4,
                  color: Colors.green,
                  backgroundColor: Colors.grey.shade200,
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [_buildLanguagePage(), _buildAllergenPage()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguagePage() {
    return Column(
      children: [
        // Gradient hero header — gives the screen personality
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
            ),
          ),
          child: const Column(
            children: [
              Icon(Icons.gpp_good_rounded, size: 64, color: Colors.white),
              SizedBox(height: 12),
              Text(
                'SafeEat Japan',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Safe food scanning for travelers in Japan',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              Text(
                '日本での食の安全をサポート',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose your language / 言語を選んでください / 请选择语言',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _langButton('English', 'en')),
                    const SizedBox(width: 8),
                    Expanded(child: _langButton('日本語', 'ja')),
                    const SizedBox(width: 8),
                    Expanded(child: _langButton('中文', 'zh')),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          child: _primaryButton(
            t('Choose My Allergens', 'アレルゲンを選ぶ', zh: '选择过敏原'),
            _nextPage,
          ),
        ),
      ],
    );
  }

  Widget _langButton(String label, String lang) {
    final isSelected = appLanguage.value == lang;
    return GestureDetector(
      onTap: () {
        appLanguage.value = lang;
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green.shade400 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.green.shade700 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllergenPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Select your allergens', 'アレルゲンを選択してください', zh: '选择您的过敏原'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t(
                  'You will be warned when a product contains them.\nYou can change this anytime in Settings.',
                  '商品に含まれる場合に警告が表示されます。\n設定からいつでも変更できます。',
                  zh: '检测到过敏原时会发出警告。\n可随时在设置中更改。',
                ),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: userAllergens,
            builder: (context, selected, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                children: _categories.map((cat) {
                  final (label, keys) = cat;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 6),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
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
                          final isSel = selected.contains(jp);
                          return FilterChip(
                            label: Text(
                              '$emoji $jp / $displayName',
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: isSel,
                            selectedColor: Colors.green.shade100,
                            checkmarkColor: Colors.green.shade700,
                            side: isSel
                                ? BorderSide(color: Colors.green.shade400)
                                : BorderSide(color: Colors.grey.shade300),
                            labelStyle: TextStyle(
                              color: isSel
                                  ? Colors.green.shade800
                                  : Colors.black87,
                              fontWeight: isSel
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
                              saveUserAllergens(newSet);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _primaryButton(
            t('Review & Start', '確認して始める'),
            _nextPage,
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
