import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_settings.dart';

import 'screens/barcode_scan_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/allergen_report_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();
late final GoRouter _router;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://nzzenffzsohmbnoscfvx.supabase.co',
    publishableKey: 'sb_publishable_sRZAzxUNJlsRHcWjxYT3Ew_m1iuEPLq',
  );
  await loadAppSettings();
  await loadGlobalHistory();
  await loadUserAllergens();
  await loadCustomAllergens();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: onboardingDone ? '/' : '/onboarding',
    routes: [
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return ScaffoldWithNavBar(child: child);
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/barcode_scan',
            builder: (context, state) => const BarcodeScanScreen(),
          ),
          GoRoute(
            path: '/allergen_report',
            builder: (context, state) {
              final janCode = state.extra as String? ?? '';
              return AllergenReportScreen(initialJanCode: janCode);
            },
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/product_detail',
        builder: (context, state) {
          final product = state.extra as Map<String, dynamic>? ?? {};
          return ProductDetailScreen(product: product);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appThemeColor,
      builder: (context, color, child) {
        return ValueListenableBuilder<double>(
          valueListenable: appTextScale,
          builder: (context, scale, child) {
            return MaterialApp.router(
              title: 'SafeEat Japan',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: color,
                  primary: color,
                ),
                appBarTheme: AppBarTheme(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                bottomNavigationBarTheme: BottomNavigationBarThemeData(
                  selectedItemColor: color,
                ),
              ),
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                );
              },
              routerConfig: _router,
            );
          },
        );
      },
    );
  }
}

class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 🌟 ここに言語を監視するカメラを追加！
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          body: child,
          bottomNavigationBar: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: t('Home', 'ホーム'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.qr_code_scanner),
                label: t('Scan', 'スキャン'),
              ),
            ],
            currentIndex: _calculateSelectedIndex(context),
            onTap: (int idx) => _onItemTapped(idx, context),
            selectedItemColor: appThemeColor.value,
            unselectedItemColor: Colors.grey,
          ),
        );
      },
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/barcode_scan')) return 1;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/barcode_scan');
        break;
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'SafeEat Japan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            actions: [buildGlobalSettingsButton(context)],
          ),
          body: Column(
            children: [
              ValueListenableBuilder<Set<String>>(
                valueListenable: userAllergens,
                builder: (context, allergens, _) {
                  if (allergens.isNotEmpty || customAllergens.value.isNotEmpty) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t(
                                'No allergens set. Tap to set your profile.',
                                'アレルゲンが未設定です。タップして設定してください。',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.amber.shade800,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                flex: 4,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.gpp_good_rounded,
                        size: 100,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'SafeEat Japan',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'For International Travelers',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 48),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/barcode_scan'),
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 24,
                        ),
                        label: Text(
                          t('Scan Barcode', 'バーコードをスキャン'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          backgroundColor: appThemeColor.value,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 24,
                          top: 24,
                          bottom: 16,
                        ),
                        child: Text(
                          t('Recently Viewed', '最近見たお土産'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Expanded(
                        child:
                            ValueListenableBuilder<List<Map<String, dynamic>>>(
                              valueListenable: globalHistory,
                              builder: (context, history, child) {
                                if (history.isEmpty) {
                                  return Center(
                                    child: Text(
                                      t('No history yet.', 'まだ履歴はありません。'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: history.length,
                                  itemBuilder: (context, index) {
                                    final item = history[index];
                                    final imageUrl =
                                        item['image_front']?.toString() ??
                                        item['image']?.toString() ??
                                        '';
                                    final name =
                                        item['name_jp']?.toString() ??
                                        'Unknown';

                                    return GestureDetector(
                                      onTap: () => context.push(
                                        '/product_detail',
                                        extra: item,
                                      ),
                                      child: Container(
                                        width: 130,
                                        margin: const EdgeInsets.only(
                                          left: 8,
                                          right: 8,
                                          bottom: 24,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(16),
                                                    ),
                                                child: imageUrl.isNotEmpty
                                                    ? Image.network(
                                                        imageUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              c,
                                                              e,
                                                              s,
                                                            ) => const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        size: 40,
                                                        color: Colors.grey,
                                                      ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                12.0,
                                              ),
                                              child: Text(
                                                name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.grey.shade200,
                child: Text(
                  t(
                    'Allergy info is for reference only. Always check the actual product label.',
                    'アレルギー情報は参考用です。必ず商品パッケージの表示をご確認ください。',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
