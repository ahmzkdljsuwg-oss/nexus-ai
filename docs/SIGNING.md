# توقيع IPA وتثبيته — NEXUS AI

Bundle Identifier ثابت: `ai.nexus.app` (لا يُطلب تغييره ولا يوجد Secret لتغييره).

## ما يحتاجه GitHub Actions

أضف القيم التالية في **Settings → Secrets and variables → Actions → New repository secret**. لا ترسلها في المحادثة ولا تضعها في أي ملف داخل المستودع.

| Secret | المحتوى | كيف يُنتج |
|---|---|---|
| `IOS_CERT_P12_BASE64` | شهادة `Apple Distribution` أو `Apple Development` بصيغة `.p12` بعد تحويلها Base64 | Keychain Access → تصدير الشهادة مع المفتاح الخاص → `base64 -i cert.p12 \| pbcopy` على macOS، أو `base64 -w0 cert.p12` على Linux |
| `IOS_CERT_PASSWORD` | كلمة مرور ملف `.p12` | التي اخترتها لحظة التصدير |
| `IOS_PROVISIONING_PROFILE_BASE64` | ملف `.mobileprovision` بعد تحويله Base64 | developer.apple.com → Profiles → Ad Hoc (أو Development) للـ App ID `ai.nexus.app` → تنزيل الملف → `base64 -i profile.mobileprovision \| pbcopy` |
| `IOS_TEAM_ID` | معرف فريق Apple المكوّن من 10 خانات | أعلى صفحة developer.apple.com، أو Membership Details |

`IOS_BUNDLE_ID` و`KEYCHAIN_PASSWORD` **ليسا مطلوبين**: الـ Bundle ID مثبّت في الـ workflow، وكلمة مرور الـ keychain تُولّد عشوائياً داخل Runner.

### شروط الملف التعريفي

- App ID مطابق تماماً لـ `ai.nexus.app`.
- النوع **Ad Hoc** (مفضّل) أو **Development**.
- يحتوي على UDID الخاص بـ iPhone الذي ستثبّت عليه. بدون ذلك يفشل الـ workflow برسالة واضحة قبل البناء.
- الشهادة داخل `.p12` من النوع المطابق: `Apple Distribution` مع Ad Hoc، و`Apple Development` مع Development.

### اختيار طريقة التصدير

- `ad-hoc`: يعمل على الأجهزة المسجّلة في الحساب، وهو الأنسب لـ ESign/التثبيت المباشر.
- `development`: للتطوير والاختبار على أجهزة الفريق.

## خطوات التشغيل

1. أضف الأسرار الأربعة أعلاه.
2. Actions → **Build Signed iOS App** → Run workflow → اختر `ad-hoc`.
3. ينفّذ الـ workflow:
   - استيراد الشهادة والملف التعريفي والتحقق من تطابق Team وBundle ID.
   - بناء Release وArchive بتوقيع يدوي.
   - تصدير IPA موقّع.
   - `codesign --verify --deep --strict` والتحقق من `embedded.mobileprovision` ورفض أي توقيع ad-hoc من الرابط.
   - رفع `NexusAI-signed-ipa` مع SHA256.
4. نزّل الـ artifact من صفحة التشغيل.

## التثبيت عبر ESign

1. انقل `NexusAI-signed.ipa` إلى iPhone.
2. افتح ESign → Import → اختر الملف.
3. إن ظهرت حاجة لإعادة توقيع، استخدم نفس `.p12` و`.mobileprovision` داخل ESign.
4. ثبّت، ثم افتح التطبيق وأدخل رابط Railway في شاشة تسجيل الدخول.

لا يمكن إعلان نجاح التثبيت قبل تنفيذه على جهاز فعلي. الـ workflow يثبت سلامة التوقيع داخل الـ archive فقط.

## ملاحظات أمان

- الملفات الموقّعة والأسرار تبقى خارج git؛ `.gitignore` يستثني `*.ipa`.
- GitHub يخفي قيم Secrets في السجلات. لا تطبع الشهادة أو كلمة مرورها.
- استخدم شهادة مخصصة لهذا التطبيق، وألغِها من developer.apple.com عند انتهاء الحاجة.
