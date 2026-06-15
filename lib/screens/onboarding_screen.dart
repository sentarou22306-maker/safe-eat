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
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    await prefs.setBool('disclaimer_shown', true);
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
                  value: (_currentPage + 1) / 3,
                  minHeight: 4,
                  color: appThemeColor.value,
                  backgroundColor: Colors.grey.shade200,
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _buildLanguagePage(),
                      _buildAllergenPage(),
                      _buildDisclaimerPage(),
                    ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gpp_good_rounded, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            'SafeEat Japan',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Safe food scanning for travelers in Japan\n日本での食の安全をサポート',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          Text(
            'Choose your language / 言語を選んでください',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _langButton('English', 'en')),
              const SizedBox(width: 16),
              Expanded(child: _langButton('日本語', 'ja')),
            ],
          ),
          const SizedBox(height: 40),
          _nextButton(),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? appThemeColor.value : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? appThemeColor.value : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllergenPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Select your allergens', 'アレルゲンを選択'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                t(
                  'You will be warned when a product contains them.\nYou can change this anytime in Settings.',
                  '商品に含まれる場合に警告が表示されます。\n設定からいつでも変更できます。',
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
                          final en = info['en']!;
                          final emoji = info['emoji']!;
                          final isSel = selected.contains(jp);
                          return FilterChip(
                            label: Text(
                              '$emoji $jp / $en',
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: isSel,
                            selectedColor: Colors.red.shade100,
                            checkmarkColor: Colors.red,
                            side: isSel
                                ? BorderSide(color: Colors.red.shade300)
                                : BorderSide(color: Colors.grey.shade300),
                            labelStyle: TextStyle(
                              color: isSel ? Colors.red.shade800 : Colors.black87,
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.normal,
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
          child: _nextButton(),
        ),
      ],
    );
  }

  Widget _buildDisclaimerPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade500),
          const SizedBox(height: 20),
          Text(
            t('Important Notice', '重要なご注意'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              t(
                'The allergen information provided by this app is for reference only and may not be 100% accurate or up to date.\n\nAlways check the actual product packaging before consumption. Do not rely solely on this app for severe or life-threatening allergies.',
                'このアプリが提供するアレルゲン情報は参考用であり、正確性・最新性を保証しません。\n\nお召し上がり前に必ず商品パッケージの表示をご確認ください。重篤なアレルギーをお持ちの方は、このアプリのみに依存しないでください。',
              ),
              style: const TextStyle(fontSize: 13, height: 1.7, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                t('I Understand — Get Started 🚀', '理解しました — 始める 🚀'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _nextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: appThemeColor.value,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          t('Next →', '次へ →'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
