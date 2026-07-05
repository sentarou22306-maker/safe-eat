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

  // Page 2: disclaimer
  bool _disclaimerChecked = false;
  bool _analyticsConsent = false;

  static const _totalPages = 3;

  static const _allergenCategories = [
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

  void _goNext() {
    if (_currentPage < _totalPages - 1) {
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
    await prefs.setBool('analytics_consent', _analyticsConsent);
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
                _buildProgressBar(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _buildLanguagePage(),
                      _buildDisclaimerPage(),
                      _buildAllergenPage(),
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

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(_totalPages, (i) {
          final active = i <= _currentPage;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < _totalPages - 1 ? 6 : 0),
              decoration: BoxDecoration(
                color: active ? Colors.green : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Page 1: Language ──────────────────────────────────────────

  Widget _buildLanguagePage() {
    return Column(
      children: [
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
                '日本での食の安全をサポート  /  일본 여행자를 위한 식품 안전 앱',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white70),
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
                  'Choose your language / 言語を選んでください / 请选择语言 / 언어를 선택하세요',
                  style: TextStyle(
                    fontSize: 13,
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
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _langButton('中文', 'zh')),
                    const SizedBox(width: 8),
                    Expanded(child: _langButton('한국어', 'ko')),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          child: _primaryButton(
            t('Next', '次へ', zh: '下一步', ko: '다음'),
            _goNext,
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
              Icon(Icons.check_circle_rounded,
                  size: 16, color: Colors.green.shade600),
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

  // ── Page 2: Disclaimer ────────────────────────────────────────

  Widget _buildDisclaimerPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.shade300, width: 2),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  size: 40, color: Colors.amber.shade700),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              t('Before you start', '始める前に', zh: '使用前须知', ko: '시작 전에'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              t('Please read carefully', 'よくお読みください',
                  zh: '请仔细阅读', ko: '주의 깊게 읽어주세요'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              children: [
                _disclaimerPoint(
                  Icons.search_outlined,
                  t('Results are for reference only.',
                      '結果は参考情報です。',
                      zh: '结果仅供参考。',
                      ko: '결과는 참고 정보입니다.'),
                  t('Allergen data may be incomplete or outdated. Always verify with the actual product label.',
                      'アレルゲンデータが不完全・古い場合があります。必ず実際のラベルで確認してください。',
                      zh: '过敏原数据可能不完整或已过时，请务必核对实际商品标签。',
                      ko: '알레르겐 데이터가 불완전하거나 오래되었을 수 있습니다. 반드시 실제 라벨로 확인하세요.'),
                ),
                const Divider(height: 20),
                _disclaimerPoint(
                  Icons.camera_alt_outlined,
                  t('Label scans can make mistakes.',
                      'ラベルスキャンには誤読があります。',
                      zh: '标签扫描可能出现误读。',
                      ko: '라벨 스캔은 오독이 생길 수 있습니다.'),
                  t('Camera OCR may fail on small text, poor lighting, or unusual fonts. The result is not a guarantee.',
                      '小さい文字・暗い環境・特殊フォントでは正確に読み取れないことがあります。',
                      zh: '小字、光线不足或特殊字体可能导致读取失败，结果不作任何保证。',
                      ko: '작은 글씨, 어두운 환경, 특수 폰트에서는 정확하게 읽지 못할 수 있습니다.'),
                ),
                const Divider(height: 20),
                _disclaimerPoint(
                  Icons.personal_injury_outlined,
                  t('Severe allergies: always ask staff.',
                      '重篤なアレルギーは必ず店員に確認を。',
                      zh: '严重过敏者：请务必询问工作人员。',
                      ko: '중증 알레르기: 반드시 직원에게 확인하세요.'),
                  t('If a reaction could be life-threatening, ask a store employee to check the label for you.',
                      'アナフィラキシーなど重篤なリスクがある方は、このアプリのみに頼らず、店員に直接確認してもらってください。',
                      zh: '如过敏反应可能危及生命，请务必请工作人员帮您核对标签，切勿仅依赖本应用。',
                      ko: '아나필락시스 등 중증 위험이 있는 분은 직원에게 라벨 확인을 요청하세요.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 必須チェックボックス
          GestureDetector(
            onTap: () =>
                setState(() => _disclaimerChecked = !_disclaimerChecked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _disclaimerChecked
                    ? Colors.green.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _disclaimerChecked
                      ? Colors.green.shade400
                      : Colors.grey.shade300,
                  width: _disclaimerChecked ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _disclaimerChecked
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: _disclaimerChecked
                        ? Colors.green.shade600
                        : Colors.grey.shade400,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t('I understand this app is for reference only, and I will always check the actual product label.',
                          'このアプリは参考用であり、実際のラベルを必ず確認することを理解しました。',
                          zh: '我理解本应用仅供参考，并将始终核对实际商品标签。',
                          ko: '이 앱은 참고용이며, 반드시 실제 라벨을 확인할 것을 이해했습니다.'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _disclaimerChecked
                            ? Colors.green.shade800
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // アナリティクス同意（任意）
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              value: _analyticsConsent,
              onChanged: (v) => setState(() => _analyticsConsent = v),
              activeThumbColor: Colors.green,
              title: Text(
                t('Share anonymous scan statistics',
                    '匿名のスキャン統計を共有する',
                    zh: '共享匿名扫描统计',
                    ko: '익명 스캔 통계 공유'),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                t('No personal info included. Helps improve the app.',
                    '個人情報は含まれません。アプリ改善に役立てます。',
                    zh: '不含个人信息，用于改善应用。',
                    ko: '개인정보는 포함되지 않습니다. 앱 개선에 활용됩니다.'),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _primaryButton(
            t('I Understand — Next', '理解しました — 次へ',
                zh: '我已了解 — 下一步', ko: '이해했습니다 — 다음'),
            _disclaimerChecked ? _goNext : null,
          ),
        ],
      ),
    );
  }

  Widget _disclaimerPoint(IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.amber.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.amber.shade900)),
              const SizedBox(height: 3),
              Text(body,
                  style: TextStyle(
                      fontSize: 12, height: 1.5, color: Colors.amber.shade800)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Page 3: Allergens ─────────────────────────────────────────

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
                t('Select your allergens', 'アレルゲンを選択してください',
                    zh: '选择您的过敏原', ko: '알레르겐을 선택하세요'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t('You will be warned when a product contains them.\nYou can change this anytime in Settings.',
                    '商品に含まれる場合に警告が表示されます。\n設定からいつでも変更できます。',
                    zh: '检测到过敏原时会发出警告。\n可随时在设置中更改。',
                    ko: '제품에 포함된 경우 경고가 표시됩니다.\n설정에서 언제든지 변경할 수 있습니다.'),
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
                children: _allergenCategories.map((cat) {
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
                          final displayName =
                              info[appLanguage.value] ?? info['en']!;
                          final emoji = info['emoji']!;
                          final isSel = selected.contains(jp);
                          return FilterChip(
                            label: Text('$emoji $jp / $displayName',
                                style: const TextStyle(fontSize: 12)),
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
                              val ? newSet.add(jp) : newSet.remove(jp);
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
          child: Column(
            children: [
              _primaryButton(
                t('Save & Start', '保存して始める', zh: '保存并开始', ko: '저장하고 시작'),
                _finish,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _finish,
                child: Text(
                  t('Skip for now — set later in Settings',
                      'スキップ — あとで設定から変更できます',
                      zh: '暂时跳过 — 稍后可在设置中更改',
                      ko: '지금은 건너뛰기 — 나중에 설정에서 변경 가능'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
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
