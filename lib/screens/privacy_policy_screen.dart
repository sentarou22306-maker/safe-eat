import 'package:flutter/material.dart';
import '../theme_settings.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(t('Privacy Policy', 'プライバシーポリシー')),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(t('Privacy Policy', 'プライバシーポリシー')),
                _meta(t(
                  'Last updated: July 2026',
                  '最終更新日：2026年7月',
                )),
                const SizedBox(height: 8),
                _body(t(
                  'SafeEat Japan ("the App") is designed for international travelers checking food allergens in Japan. This policy explains what data the App collects, how it is used, and your rights.',
                  'SafeEat Japan（以下「本アプリ」）は、日本を訪れる外国人旅行者が食品のアレルゲンを確認するためのアプリです。本ポリシーでは、本アプリが収集するデータ、その利用方法、およびユーザーの権利について説明します。',
                )),

                _divider(),

                // 1. Data collected
                _section(t('1. Data Collected', '1. 収集するデータ')),

                _subSection(t('Stored locally on your device only', 'お使いの端末内のみに保存されるデータ')),
                _bullet(t('Allergen profile you select', '選択したアレルゲンプロフィール')),
                _bullet(t('App settings (language, text size, theme color)', 'アプリ設定（言語・文字サイズ・テーマカラー）')),
                _bullet(t('Recently viewed product history', '最近閲覧した商品の履歴')),
                _bullet(t('Your analytics consent preference', 'アナリティクス同意設定')),
                _body(t(
                  'This data never leaves your device unless you opt in to anonymous analytics below.',
                  'これらのデータは、以下の匿名アナリティクスにオプトインしない限り、端末外には送信されません。',
                )),

                const SizedBox(height: 12),
                _subSection(t(
                  'Sent to our servers only with your explicit consent',
                  '明示的な同意を得た場合にのみサーバーへ送信されるデータ',
                )),
                _bullet(t('Scan date (date only, no time)', 'スキャン日（日付のみ、時刻なし）')),
                _bullet(t('App language setting (used as a nationality proxy)', 'アプリの言語設定（国籍の参考情報として使用）')),
                _bullet(t('Your allergen profile (list of allergen names)', 'アレルゲンプロフィール（アレルゲン名のリスト）')),
                _bullet(t(
                  'Scan source (whether the product was found in our database, Open Food Facts, or via OCR)',
                  'スキャンのソース（自社データベース・Open Food Facts・OCRのいずれか）',
                )),
                _body(t(
                  'No name, email address, phone number, location, or device identifier is ever collected. You can opt out at any time in Settings → Privacy.',
                  '氏名・メールアドレス・電話番号・位置情報・端末識別子は一切収集しません。設定→プライバシーからいつでもオプトアウトできます。',
                )),

                _divider(),

                // 2. Not collected
                _section(t('2. What We Do NOT Collect', '2. 収集しないデータ')),
                _bullet(t('Name, address, phone number, or email', '氏名・住所・電話番号・メールアドレス')),
                _bullet(t('Location or GPS data', '位置情報・GPS')),
                _bullet(t('Device identifiers (IDFA, Android ID, etc.)', '端末識別子（IDFA、Android IDなど）')),
                _bullet(t(
                  'Photos — images are processed in memory for OCR and immediately discarded. They are not stored on our servers.',
                  '写真 — 画像はOCR処理のためにメモリ上で処理され、即座に破棄されます。サーバーには保存されません。',
                )),

                _divider(),

                // 3. How we use data
                _section(t('3. How We Use Data', '3. データの利用方法')),
                _body(t(
                  'Anonymous scan statistics (when consented) are aggregated and may be shared with business partners (e.g., hotels, food companies) as statistical reports. Individual records are never shared. Examples of aggregated insights:',
                  '匿名スキャン統計（同意した場合）は集計され、統計レポートとしてビジネスパートナー（ホテル、食品会社など）に共有される場合があります。個人のレコードは共有されません。集計インサイトの例：',
                )),
                _bullet(t(
                  '"38% of English-speaking users have an egg allergy"',
                  '「英語圏ユーザーの38%が卵アレルギーを持つ」',
                )),
                _bullet(t(
                  '"Peanut allergy is most common among users from the Americas"',
                  '「南北米大陸出身ユーザーに落花生アレルギーが多い」',
                )),

                _divider(),

                // 4. Third-party services
                _section(t('4. Third-Party Services', '4. 第三者サービス')),

                _subSection('Supabase'),
                _body(t(
                  'Product database and anonymous analytics storage. Data is stored in EU-region servers. Supabase Privacy Policy: supabase.com/privacy',
                  '商品データベースおよび匿名アナリティクスの保存に使用しています。データはEUリージョンのサーバーに保存されます。Supabaseプライバシーポリシー：supabase.com/privacy',
                )),

                const SizedBox(height: 10),
                _subSection('Google Cloud Vision API'),
                _body(t(
                  'Used for OCR text recognition on web. When you scan a label, the image is sent to Google\'s servers for text extraction only. Google does not store the image beyond the API call. Google Privacy Policy: policies.google.com/privacy',
                  'Web版のOCRテキスト認識に使用しています。ラベルをスキャンすると、テキスト抽出のためだけに画像がGoogleのサーバーに送信されます。GoogleはAPIコール後に画像を保持しません。GoogleプライバシーポリシーーのURL：policies.google.com/privacy',
                )),

                const SizedBox(height: 10),
                _subSection('Open Food Facts'),
                _body(t(
                  'Public food database used as a fallback when a product is not in our database. The JAN code is sent to their public API. No personal data is included. openfoodfacts.org',
                  '自社データベースにない商品の代替として使用する公開食品データベースです。JANコードが公開APIに送信されます。個人データは含まれません。openfoodfacts.org',
                )),

                _divider(),

                // 5. Your rights
                _section(t('5. Your Rights', '5. ユーザーの権利')),
                _bullet(t(
                  'Opt out of analytics at any time: Settings → Privacy → toggle off',
                  'アナリティクスのオプトアウト：設定→プライバシー→スイッチをオフ',
                )),
                _bullet(t(
                  'Delete local data: uninstall the app or clear app data from device settings',
                  'ローカルデータの削除：アプリをアンインストール、またはデバイス設定からアプリデータを消去',
                )),
                _bullet(t(
                  'EU users (GDPR): anonymous aggregated data is outside GDPR scope as it cannot identify any individual',
                  'EUユーザー（GDPR）：匿名集計データは個人を特定できないためGDPRの適用範囲外です',
                )),
                _bullet(t(
                  'Japan users (APPI): allergen profiles stored locally are not "personal information" as they contain no identifying details',
                  '日本在住ユーザー（個人情報保護法）：端末内に保存されるアレルゲンプロフィールは識別情報を含まないため個人情報に該当しません',
                )),

                _divider(),

                // 6. Data retention
                _section(t('6. Data Retention', '6. データ保存期間')),
                _body(t(
                  'Local data is retained until you uninstall the app. Anonymous analytics records are retained for up to 3 years for trend analysis, after which they are deleted.',
                  'ローカルデータはアプリをアンインストールするまで保持されます。匿名アナリティクスのレコードはトレンド分析のために最大3年間保持され、その後削除されます。',
                )),

                _divider(),

                // 7. Changes
                _section(t('7. Changes to This Policy', '7. ポリシーの変更')),
                _body(t(
                  'If this policy changes materially, the updated date at the top of this page will be updated. Continued use of the App after changes constitutes acceptance.',
                  'ポリシーに重要な変更がある場合、このページ上部の更新日が変更されます。変更後もアプリを継続利用することで、変更への同意とみなします。',
                )),

                _divider(),

                // 8. Contact
                _section(t('8. Contact', '8. お問い合わせ')),
                _body(t(
                  'For privacy-related questions, please contact:',
                  'プライバシーに関するお問い合わせはこちら：',
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
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
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );

  Widget _subSection(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );

  Widget _body(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
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
                style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
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
