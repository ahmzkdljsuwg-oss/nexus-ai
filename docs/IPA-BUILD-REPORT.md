# NEXUS AI — تقرير بناء IPA

التاريخ: 2026-11-15  
الفرع: `lemon/expo-ios-ipa`  
Commit: `bae005d`  
GitHub Actions Run: [43714673687](https://github.com/ahmzkdljsuwg-oss/nexus-ai/actions/runs/43714673687)

## 1. الملفات المفحوصة

| الملف المرفق | النتيجة |
|---|---|
| `NEXUS-AI-Project.zip` | نسخة تجريبية صغيرة (5 شاشات تعليمية، لا Backend، ولا محرك تحليل، وتحتوي ثابت `OPENAI_API_KEY` غير مستخدم). لم تُستخدم كأساس لأنها لا تحتوي وظائف NEXUS AI الفعلية. |
| `NEXUS-AI.ipa` السابق | حزمة 25 KB تحتوي `NexusAI.app` وملفاً باسم `NexusAI` حجمه 58 بايت نصه `NEXUS_AI_BINARY_PLACEHOLDER`. **ليست تطبيقاً مترجماً**، وBundle ID فيها `com.nexus.ai` وليس `ai.nexus.app`. |

لم يصل أي ملف IPA لـ Snapchat إلى مساحة العمل، لذلك لم يُفحص. لم يُنسخ أي كود أو هوية أو شهادة من أي تطبيق آخر.

## 2. المصدر المستخدم

المشروع الحقيقي `nexus-ai-trading` (FastAPI + Expo/React Native) هو الذي يحتوي:

- الأسواق السبعة المنفصلة.
- تحليل الشموع وSMC وAlligator/MA 200.
- توصيات وسجل وإحصاءات.
- Gemini للدردشة، Gemini + Mistral للتحليل.
- واجهة عربية/إنجليزية.
- إعداد Backend URL داخل التطبيق، دون أي مفتاح سري.

نُقلت واجهة Expo إلى `mobile/` في مستودع GitHub، مع الحفاظ على تطبيق SwiftUI القديم في `ios/` دون حذف.

## 3. البناء

Workflow: `.github/workflows/expo-ios-build.yml`

- Runner: `macos-15`
- Node 20 + `npm ci`
- `npx expo prebuild --platform ios --no-install`
- `pod install --repo-update`
- `xcodebuild archive -configuration Release -destination generic/platform=iOS`
- `CODE_SIGNING_ALLOWED=NO` لذلك الملف **غير موقّع**.
- فحص البناء: وجود `Info.plist`، تطابق Bundle ID، وحجم الملف التنفيذي أكبر من 200 KB.

## 4. التحقق الفعلي من IPA

| الفحص | النتيجة |
|---|---|
| الحجم | 5,086,426 بايت |
| SHA-256 | `764b08b606de63226cca4c4ff563e192af4d823f627a2150a1977c954da5be22` |
| البنية | `Payload/NEXUSAI.app/` (تنسيق IPA قياسي) |
| الملف التنفيذي | `NEXUSAI` بحجم 6,389,352 بايت |
| Mach-O | `0xcffaedfe` — Mach-O 64-bit |
| المعمارية | `arm64` (CPU type `0x0100000C`) |
| Bundle ID | `ai.nexus.app` |
| الاسم المعروض | `NEXUS AI` |
| الإصدار | `1.0.0 (1)` |
| أدنى iOS | `15.1` |
| حزمة JavaScript | `main.jsbundle` بحجم 2,650,717 بايت |
| `embedded.mobileprovision` | غير موجود (متوقع في نسخة غير موقّعة) |
| `_CodeSignature` | غير موجود (الملف غير موقّع) |
| مفاتيح داخل الحزمة | لا يوجد `AIza…` ولا `sk-…` ولا `Bearer …` ولا private key |

> الملاحظة الوحيدة: `main.jsbundle` يحتوي سلسلة `localhost` الداخلية الخاصة بـ React Native dev server. التطبيق لا يستخدمها كعنوان Backend؛ `apiBaseUrl` فارغ ولا يوجد عنوان افتراضي.

## 5. الاختبارات

| الاختبار | النتيجة |
|---|---|
| Backend pytest | 18 passed |
| Mobile node tests | 3 passed |
| Expo iOS production export | نجح (1001 modules) |
| GitHub Actions build | success |
| فحص IPA | ناجح |

## 6. حالة التوقيع

الملف **unsigned**. هذا مقصود: ESign يعيد التوقيع بشهادة المستخدم. لا يُوصف الملف بأنه قابل للتثبيت مباشرة قبل توقيعه.

لا توجد شهادة Apple أو Provisioning Profile في مساحة العمل. لتوقيع مباشر من GitHub Actions يلزم إضافة الأسرار الموضحة في `docs/SIGNING.md` وتشغيل `expo-ios-signed.yml`. بديلاً عن ذلك، استخدم ESign على iPhone.

## 7. مراجعة ما قبل ESign

- `LC_CODE_SIGNATURE` غير موجود، و`_CodeSignature` غير موجودة: الملف غير موقّع فعلاً.
- `LC_ENCRYPTION_INFO_64` موجود مع `cryptid = 0`: لا يوجد تشفير App Store.
- معمارية واحدة `arm64`، و`UIDeviceFamily = [1]`: iPhone فقط.
- لا توجد App Extensions ولا إطارات تحتاج توقيعاً منفصلاً.
- لا توجد مفاتيح أو شهادات أو Provisioning Profile داخل الحزمة.
- `extra.apiBaseUrl` فارغ داخل `app.json`، لذلك رابط Railway يُدخل من Settings.

التفاصيل الكاملة وخطوات التوقيع: `docs/IPA-FINAL-REVIEW.md` و`docs/SIGNING.md`.
