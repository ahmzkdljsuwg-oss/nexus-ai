# دليل بناء وتثبيت IPA

## Unsigned IPA

ملف IPA يحتوي تطبيقاً **بدون توقيع**. لا يستطيع iPhone تثبيته مباشرة، لأن iOS يرفض أي تطبيق غير موقّع.

الاستخدام:
1. حمّل `NexusAI-unsigned-ipa` من GitHub Actions.
2. أعد توقيعه باستخدام **ESign** أو Sideloadly أو AltStore بحساب Apple الخاص بك.
3. ثبّته على الجهاز.

قيود:
- يحتاج إعادة توقيع في كل مرة تنتهي فيها الشهادة/الملف التعريفي.
- قد توجد حدود على عدد التطبيقات/الأجهزة حسب نوع الحساب.
- لا يصلح للنشر على App Store.

## Signed IPA

IPA موقّع بشهادة توقيع Apple صالحة (`Distribution` أو `Development`) مع Provisioning Profile يطابق Bundle Identifier `ai.nexus.app`.

يتطلب:
- شهادة `.p12` وكلمة مرورها.
- ملف `.mobileprovision` صالح.
- Bundle Identifier مطابق، والأجهزة مسجلة في الحساب (Development/Ad Hoc).

الملفات المطلوبة كـ GitHub Secrets:

| Secret | القيمة |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `base64 -i cert.p12` |
| `P12_PASSWORD` | كلمة مرور الشهادة |
| `PROVISIONING_PROFILE_BASE64` | `base64 -i profile.mobileprovision` |
| `KEYCHAIN_PASSWORD` | أي كلمة مرور مؤقتة للـ keychain في CI |
| `DEVELOPMENT_TEAM` | Apple Team ID |
| `PROVISIONING_PROFILE_SPECIFIER` | اسم الملف التعريفي |

ثم: Actions → **Build Signed iOS App** → Run workflow.

## Workflows

- `.github/workflows/ios-build.yml`: يبني على macOS، ينتج archive غير موقّع و`NexusAI-unsigned-ipa`.
- `.github/workflows/ios-signed.yml`: يدوي، يستورد الشهادة والملف التعريفي وينتج `NexusAI-signed-ipa`.

## مسار بديل إذا تعطلت GitHub macOS runners

1. **Codemagic** (`codemagic.yaml`): اربط المستودع، ثم شغّل `ios-unsigned`. يبني على `mac_mini_m2` وينتج `ios/build/NexusAI-unsigned.ipa`.
2. **Mac محلي**:

```bash
brew install xcodegen
cd ios
./scripts/build-ipa.sh
```

يُنتج `ios/build/NexusAI-unsigned.ipa` ويتحقق من وجود `Payload/NexusAI.app/Info.plist` داخل الأرشيف.

الملف الناتج غير موقّع في الحالتين. التثبيت المباشر يتطلب إعادة توقيع بـ ESign أو Sideloadly، أو بناء نسخة موقّعة عبر `ios-signed` أو Xcode بحساب Apple.

## Bundle Identifier

`ai.nexus.app` — موجود في `ios/project.yml`. غيّره إن كان لديك معرّف مختلف في حساب Apple، وأعد التوليد بـ `xcodegen generate`.
