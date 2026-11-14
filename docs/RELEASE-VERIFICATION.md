# NEXUS AI — التحقق النهائي للملفات والإصدار

**تاريخ التحقق:** 2026-11-14
**HEAD:** `ae927e6` (آخر تغيير على كود iOS: `499f516`)
**ملاحظة:** لا يوجد نشر Railway ولا مفاتيح `RAILWAY_TOKEN` أو `GEMINI_API_KEY` في بيئة العمل حتى الآن. كل ما يلي تم التحقق منه محلياً أو من مخرجات GitHub Actions الفعلية.

## 1. فحص IPA

**الملف:** `NexusAI-unsigned.ipa`
**الحجم:** 567,019 بايت
**SHA256:**

```
ceb96cb0156e37611fb5ce317a7cae305b33fffd91eafa1290cf074c97ff046f
```

**فحص الأرشيف:** `zip_test` ناجح، وكل الملفات التالية موجودة:

| الملف | الحالة |
|---|---|
| `Payload/NexusAI.app/NexusAI` | موجود، Mach-O 64-bit |
| `Payload/NexusAI.app/Info.plist` | موجود، plist صالح |
| `Payload/NexusAI.app/Assets.car` | موجود، `BOMStore` |
| `Payload/NexusAI.app/PkgInfo` | موجود، `APPL????` |
| `Payload/NexusAI.app/AppIcon60x60@2x.png` | موجود، PNG صالح |
| `Payload/NexusAI.app/AppIcon76x76@2x~ipad.png` | موجود، PNG صالح |

لا توجد مجلدات `Frameworks` أو امتدادات مطلوبة: التطبيق يستخدم إطارات النظام فقط.

## 2. بيانات التطبيق

| البند | القيمة |
|---|---|
| Bundle Identifier | `ai.nexus.app` |
| CFBundleName | `NexusAI` |
| Display Name | `NEXUS AI` |
| Version | `1.0.0` |
| Build | `1` |
| Minimum iOS | `16.0` |
| Architecture | `arm64` فقط |
| Platform | `iPhoneOS` |
| Device family | iPhone فقط (`1`) |
| Orientation | Portrait |
| Required capability | `arm64` |

## 3. حالة التوقيع

- لا يوجد `Payload/NexusAI.app/_CodeSignature/`.
- لا يوجد `Payload/NexusAI.app/embedded.mobileprovision`.
- ملف Mach-O لا يحتوي على `LC_CODE_SIGNATURE`.

**النتيجة:** IPA غير موقّع فعلاً. لا يمكن تثبيته مباشرة على iPhone قبل إعادة التوقيع.

## 4. رابط الخادم داخل التطبيق

- `AppState.baseURLString` يُقرأ من `UserDefaults` (المفتاح `nexus.base-url`).
- شاشة الدخول تسمح بإدخال عنوان الخادم وحفظه.
- لا يوجد `localhost` أو `127.0.0.1` أو رابط تجريبي ثابت في كود التطبيق.
- القيمة الافتراضية فارغة، ويجب إدخال رابط Railway الإنتاجي مرة واحدة.
- الشرط الحالي يقبل `https://` و`http://`، لكن iOS ATS يمنع HTTP غير الاستثنائي؛ استخدم HTTPS دائماً.

**النتيجة:** الرابط قابل للتغيير، وليس مضبوطاً على خادم محلي أو تجريبي.

## 5. PostgreSQL الإنتاجي

تم محلياً:

- إنشاء المخطط على PostgreSQL 18.7.
- الجداول: `chats, files, messages, projects, sessions, users`.
- اختبارات الخادم على PostgreSQL المحلي: `42 passed, 1 skipped`.

**لم يتم بعد:** التحقق من قاعدة Railway الإنتاجية. لا يمكن ذلك قبل نشر الخادم وربط خدمة Postgres. عند النشر:

```bash
cd backend
railway run --service <service-name> python scripts/init_db.py
python scripts/verify_production.py https://<service>.up.railway.app
```

`init_db.py` يطبع أسماء الجداول من قاعدة Railway نفسها، و`/api/health` يجب أن يعيد `"database":"ok"`.

## 6. اختبارات HTTP/Gemini من خارج الخادم

- اختبارات HTTP حقيقية محلياً عبر TCP: ناجحة.
- اختبار Gemini الحقيقي: مُعد ليعمل تلقائياً عند وجود `GEMINI_API_KEY`، ولم يُنفّذ لعدم وجود المفتاح.
- اختبار الإنتاج الخارجي: ينتظر وصول `RAILWAY_TOKEN` و`GEMINI_API_KEY`.

## 7. إعادة التوقيع والتثبيت عبر ESign

1. ثبّت ESign على iPhone بطريقتك المعتادة.
2. انقل `NexusAI-unsigned.ipa` إلى تطبيق Files على الجهاز.
3. افتح ESign → Import/Import File → اختر IPA.
4. اختر شهادة توقيع صالحة (`p12` + كلمة المرور) وملف `mobileprovision` يطابق `ai.nexus.app` أو Bundle ID wildcard.
5. اضغط Sign/Install، ثم افتح التطبيق.
6. إذا ظهر تحذير المطوّر: Settings → General → VPN & Device Management → Trust.
7. عند فشل التثبيت تحقق من: صلاحية الشهادة، تطابق Bundle ID، تسجيل الجهاز في profile، وصلاحية الشهادة/الملف التعريفي.

**لم يتم اختبار التثبيت على iPhone فعلي** في بيئة العمل، ولا يمكن ادّعاء نجاحه.

## 8. المتبقي بوضوح

| البند | الحالة |
|---|---|
| نشر Railway | ينتظر `RAILWAY_TOKEN` |
| PostgreSQL الإنتاجي | ينتظر النشر |
| Gemini حقيقي | ينتظر `GEMINI_API_KEY` |
| HTTP من خارج الخادم | ينتظر رابط Railway |
| اتصال التطبيق بالخادم | ينتظر رابط Railway + تثبيت IPA |
| تثبيت IPA على iPhone | ينتظر إعادة التوقيع والجهاز |
