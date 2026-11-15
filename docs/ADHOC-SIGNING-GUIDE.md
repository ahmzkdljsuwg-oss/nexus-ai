# تجهيز توقيع Ad Hoc — NEXUS AI

هذا الدليل يجهّز الشهادة والبروفايل اللذين يحتاجهما
`.github/workflows/expo-ios-signed.yml`، دون تغيير التطبيق أو Bundle ID.

**Bundle ID:** `ai.nexus.app`
**الفريق:** نفس فريق Apple Developer الذي يملك الشهادة والبروفايل.

---

## 1. المتطلبات

- عضوية **Apple Developer Program** مدفوعة وسارية.
- وصول إلى [developer.apple.com](https://developer.apple.com/account) بصلاحية
  Certificates, Identifiers & Profiles.
- iPhone مسجّل في نفس الحساب.
- جهاز Mac لإنشاء الشهادة وتصدير `.p12` (أو OpenSSL كما في القسم 5).

> لا يمكن إنشاء شهادة Apple صالحة من GitHub أو من مساحة العمل. الشهادة تُصدر
> من حسابك في Apple Developer فقط. لا ترسل الشهادة أو كلمة مرورها في المحادثة.

---

## 2. تسجيل iPhone والحصول على UDID

1. وصّل iPhone بـ Mac وافتح **Finder**.
2. اختر الجهاز، اضغط على اسم الجهاز أو زر المعلومات حتى يظهر **UDID**.
3. انسخ UDID (40 خانة hex، أو 25 خانة في الأجهزة الحديثة).
4. في developer.apple.com: **Devices → +** → اختر iPhone → الصق UDID → Register.

لا تستخدم مواقع "إظهار UDID" غير الموثوقة. يمكن أيضاً قراءة UDID من ESign،
لكن الأفضل من Finder.

---

## 3. إنشاء App ID صريح

1. **Identifiers → +** → App IDs → App.
2. Type: **App**.
3. Bundle ID: **Explicit**.
4. القيمة: `ai.nexus.app`.
5. لا تضف Capabilities غير مستخدمة في المشروع.
6. احفظ.

لا تستخدم Wildcard App ID. البروفايل المشترك `*` لا يصلح لتوقيع هذا التطبيق.

---

## 4. إنشاء شهادة Apple Distribution

على Mac:

1. افتح **Keychain Access → Certificate Assistant → Request a Certificate
   From a Certificate Authority**.
2. أدخل بريدك، واختر **Saved to disk**.
3. في developer.apple.com: **Certificates → +**.
4. اختر **Apple Distribution** (لـ Ad Hoc) أو **Apple Development** (لـ Development).
5. ارفع ملف `.certSigningRequest`.
6. نزّل ملف `.cer`.
7. افتح `.cer` ليُضاف إلى Keychain.
8. في Keychain Access، افتح تبويب **My Certificates**، تأكد أن الشهادة ومعها
   **المفتاح الخاص**.
9. اضغط عليها بزر الفأرة الأيمن → **Export** → صيغة `.p12`.
10. ضع كلمة مرور قوية، واحفظها مؤقتاً؛ ستصبح `IOS_CERT_PASSWORD`.

يجب أن تحتوي الشهادة على المفتاح الخاص، وإلا سيفشل `codesign`.

---

## 5. بديل بدون Mac: إنشاء CSR بـ OpenSSL

على أي جهاز فيه OpenSSL:

```bash
openssl req -new -newkey rsa:2048 -nodes \
  -keyout nexus-distribution.key \
  -out nexus-distribution.certSigningRequest \
  -subj "/CN=NEXUS AI Distribution/OU=Distribution/O=NEXUS AI/C=SA"
```

1. ارفع `nexus-distribution.certSigningRequest` إلى Apple Developer.
2. نزّل `distribution.cer`.
3. حوّل الشهادة إلى PEM:

```bash
openssl x509 -inform DER -in distribution.cer -out distribution.pem
```

4. أنشئ ملف `.p12` مع المفتاح الخاص:

```bash
openssl pkcs12 -export \
  -inkey nexus-distribution.key \
  -in distribution.pem \
  -name "NEXUS AI Distribution" \
  -out nexus-distribution.p12
```

احتفظ بالمفتاح الخاص. لا ترفعه إلى GitHub ولا ترسله في المحادثة.

---

## 6. إنشاء Provisioning Profile من نوع Ad Hoc

1. في developer.apple.com: **Profiles → +**.
2. اختر **Ad Hoc**.
3. اختر App ID: `ai.nexus.app`.
4. اختر شهادة **Apple Distribution** التي أنشأتها.
5. اختر **iPhone جهازك** من قائمة الأجهزة المسجّلة.
6. أدخل اسماً واضحاً، مثل `NEXUS AI AdHoc`.
7. Generate → Download.
8. احفظ `NEXUS_AI_AdHoc.mobileprovision`.

مهم: أضف UDID الجهاز **قبل** إنشاء البروفايل. إذا أضفت جهازاً لاحقاً،
أعد إنشاء البروفايل ونزّله من جديد.

---

## 7. التحقق المحلي قبل الرفع

### فحص البروفايل

```bash
security cms -D -i NEXUS_AI_AdHoc.mobileprovision > profile.plist
/usr/libexec/PlistBuddy -c 'Print :Name' profile.plist
/usr/libexec/PlistBuddy -c 'Print :UUID' profile.plist
/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' profile.plist
/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' profile.plist
/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' profile.plist
/usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' profile.plist
```

يجب أن تحصل على:

- `application-identifier` = `TEAMID.ai.nexus.app`
- `get-task-allow` = `false` لـ Ad Hoc
- قائمة `ProvisionedDevices` تحتوي UDID جهازك

### فحص الشهادة

```bash
security find-identity -v -p codesigning
security import nexus-distribution.p12 -k ~/Library/Keychains/login.keychain-db \
  -P 'P12_PASSWORD' -T /usr/bin/codesign -T /usr/bin/security
```

يجب أن تظهر هوية تبدأ بـ `Apple Distribution:` أو `Apple Development:`.

---

## 8. تجهيز قيم GitHub Secrets

حوّل الملفين إلى Base64:

macOS:

```bash
base64 -i nexus-distribution.p12 -o cert.b64
base64 -i NEXUS_AI_AdHoc.mobileprovision -o profile.b64
```

Linux:

```bash
base64 -w0 nexus-distribution.p12 > cert.b64
base64 -w0 NEXUS_AI_AdHoc.mobileprovision > profile.b64
```

افتح في GitHub:
**Settings → Secrets and variables → Actions → New repository secret**

| Secret | القيمة |
|---|---|
| `IOS_CERT_P12_BASE64` | محتوى `cert.b64` |
| `IOS_CERT_PASSWORD` | كلمة مرور `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | محتوى `profile.b64` |
| `IOS_TEAM_ID` | Team ID (10 خانات) |

لا تضف `IOS_BUNDLE_ID`، ولا `KEYCHAIN_PASSWORD`؛ غير مطلوبين.
لا تلصق القيم في المحادثة أو في Issue أو في commit.

بعد الإضافة، احذف `cert.b64` و`profile.b64` من الجهاز إن لم تكن بحاجة إليها.

---

## 9. تشغيل البناء

1. افتح **Actions → Build Signed Expo iOS App**.
2. **Run workflow** → Branch: الفرع الذي يحتوي المشروع → `ad-hoc`.
3. انتظر الخطوات:
   - Require signing secrets
   - Verify app identity and read version
   - Install and test
   - Generate iOS project
   - Install pods
   - Import certificate and profile
   - Archive signed app
   - Export signed IPA
   - Verify signature
4. نزّل artifact **NEXUSAI-signed-ipa**.
5. تحقق من `NEXUSAI-signed.ipa.sha256`.

إذا ظهر خطأ، لا تعِد المحاولة قبل قراءة رسالة `::error::`؛ الـ workflow
يرفض الشهادة أو البروفايل غير المطابق بدلاً من إنتاج IPA غير صالح.

---

## 10. التثبيت عبر ESign

1. انقل `NEXUSAI-signed.ipa` إلى iPhone (AirDrop أو Files).
2. افتح ESign → **Files** → اختر IPA.
3. اضغط **Sign**.
4. اختر نفس الشهادة `.p12` والبروفايل `.mobileprovision`.
5. تأكد أن Bundle ID هو `ai.nexus.app`.
6. اضغط **Sign** ثم **Install**.
7. إذا ظهر تحذير مطوّر: **Settings → General → VPN & Device Management →
   اسم المطوّر → Trust**.
8. افتح التطبيق وأدخل رابط Railway من شاشة Settings.

التثبيت عبر ESign يتم على جهازك. لا يمكن إعلان نجاح التثبيت قبل تنفيذه فعلياً
على iPhone.

---

## 11. ملاحظات أمان

- الشهادة والبروفايل يبقيان في GitHub Secrets فقط.
- لا تضع `.p12` أو `.mobileprovision` في المستودع.
- لا تضع مفاتيح Gemini أو Mistral أو Twelve Data في التطبيق.
- إذا انتهت الشهادة أو أُلغيت، يتوقف التطبيق عن العمل عند إعادة التثبيت.
- استخدم شهادة مخصصة لهذا التطبيق، وألغِها من Apple Developer عند انتهاء الحاجة.
