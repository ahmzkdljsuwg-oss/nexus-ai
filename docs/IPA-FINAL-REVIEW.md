# NEXUS AI — مراجعة IPA ومسار التوقيع

**التاريخ:** 2026-11-15
**الفرع:** `lemon/expo-ios-ipa`
**Bundle ID:** `ai.nexus.app` — غير قابل للتغيير في هذا الإصدار

## 1. الحكم النهائي

| السؤال | النتيجة |
|---|---|
| هل `NEXUS-AI.ipa` تطبيق حقيقي مترجم؟ | نعم. تنفيذي Mach-O 64-bit لمعمارية arm64، وليس ملفاً نصياً أو حزمة فارغة |
| هل هو موقّع؟ | **لا.** لا يوجد `_CodeSignature`، ولا `LC_CODE_SIGNATURE`، ولا `embedded.mobileprovision` |
| هل هو جاهز لإعادة التوقيع عبر ESign؟ | نعم، بشرط استخدام شهادة وبروفايل يطابقان `ai.nexus.app` |
| هل يحتوي مفاتيح سرية؟ | لا |
| هل يعمل على iPhone فقط؟ | نعم، `UIDeviceFamily = [1]`، والحد الأدنى iOS 15.1 |
| هل البناء الموقّع جُرّب فعلياً؟ | لا. الكود والـ workflow مفحوصان، لكن التشغيل يحتاج أسرار التوقيع |

## 2. فحص الحزمة

| العنصر | القيمة |
|---|---|
| حجم IPA | 5,086,426 بايت |
| SHA-256 | `764b08b606de63226cca4c4ff563e192af4d823f627a2150a1977c954da5be22` |
| عدد المدخلات | 63 |
| سلامة الأرشيف | `zipfile.testzip()` أعاد `None` |
| المسار | `Payload/NEXUSAI.app/` |
| التنفيذي | `NEXUSAI` — 6,389,352 بايت |
| Mach-O | `0xcffaedfe` / arm64 / filetype 2 |
| `LC_CODE_SIGNATURE` | غير موجود |
| `LC_ENCRYPTION_INFO_64` | موجود، `cryptid = 0` (غير مشفّر) |
| Bundle ID | `ai.nexus.app` |
| الاسم المعروض | `NEXUS AI` |
| الاسم الداخلي | `NEXUSAI` |
| الإصدار | `1.0.0 (1)` |
| أدنى iOS | `15.1` |
| الأجهزة | iPhone فقط |
| الاتجاهات | Portrait + PortraitUpsideDown |
| Extensions | لا توجد |
| `Assets.car` | موجود، وأيقونات 120×120 و152×152 |
| `main.jsbundle` | 2,650,717 بايت |
| `apiBaseUrl` داخل الحزمة | فارغ — يُدخل رابط Railway من شاشة Settings |
| مفاتيح AIza / sk- / Bearer / PEM | غير موجودة |

> وجود `localhost` مرة واحدة داخل `main.jsbundle` هو عنوان React Native الداخلي، وليس عنوان Backend. لا يوجد عنوان افتراضي يوجّه التطبيق إلى خادم تجريبي.

## 3. مراجعة GitHub Actions

Workflow: `.github/workflows/expo-ios-signed.yml`

تم التحقق من:

- YAML صالح، و`actionlint` بلا ملاحظات.
- `macos-15`، Node 20، CocoaPods، بناء Release.
- قراءة الإصدار ورقم البناء من `app.json` وفرضهما على archive.
- التحقق من أن Bundle ID هو `ai.nexus.app`.
- رفض التشغيل إذا كانت الأسرار ناقصة.
- فك Base64 باستخدام `openssl` المتوفر على macOS.
- تثبيت WWDR G4/G3 تلقائياً وفحص سلسلة الشهادات.
- فحص وجود هوية `Apple Distribution` أو `Apple Development` داخل الـ p12.
- مطابقة Team وBundle ID ونوع البروفايل ووجود أجهزة مسجّلة.
- `codesign --verify --deep --strict` بعد التصدير.
- رفض التوقيع ad-hoc، وفحص `Authority=Apple`.
- فحص الإصدار ورقم البناء وUUID للبروفايل المدمج.
- إخراج artifact يحتوي IPA وSHA-256.

**ما لم يحدث:** لم يُشغّل هذا الـ workflow للبناء الموقّع، لأن الشهادة والبروفايل غير موجودين في مساحة العمل. لا يوجد ادعاء بأن التوقيع نجح.

## 4. الخطوات المتبقية بالترتيب

1. أضف UDID الخاص بـ iPhone في Apple Developer.
2. أنشئ App ID صريحاً: `ai.nexus.app`.
3. أنشئ شهادة `Apple Distribution` (لـ Ad Hoc) أو `Apple Development`.
4. أنشئ Provisioning Profile من نوع Ad Hoc أو Development لهذا App ID.
5. ضع القيم الأربعة في GitHub Secrets كما في `docs/SIGNING.md`.
6. شغّل **Build Signed Expo iOS App** واختر `ad-hoc`.
7. نزّل `NEXUSAI-signed-ipa` وتحقق من ملف `.sha256`.
8. ثبّت على الجهاز عبر ESign أو الأداة المناسبة.
9. أدخل رابط Railway الإنتاجي في Settings داخل التطبيق.
10. اختبر الاتصال والأسواق والتوصيات على الجهاز.

لا ترسل أي شهادة أو كلمة مرور في المحادثة.

## 5. القيود المعروفة

- لا يوجد Backend منشور على Railway بعد، لذلك `apiBaseUrl` فارغ.
- لا توجد مفاتيح إنتاجية لـ Gemini أو Mistral أو Twelve Data.
- لا يوجد جسر ExpertOption/MT5 حقيقي للأسواق الستة غير FOREX.
- لم يُختبر التطبيق على جهاز أو محاكي.
- لم يُختبر تثبيت ESign فعلياً.
