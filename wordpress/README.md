# بيئة وردبريس + إليمنتور محلية

سكريبتات تبني موقع WordPress كامل مع Elementor وثيم Hello Elementor وكيت
"Client Dossier" جاهز — من غير MySQL ومن غير الاتصال بـ `wordpress.org`.

## التشغيل

```bash
cd wordpress
./setup.sh          # يبني كل حاجة من الصفر (بياخد وقت — Elementor بيتبني من السورس)
./bin/serve.sh      # يشغّل السيرفر
```

| | |
|---|---|
| الموقع | http://127.0.0.1:8080 |
| لوحة التحكم | http://127.0.0.1:8080/wp-admin/ |
| المستخدم | `admin` / `admin123` |

`site/` مستثناة من git — بتتولد من `setup.sh`.

## المكوّنات

| المكوّن | الإصدار | المصدر |
|---|---|---|
| WordPress | 6.9 | `github.com/WordPress/WordPress` |
| SQLite Database Integration | 3.0.2 | `github.com/WordPress/sqlite-database-integration` |
| Elementor | 3.35.9 | `github.com/elementor/elementor` (مبني من السورس) |
| Hello Elementor | 3.5.1 | `github.com/elementor/hello-theme` (مبني من السورس) |

## ليه من GitHub ومش من wordpress.org؟

سياسة الشبكة في بيئة التشغيل دي بتحجب:

- `wordpress.org` و `downloads.wordpress.org` و `api.wordpress.org`
- `composer.elementor.com`
- `assets.elementor.com` و `api.elementor.com` و `my.elementor.com`

عشان كده كل حاجة بتتجاب من GitHub وبتتبني محليًا بـ npm. النتيجة موقع
كامل شغّال، مع استثناءين:

1. **مكتبة الكيتس جوه إليمنتور (Kit Library) مش هتفتح** — بتقرأ من سيرفرات
   إليمنتور المحجوبة. الاستيراد من ملف `.zip` محلي شغال عادي (`bin/kit-import.php`).
2. **`composer install` بتتخطى** — الباكدج `elementor/wp-one-package` على
   ريبو إليمنتور الخاص المحجوب. إليمنتور بيلف حول `vendor/autoload.php`
   بـ `file_exists()`، والكود الوحيد اللي محتاج نسخة Twig المعزولة موجود جوه
   تجربة `e_atomic_elements` وهي مطفية افتراضيًا.

## قاعدة البيانات

مفيش MySQL في البيئة، فالموقع شغّال على SQLite عن طريق الـ drop-in الرسمي
(`wp-content/db.php`). قاعدة البيانات ملف واحد في `site/wp-content/database/`.

## السكريبتات

| السكريبت | الوظيفة |
|---|---|
| `setup.sh` | يبني الموقع كله من الصفر |
| `bin/serve.sh [port]` | يشغّل/يعيد تشغيل سيرفر PHP المدمج |
| `bin/router.php` | راوتر عشان الروابط الدائمة (permalinks) تشتغل مع `php -S` |
| `bin/install.php` | يعمل تنصيب وردبريس (يقرأ `WP_TITLE` و`WP_ADMIN_USER` و`WP_ADMIN_PASS` و`WP_ADMIN_EMAIL`) |
| `bin/activate.php` | يفعّل الإضافات والثيم ويظبط الروابط الدائمة |
| `bin/kit-setup.php` | يبني كيت "Client Dossier" (ألوان وخطوط عامة + إعدادات تخطيط) |
| `bin/kit-export.php` | يصدّر الكيت الحالي كملف `.zip` |
| `bin/kit-import.php` | يستورد أي كيت `.zip` (`php bin/kit-import.php kit.zip`) |

سكريبتات الـ PHP اللي محتاجة صلاحيات أدمن بتتشغّل بـ `WP_USER_ID=1` قدامها.

## الكيت

`kits/client-dossier-kit.zip` — كيت جاهز للاستيراد على أي موقع وردبريس فيه
إليمنتور (Elementor → Tools → Import / Export Kit). محتواه مأخوذ من لوحة
ألوان `index.html` بتاعة الدوسيه:

**ألوان النظام:** Copper `#B0602E` · Steel `#2F5559` · Ink `#1B2420` · Ochre `#C98A2E`

**ألوان مخصصة:** Paper `#F4F3EE` · Ink Soft `#26332D` · Copper Dark `#8F4C22` ·
Muted `#5C645F` · Line `#DCD9D0` · Success `#2F6B4F` · Danger `#A63A2C`

**الخطوط:** IBM Plex Sans Arabic (عناوين ونصوص) · IBM Plex Mono (تسميات)

## mu-plugins

| الملف | السبب |
|---|---|
| `00-local-sandbox.php` | يوقف فحص التحديثات (بيعلّق لوحة التحكم لأن `api.wordpress.org` محجوب) ويوقف تحويل الإيموجي لصور من `s.w.org` |
| `10-elementor-offline.php` | يدّي شاشة Home بتاعة إليمنتور بيانات فاضية سليمة الشكل — من غيرها بيحصل fatal لما الـ API بترجع `null` |
| `20-cli-user.php` | يحدّد المستخدم الحالي من `WP_USER_ID` وقت التشغيل من الـ CLI، لأن إليمنتور بيسجّل مكوّنات الاستيراد/التصدير وقت تحميل الإضافة لمستخدم عنده `manage_options` |
