# SafeEat Japan

**Allergen-checking PWA for international travelers in Japan**

SafeEat Japan lets travelers scan any Japanese product barcode and instantly see whether it contains their personal allergens — in English or Japanese. When a product isn't in any database, it falls back to on-device OCR that reads the ingredient label directly from the camera.

**Live demo:** https://sentarou22306-maker.github.io/safe-eat/

---

## Features

| Feature | Detail |
|---|---|
| Barcode scan | Real-time camera scan via `mobile_scanner` |
| Allergen profile | 36 allergens across 4 categories (JP mandatory 8, recommended 21, EU additions, other) |
| Custom allergens | Users can add free-text allergens (e.g. garlic, MSG) |
| Bilingual matching | Detects allergens written in both Japanese and English in ingredient lists |
| Cross-contamination detection | Flags sentences containing words like 「を含む製品と共通の設備」 |
| Unspecified vegetable oil | Special warning when 「植物油脂」 appears without specification |
| OCR fallback | Products absent from all databases are scanned via camera + Google Cloud Vision API |
| Safety banner | Full-width red/green banner on the result screen based on the user's profile |
| Onboarding | 2-step setup: language selection → allergen selection (with one-time disclaimer bottom sheet) |
| Settings | Allergen profile, language, text size, theme color — all persisted across sessions |
| History | Recently viewed products on the home screen |

---

## Tech Stack

### Frontend
- **Flutter** (Dart) — single codebase targeting web (PWA) and mobile
- **go_router** — declarative navigation with `ShellRoute` for the bottom nav bar
- **ValueNotifier + ValueListenableBuilder** — lightweight reactive state without an external state management library
- **shared_preferences** — local persistence for allergen profiles and app settings
- **mobile_scanner** — real-time barcode detection
- **google_mlkit_text_recognition** — on-device OCR (Japanese) for mobile
- **flutter_dotenv** — runtime API key loading from `.env`

### Backend / External APIs
- **Supabase** (Postgres + Storage) — primary product database with Row Level Security; allergen correction table for community fixes
- **Open Food Facts API** — fallback for products not yet in the Supabase DB
- **Google Cloud Vision API** — cloud OCR for web platform (supports Japanese + English)

### DevOps
- **GitHub Actions** — builds Flutter web on every push to `main`; injects API key from GitHub Secrets into `.env` at build time
- **GitHub Pages** — static hosting; deploy step via `peaceiris/actions-gh-pages`

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter App                          │
│                                                             │
│  ┌──────────┐   ┌──────────────┐   ┌──────────────────┐   │
│  │  Home    │   │  Scan screen │   │  Product Detail  │   │
│  │  screen  │   │              │   │  screen          │   │
│  │          │   │ MobileScanner│   │                  │   │
│  │  History │   │ (barcode)    │   │ Safety banner    │   │
│  └──────────┘   └──────┬───────┘   │ Allergen chips   │   │
│                        │           │ OCR verify btn   │   │
│            ┌───────────┴────────┐  └──────────────────┘   │
│            │  _searchProduct()  │                          │
│            └───────────┬────────┘                          │
│                        │                                   │
│           ┌────────────┼────────────┐                      │
│           ▼            ▼            ▼                      │
│      Supabase      Open Food     OCR Service               │
│      (primary)     Facts API     (fallback)                │
│                    (fallback)                              │
│                                  ┌──────────┬──────────┐  │
│                                  │  ML Kit  │ GCV API  │  │
│                                  │ (mobile) │  (web)   │  │
│                                  └──────────┴──────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Key design decisions

**No heavy state management** — all shared state lives in `theme_settings.dart` as top-level `ValueNotifier<T>` instances. Every widget that needs reactive updates wraps in `ValueListenableBuilder`. This is intentionally simple: there are no complex async state transitions that would justify BLoC or Riverpod.

**Platform branching for OCR** — `kIsWeb` switches between ML Kit (on-device, mobile) and Google Cloud Vision (HTTP, web). The `ocr_service.dart` module exposes two functions; the scan screen picks the right one.

**Allergen matching in both languages** — `allergenDictionary` maps each Japanese key to an English translation. Matching checks both `text.contains(jpKey)` and `text.toLowerCase().contains(enTranslation)`, so it catches ingredient lists written in either language.

**API key security** — the key is never committed. Locally it lives in `.env` (gitignored). In CI, the `Create .env file` step writes it from a GitHub Secret before the build runs.

---

## Project Structure

```
lib/
├── main.dart                  # App entry, router setup, global init
├── theme_settings.dart        # All ValueNotifiers + allergen dictionary
├── screens/
│   ├── onboarding_screen.dart # Language + allergen setup (first launch)
│   ├── barcode_scan_screen.dart
│   ├── product_detail_screen.dart
│   ├── settings_screen.dart
│   └── allergen_report_screen.dart
└── services/
    └── ocr_service.dart       # ML Kit (mobile) + Cloud Vision (web) OCR
```

---

## Local Setup

**Prerequisites:** Flutter SDK ≥ 3.10, a Supabase project, a Google Cloud Vision API key.

```bash
git clone https://github.com/sentarou22306-maker/safe-eat.git
cd safe-eat
flutter pub get
```

Create a `.env` file in the project root (never commit this):

```
GOOGLE_VISION_API_KEY=your_key_here
```

Run on Chrome:

```bash
flutter run -d chrome
```

Run on a connected mobile device:

```bash
flutter run
```

### Supabase schema (minimum)

```sql
create table products (
  id uuid primary key default gen_random_uuid(),
  jan_code text not null,
  name_jp text,
  name_en text,
  image_url text,
  allergens text[],
  is_approved boolean default false
);

create table allergen_corrections (
  id uuid primary key default gen_random_uuid(),
  jan_code text not null,
  allergens text[],
  is_approved boolean default false
);
```

---

## CI/CD

Every push to `main` triggers `.github/workflows/deploy.yml`:

1. Checkout → Setup Flutter → **Inject API key from GitHub Secret into `.env`** → `flutter pub get` → `flutter build web --release` → Deploy to GitHub Pages

The `GOOGLE_VISION_API_KEY` secret is set in the repository's Settings → Secrets. The key is never present in any committed file.

---

## Allergen Reference

The app covers 36 allergens with Japanese/English bilingual detection:

| Category | Items |
|---|---|
| 🇯🇵 Mandatory 8 | 卵, 乳成分, 小麦, そば, 落花生, えび, かに, くるみ |
| 🇯🇵 Recommended 21 | アーモンド, あわび, いか, いくら, オレンジ, カシューナッツ, キウイフルーツ, 牛肉, ごま, さけ, さば, 大豆, 鶏肉, バナナ, 豚肉, まつたけ, もも, やまいも, りんご, ゼラチン, マカダミアナッツ |
| 🇪🇺 EU Additions | セロリ, からし, 亜硫酸塩, ルパン |
| 🌐 Other | 魚類, とうもろこし, 植物油脂 |

---

## License

MIT
