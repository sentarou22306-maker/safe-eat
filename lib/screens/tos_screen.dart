import 'package:flutter/material.dart';
import '../theme_settings.dart';

class TosScreen extends StatelessWidget {
  const TosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(t('Terms of Service', '利用規約')),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(t('Terms of Service', '利用規約')),
                _meta(t('Last updated: July 2026', '最終更新日：2026年7月')),
                const SizedBox(height: 8),
                _body(t(
                  'By using SafeEat Japan ("the App"), you agree to these Terms. Please read them carefully before use.',
                  'SafeEat Japan（以下「本アプリ」）をご利用いただくことで、以下の利用規約に同意したものとみなされます。ご利用前に必ずお読みください。',
                )),

                _divider(),

                _section(t('1. Service Overview', '1. サービス概要')),
                _body(t(
                  'SafeEat Japan is an allergen-checking reference tool designed to assist international travelers visiting Japan. It searches product databases and scans ingredient labels to help identify potential allergens.',
                  'SafeEat Japanは、日本を訪れる外国人旅行者向けのアレルゲン確認補助ツールです。商品データベースの検索および成分ラベルのスキャンにより、含有アレルゲンの特定を支援します。',
                )),

                _divider(),

                _section(t('2. Not Medical Advice', '2. 医療目的ではありません')),
                _body(t(
                  'The App provides allergen information for reference only. It is NOT a substitute for medical advice, professional allergy diagnosis, or treatment.',
                  '本アプリが提供するアレルゲン情報は参考目的のみです。医療上のアドバイス、専門的なアレルギー診断、または治療の代替となるものではありません。',
                )),
                _body(t(
                  'If you have severe allergies or a diagnosed medical condition, consult a qualified healthcare professional before relying on this App.',
                  '重篤なアレルギーや診断された疾患をお持ちの方は、本アプリに依存する前に医療専門家にご相談ください。',
                )),

                _divider(),

                _section(t('3. Data Accuracy', '3. 情報の正確性')),
                _body(t(
                  'We strive to maintain accurate allergen data, but we cannot guarantee that all information is complete, current, or free from error. Product formulations change over time, and OCR scanning may misread label text.',
                  '正確なアレルゲン情報の提供に努めますが、全ての情報が完全・最新・正確であることを保証することはできません。商品の原材料は変更される場合があり、OCRスキャンがラベルのテキストを誤読することがあります。',
                )),
                _warning(t(
                  '⚠ Always verify by checking the actual product packaging before consuming any food.',
                  '⚠ 食品を摂取する前に必ず実際の商品パッケージの表示を直接ご確認ください。',
                )),

                _divider(),

                _section(t('4. User Responsibilities', '4. ユーザーの責任')),
                _bullet(t(
                  'Always read the actual product label before consuming food.',
                  '食品摂取前に必ず実際の商品ラベルを確認してください。',
                )),
                _bullet(t(
                  'Do not rely solely on this App for allergy-critical decisions.',
                  'アレルギーに関わる重要な判断を本アプリのみに頼らないでください。',
                )),
                _bullet(t(
                  'Keep your allergen profile accurate and up to date.',
                  'アレルゲンプロフィールを正確・最新の状態に保ってください。',
                )),
                _bullet(t(
                  'You are responsible for any decisions made based on the App\'s information.',
                  '本アプリの情報に基づいて行ったいかなる判断についても、ユーザー自身が責任を負います。',
                )),

                _divider(),

                _section(t('5. No Warranty', '5. 無保証')),
                _body(t(
                  'The App is provided "as is" and "as available" without any warranty, express or implied, including warranties of merchantability, fitness for a particular purpose, or non-infringement.',
                  '本アプリは「現状有姿」かつ「現状提供」で提供され、商品性、特定目的への適合性、または非侵害性についての黙示の保証を含む、明示または黙示のいかなる保証も行いません。',
                )),

                _divider(),

                _section(t('6. Limitation of Liability', '6. 責任の制限')),
                _body(t(
                  'To the maximum extent permitted by law, the developer shall not be liable for any direct, indirect, incidental, special, or consequential damages arising from your use of or inability to use the App — including but not limited to allergic reactions resulting from reliance on information provided by the App.',
                  '適用法の最大限の範囲において、開発者は本アプリの利用または利用不能に起因するいかなる直接的・間接的・付随的・特別または結果的損害についても責任を負いません。これには、本アプリが提供する情報への依存から生じるアレルギー反応による損害を含みます。',
                )),

                _divider(),

                _section(t('7. Third-Party Services', '7. 第三者サービス')),
                _body(t(
                  'The App uses third-party services including Supabase, Google Cloud Vision API, and Open Food Facts. Your use of those services is also subject to their respective terms and privacy policies.',
                  '本アプリはSupabase、Google Cloud Vision API、Open Food Factsを含む第三者サービスを利用しています。これらのサービスの利用は、各サービスの利用規約およびプライバシーポリシーにも準拠します。',
                )),

                _divider(),

                _section(t('8. Changes to Terms', '8. 規約の変更')),
                _body(t(
                  'We may update these Terms at any time. The "Last updated" date at the top of this page reflects changes. Continued use of the App after changes constitutes acceptance of the revised Terms.',
                  '本規約はいつでも更新される場合があります。このページ上部の「最終更新日」に変更が反映されます。変更後もアプリを継続利用することで、改定された規約への同意とみなします。',
                )),

                _divider(),

                _section(t('9. Governing Law', '9. 準拠法')),
                _body(t(
                  'These Terms are governed by the laws of Japan. Any disputes arising from the use of the App shall be subject to the exclusive jurisdiction of the courts of Japan.',
                  '本規約は日本法に準拠します。本アプリの利用に起因する紛争については、日本の裁判所を専属的合意管轄とします。',
                )),

                _divider(),

                _section(t('10. Contact', '10. お問い合わせ')),
                _body(t(
                  'For questions about these Terms, please contact:',
                  '本規約についてのお問い合わせはこちら：',
                )),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'sentarou22306@gmail.com',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      );

  Widget _meta(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );

  Widget _body(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
        ),
      );

  Widget _warning(String text) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            fontWeight: FontWeight.bold,
            color: Colors.amber.shade900,
          ),
        ),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 13, height: 1.6)),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 13, height: 1.6, color: Colors.black87),
              ),
            ),
          ],
        ),
      );

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(thickness: 1),
      );
}
