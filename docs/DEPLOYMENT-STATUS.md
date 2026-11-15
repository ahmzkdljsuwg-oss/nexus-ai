# NEXUS AI — حالة النشر والربط (Production Status)

> آخر تحديث: 2026-11-15  
> هذه الوثيقة تصف ما تم التحقق منه فعلياً، وما هو متوقف، دون ادعاء نجاح غير مثبت.

## 1. الخلاصة

| العنصر | الحالة | الدليل |
|---|---|---|
| كود الـBackend | جاهز | `backend/` + 25 اختباراً ناجحاً و2 متجاوزان |
| FastAPI endpoints | تعمل محلياً | `/api/health`, `/api/markets`, `/api/analyse`, `/api/recommendations`, `/api/history` |
| PostgreSQL | الكود جاهز | `DATABASE_URL` + `asyncpg`; لم يُختبر على Railway بعد |
| Railway deployment | **غير منشور** | لا يوجد `RAILWAY_TOKEN`، ولا رابط إنتاج |
| Gemini / Mistral | **غير متصل** | لا مفاتيح على الخادم؛ `/api/chat` يرجع 503 |
| حالة التطبيق بلا تسجيل دخول | مطبقة في SwiftUI وExpo | يبدأ التطبيق على الشاشة الرئيسية |
| عنوان API الإنتاجي | قابل للضبط | من شاشة الاتصال، أو وقت البناء |
| بيانات الأسواق السبعة | لا تُختلق | غياب المصدر = `DATA UNAVAILABLE` |
| IPA موقّع | **غير موجود** | يحتاج شهادة Apple وProvisioning Profile |

## 2. لماذا لم يُنشر على Railway؟

طلب النشر الآمن (`RAILWAY_TOKEN`) لم يُحفظ. لا يوجد في البيئة أي توكن Railway ولا مفاتيح مزودين:

- `railway whoami` → غير مصادق.
- `gh secret list` و`gh variable list` → لا أسرار ولا متغيرات مضبوطة في المستودع.

لذلك لا يوجد رابط Railway إنتاجي يمكن وضعه في `BASE_URL`. لم يتم اختلاق رابط.

## 3. طريقة النشر فور توفر التوكن

1. حفظ `RAILWAY_TOKEN` في GitHub Actions Secrets (وليس في أي ملف).
2. تشغيل يدوي لـ **Deploy Backend to Railway**.
3. السكربت `scripts/deploy_railway.py` يقوم بما يلي:
   - إنشاء/ربط مشروع Railway.
   - إنشاء خدمة PostgreSQL وربط `DATABASE_URL`.
   - نشر `backend/` عبر Dockerfile.
   - توليد دومين عام.
   - انتظار `/api/health` حتى تصبح قاعدة البيانات `postgresql`.
   - اختبار Gemini الحقيقي عبر `/api/chat` (يمكن تخطيه مؤقتاً).
   - كتابة `deployment.json` بالرابط ونتائج الاختبار.
4. بعد نجاح النشر، يوضع الرابط في:
   - `NEXUS_API_BASE_URL` كـ GitHub Actions Variable (لبناء iOS).
   - `EXPO_PUBLIC_API_BASE_URL` لبناء Expo.
   - أو يدوياً من شاشة الاتصال داخل التطبيق.

## 4. متغيرات Railway المطلوبة

| المتغير | إلزامي | الغرض |
|---|---|---|
| `GEMINI_API_KEY` | لتفعيل الدردشة والمقارنة | Gemini chat فقط |
| `MISTRAL_API_KEY` | لتفعيل التحليل المستقل | Mistral analysis |
| `GEMINI_MODEL` | اختياري | افتراضي `gemini-2.0-flash` |
| `MISTRAL_MODEL` | اختياري | افتراضي `mistral-small-latest` |
| `TWELVE_DATA_API_KEY` | لبيانات FOREX/GOLD | لا يوجد بديل وهمي |
| `MT5_BRIDGE_URL` / `MT5_BRIDGE_KEY` | للأسواق الستة | جسر ExpertOption/MT5 حقيقي |
| `DATABASE_URL` | تلقائي | يضبطه Railway من خدمة PostgreSQL |
| `SCANNER_ENABLED` | اختياري | `true` لتشغيل فحص إغلاق الشموع |

> لا تُوضع أي مفاتيح في التطبيق أو GitHub أو السجلات. `backend/.env.example` يحتوي أسماء المتغيرات فقط.
