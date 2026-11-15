# توقيع IPA وتثبيته — NEXUS AI

Bundle Identifier ثابت: `ai.nexus.app`. لا يُطلب تغييره ولا يوجد Secret لتغييره.

- الـ IPA في التسليم **غير موقّع** ومعدّ لإعادة التوقيع عبر ESign.
- بناء IPA موقّع من GitHub Actions يحتاج شهادة Apple وProvisioning Profile حقيقيين.
- لا ترسل الشهادة أو كلمة مرورها أو الملف التعريفي في المحادثة. ضعها في GitHub Secrets فقط.

## 1. ما يحتاجه GitHub Actions

أضف القيم التالية في **Settings → Secrets and variables → Actions → New repository secret**.

| Secret | المحتوى | كيف يُنتج |
|---|---|---|
| `IOS_CERT_P12_BASE64` | شهادة `Apple Distribution` أو `Apple Development` بصيغة `.p12` مع المفتاح الخاص، محوّلة إلى Base64 | Keychain Access → تصدير الشهادة، ثم على macOS: `base64 -i cert.p12 -o cert.b64`، أو على Linux: `base64 -w0 cert.p12 > cert.b64` |
| `IOS_CERT_PASSWORD` | كلمة مرور ملف `.p12` | التي اخترتها لحظة التصدير |
| `IOS_PROVISIONING_PROFILE_BASE64` | ملف `.mobileprovision` محوّل إلى Base64 | developer.apple.com → Profiles → Ad Hoc أو Development للـ App ID `ai.nexus.app` → تنزيل → `base64 -i profile.mobileprovision -o profile.b64` |
| `IOS_TEAM_ID` | معرف فريق Apple المكوّن من 10 خانات | أعلى صفحة developer.apple.com أو Membership Details |

`IOS_BUNDLE_ID` و`KEYCHAIN_PASSWORD` غير مطلوبين: الـ Bundle ID مثبّت في الـ workflow، وكلمة مرور الـ keychain تُولّد عشوائياً داخل Runner.

## 2. شروط الشهادة والملف التعريفي

- App ID مطابق تماماً لـ `ai.nexus.app` — لا تستخدم Wildcard Profile.
- النوع **Ad Hoc** (المفضّل) أو **Development**.
- يحتوي الملف التعريفي على UDID الخاص بـ iPhone الذي ستثبّت عليه.
- الشهادة والملف التعريفي من نفس الفريق:
  - `ad-hoc` ← شهادة `Apple Distribution` + بروفايل Ad Hoc (`get-task-allow = false`).
  - `development` ← شهادة `Apple Development` + بروفايل Development (`get-task-allow = true`).
- أضف UDID الجهاز في developer.apple.com **قبل** إنشاء البروفايل. البروفايل لا يتحدّث تلقائياً بعد إضافة جهاز.

## 3. تشغيل البناء الموقّع

1. أضف الأسرار الأربعة أعلاه.
2. Actions → **Build Signed Expo iOS App** → Run workflow → اختر `ad-hoc`.
3. الـ workflow يتحقق قبل البناء من:
   - وجود الأسرار الأربعة.
   - أن Bundle ID في `app.json` هو `ai.nexus.app`.
   - أن الشهادة تحتوي هوية `Apple Distribution` أو `Apple Development` المطلوبة.
   - أن البروفايل يطابق Team وBundle ID ويحتوي أجهزة مسجّلة.
   - أن نوع البروفايل يطابق طريقة التصدير.
4. ثم يبني Release، يوقّع، يصدّر IPA، ويتحقق من:
   - `codesign --verify --deep --strict`.
   - وجود `Authority=Apple`.
   - تطابق Bundle ID والإصدار ورقم البناء.
   - وجود `embedded.mobileprovision` وتطابق UUID.
5. نزّل artifact باسم `NEXUSAI-signed-ipa`. يحتوي:
   - `NEXUSAI-signed.ipa`
   - `NEXUSAI-signed.ipa.sha256`

إذا فشل أي فحص قبل البناء، تظهر رسالة `::error::` توضّح السبب بدلاً من إنتاج ملف غير صالح.

## 4. التثبيت عبر ESign

1. نزّل `NEXUS-AI.ipa` غير الموقّع من التسليم، أو `NEXUSAI-signed.ipa` إذا نجح البناء الموقّع.
2. انقل الملف إلى iPhone.
3. افتح ESign → Import → اختر ملف IPA.
4. اختر الشهادة المخصصة (`.p12`) والوصف (`.mobileprovision`) داخل ESign.
5. ثبّت التطبيق.
6. بعد الفتح: Settings → Backend URL → أدخل رابط Railway الإنتاجي.

ESign يعيد التوقيع محلياً. لا يمكن إعلان نجاح التثبيت قبل تنفيذه على جهاز فعلي.

## 5. أخطاء شائعة

| الخطأ | السبب | الحل |
|---|---|---|
| `Missing secret ...` | Secret غير مضاف أو اسمه خطأ | أضف الأسماء الأربعة بالحرف نفسه |
| `Apple Distribution identity not found` | ملف `.p12` لا يحتوي الشهادة الصحيحة أو كلمة المرور خاطئة | أعد تصدير الشهادة مع المفتاح الخاص وتأكد من النوع |
| `profile has no registered devices` | بروفايل App Store أو بروفايل بدون أجهزة | أنشئ Ad Hoc profile وأضف UDID |
| `needs an Ad Hoc profile` | اخترت `ad-hoc` مع بروفايل Development | استخدم `development` أو أنشئ بروفايل Ad Hoc |
| `does not match bundle id` | بروفايل Wildcard أو App ID مختلف | استخدم App ID صريحاً: `ai.nexus.app` |
| فشل `codesign` أثناء البناء | شهادة غير موثوقة أو WWDR ناقص | الـ workflow يثبّت WWDR G4/G3 تلقائياً؛ أعد التشغيل وتحقق من حالة الشهادة في Apple Developer |
| `No profiles for 'ai.nexus.app' were found` | البروفايل غير مثبت أو الاسم لا يطابق | أعد إنشاء البروفايل وتأكد أن Secret يحتوي الملف الصحيح |

## 6. ملاحظات أمان

- الأسرار تبقى في GitHub Secrets ولا تُطبع في السجلات.
- `.gitignore` يستثني `*.ipa` و`*.p12` و`*.mobileprovision`.
- استخدم شهادة مخصصة لهذا التطبيق، وألغِها من developer.apple.com عند انتهاء الحاجة.
