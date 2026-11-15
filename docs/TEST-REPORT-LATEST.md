# NEXUS AI — تقرير الاختبارات الفعلية (Latest)

تاريخ التشغيل: 2026-11-15  
البيئة: Linux cloud workspace، Python 3.13 venv، Node 24، SQLite للاختبار المحلي.  
لا يوجد macOS/Xcode في البيئة؛ لذلك لم تُشغّل اختبارات iOS هنا.

## 1. Backend

```bash
cd backend
python -m pytest -q
```

النتيجة:

```text
25 passed, 2 skipped in 1.26s
```

المتجاوزان مقصودان: `OTC` و`CRICKET` لا يملكان أصلاً مسجلاً في كتالوج البيانات، لذلك لا يُختبر عليهما مسار ناجح وهمي.

ما تغطيه الاختبارات:

- `/api/health`, `/api/markets`, `/api/markets/{key}`
- `/api/analyse` بنمطي `normal` و`strong`
- بوابة التحليل القوي: 3 تأكيدات على الأقل + ثقة ≥ 70 + جودة بيانات ≥ 65
- منع التوصيات المكررة أثناء وجود إشارة نشطة
- تحليل الشموع والمؤشرات وSMC
- إغلاق الشمعة وحالة الشمعة المتكوّنة
- حفظ السجل والإحصائيات
- `/api/recommendations`, `/api/history`
- رفض الطلبات غير الصالحة وحدود المعدل
- عدم وجود مفاتيح في الردود

## 2. Mobile logic

```bash
cd mobile
npm test
```

النتيجة:

```text
tests 3
pass 3
fail 0
duration_ms 137.1
```

تغطي: تطبيع `BASE_URL`، رسائل الأخطاء دون تسريب إعدادات، وتبديل العربية/الإنجليزية.

تم أيضاً تنفيذ حزمة الإنتاج الفعلية:

```bash
cd mobile
npx expo export --platform ios --output-dir /tmp/nexus-expo-export
```

النتيجة: `iOS Bundled ... (1001 modules)` و`Exported` بدون أخطاء. هذا يثبت أن شجرة JavaScript تُحزَّم، لكنه ليس بناء IPA أصلياً.

## 3. Live local HTTP smoke test

الخادم: `uvicorn` على `127.0.0.1`، `SCANNER_ENABLED=false`، بدون مفاتيح AI، وبدون `TWELVE_DATA_API_KEY`.

| الطلب | النتيجة الفعلية |
|---|---|
| `GET /api/health` | `200`، `status=ok`، `database=sqlite`، المزودون `configured=false` |
| `GET /api/markets` | `200`، الأسواق السبعة كلها `UNAVAILABLE` |
| `POST /api/analyse` — OTC/SMARTY/FOOTBALL/LUXURY/AI/CRICKET | `503 EO_BRIDGE_NOT_CONFIGURED` |
| `POST /api/analyse` — FOREX | `200 NO TRADE` مع `status=UNAVAILABLE`, `DATA_UNAVAILABLE` |
| `POST /api/chat` | `503 GEMINI_UNAVAILABLE` |
| `GET /api/recommendations` | `200`، قائمة فارغة وإحصاءات صفرية دون نسبة نجاح وهمية |
| `GET /api/history` | `200`، سجل فارغ |

تم التحقق تحديداً من أن FOREX لا يستخدم مفتاح `demo` ولا أسعاراً وهمية. تم حذف fallback إلى مفتاح Twelve Data التجريبي وإلى Yahoo غير المرخّص؛ بدون `TWELVE_DATA_API_KEY` يرجع المصدر `NOT_CONFIGURED` وتظهر `DATA UNAVAILABLE`.

## 4. ما لم يُختبر

- **Railway**: لا يوجد توكن/نشر، لذلك لا يوجد رابط إنتاجي ولا اختبار HTTPS خارجي.
- **PostgreSQL على Railway**: الكود والـDockerfile جاهزان، لكن لم تُنشأ قاعدة إنتاجية.
- **Gemini/Mistral بمفاتيح حقيقية**: لم تصل المفاتيح؛ الاختبارات الحقيقية تُنفَّذ تلقائياً بعد ضبطها.
- **iOS على جهاز/محاكي**: لا Xcode. لم يُبنَ IPA موقّع.
- **جسر ExpertOption/MT5**: غير مضبوط، لذلك الأسواق الستة ترجع `DATA UNAVAILABLE` كما هو مطلوب.

## 5. أوامر إعادة الاختبار

```bash
cd backend && python -m pytest -q
cd ../mobile && npm test
cd .. && /tmp/actionlint .github/workflows/*.yml
```
