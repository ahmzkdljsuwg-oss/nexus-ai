# NEXUS AI — جاهزية الإطلاق

آخر تحديث: 2026-11-14

## الحالة باختصار

| المسار | الحالة | ما ينقص |
|---|---|---|
| الكود والاختبارات | ✅ مكتمل | لا شيء |
| نشر Railway | 🟡 جاهز للتشغيل بضغطة | `RAILWAY_TOKEN` فقط |
| Gemini الحقيقي | 🟡 جاهز للتشغيل تلقائياً | `GEMINI_API_KEY` فقط |
| IPA موقّع | 🟡 جاهز للتشغيل | 4 أسرار توقيع |
| تثبيت على iPhone | ⛔ لم يُنفّذ | جهاز فعلي بعد التوقيع |
| Bundle ID | ✅ `ai.nexus.app` | لا يتغيّر |

لا يُعتبر المشروع مكتملاً إطلاقاً حتى تنجح المسارات الثلاثة: النشر، Gemini، والتوقيع.

## 1. النشر — ما يحتاجه منك

أضف في GitHub **Settings → Secrets and variables → Actions**:

- `RAILWAY_TOKEN` — Account Token من Railway (ليس Project Token).
- `GEMINI_API_KEY` — اختياري في هذه الخطوة، لكنه مطلوب لاختبار المساعد الحقيقي.
- `GEMINI_MODEL` — اختياري، الافتراضي `gemini-2.5-flash`.
- `RAILWAY_WORKSPACE` — Variable (ليس Secret) فقط إذا كان لديك أكثر من Workspace.

ثم: Actions → **Deploy Backend to Railway** → Run workflow.

ما ينفّذه النظام تلقائياً: إنشاء المشروع، PostgreSQL، الخدمة، المتغيرات، رفع الكود، الدومين، انتظار الصحة، اختبار Gemini من خارج الخادم، وحفظ `deployment.json`.

## 2. التوقيع — ما يحتاجه منك

- `IOS_CERT_P12_BASE64`
- `IOS_CERT_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_TEAM_ID`

التفاصيل الكاملة في `docs/SIGNING.md`. لا يُطلب `IOS_BUNDLE_ID` لأنه ثابت.

ثم: Actions → **Build Signed iOS App** → Run workflow → `ad-hoc`.

## 3. ما أستطيع تنفيذه بنفسي بعد وصول الأسرار

عبر النماذج الآمنة أو بعد إضافتها في GitHub:

1. تشغيل النشر وقراءة سجل التشغيل الفعلي.
2. تشغيل `verify_production.py --gemini` والتحقق من رد Gemini الحقيقي.
3. إعادة تشغيل بناء IPA الموقّع وفحص التوقيع وSHA256.
4. تحديث تقرير التسليم بالنتائج الفعلية.
5. اختبار HTTP من خارج الخادم عبر `verify_production.py`.
6. توثيق أي خطأ يظهر وإصلاحه، لا تجاوزه.

## 4. ما لا أستطيع تنفيذه بنفسي

- إصدار شهادة Apple أو إنشاء Provisioning Profile — يتطلب حساب Apple Developer.
- تثبيت التطبيق على iPhone فيزيائي — لا يوجد جهاز متصل ببيئة العمل.
- تسجيل الدخول إلى حساب Railway نيابةً عنك دون Token.
- الحصول على مفتاح Gemini من حسابك.

## 5. إعدادات التطبيق

- رابط الخادم يُدخل من شاشة تسجيل الدخول ويُحفظ في `UserDefaults`.
- يمكن تغييره من شاشة الدخول؛ لا يوجد رابط إنتاجي مثبت داخل الكود.
- HTTPS إلزامي، و`http` مسموح فقط لـ `localhost`/`127.0.0.1`.
- لا يحتوي التطبيق أي مفتاح Gemini.

## 6. أدلة التحقق الحالية

- `backend`: `42 passed, 1 skipped` (المتخطى هو اختبار Gemini الغائب المفتاح).
- `docs/UI-REVIEW.md` + `docs/screenshots/`: 11 صورة من محاكي iPhone 16.
- `docs/RELEASE-VERIFICATION.md`: فحص IPA غير الموقّع وSHA256.
- `docs/TEST-REPORT.md`: تفاصيل الاختبارات.
- GitHub Actions: Backend Tests و iOS Build و UI Screenshots ناجحة.

## 7. حدود يجب قولها بوضوح

- لم يُنشر Backend على Railway فعلياً.
- لم يُستدعَ Gemini بمفتاح حقيقي.
- لم يُبنَ IPA موقّع ولم يُثبَّت على جهاز.
- الصور من المحاكي وليست من iPhone فيزيائي.
