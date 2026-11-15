# NEXUS AI

**NEXUS AI** هو تطبيق iPhone لتحليل الأسواق وتقديم توصيات تداول (UP / DOWN / NO TRADE)، مع Backend على FastAPI وسبعة أسواق منفصلة:

`OTC` · `SMARTY` · `FOOTBALL` · `LUXURY` · `AI INDEX` · `CRICKET` · `FOREX`

> التطبيق للتحليل والتوصيات فقط، ولا ينفّذ صفقات.

---

## 1. حالة النسخة الحالية

| العنصر | الحالة | الدليل |
|---|---|---|
| Backend FastAPI | ✅ يعمل | 18 اختباراً ناجحاً |
| اختبارات HTTP للعقود | ✅ تعمل | `backend/tests/test_http_contract.py` |
| تحليل الشموع والمؤشرات وSMC | ✅ يعمل | `backend/engines/` |
| Gemini + Mistral ومقارنة النتائج | ⚠️ الكود جاهز | يحتاج `GEMINI_API_KEY` و`MISTRAL_API_KEY` حقيقيين |
| الأسواق السبعة منفصلة | ✅ في التطبيق والـAPI | `/api/markets` |
| بيانات FOREX / GOLD | ⚠️ تعتمد على المفتاح | Twelve Data أو Yahoo fallback |
| بيانات OTC / SMARTY / FOOTBALL / LUXURY / AI / CRICKET | ⚠️ تحتاج جسراً حقيقياً | `EO_BRIDGE_URL` و`EO_BRIDGE_KEY` أو `MT5_BRIDGE_URL` |
| بناء IPA | ✅ تم بناؤه والتحقق منه | `NEXUS-AI.ipa` + `docs/IPA-BUILD-REPORT.md` |
| توقيع IPA | ❌ لم يتم | يحتاج شهادة Apple وProvisioning Profile |
| نشر Railway | ❌ لم يتم | يحتاج `RAILWAY_TOKEN` أو ربط الحساب |

**قاعدة صريحة:** عند غياب مصدر بيانات حقيقي أو كافٍ، يرجع الـBackend خطأ `DATA_UNAVAILABLE` أو توصية `NO TRADE`، ولا يخترع سعراً أو شمعة أو توصية. كما لا يعرض التطبيق حالة `ONLINE` قبل التحقق من رابط الخادم.

---

## 2. الهيكل

```
NEXUS-AI/
├── backend/                     # الـBackend الحالي (FastAPI)
│   ├── app/
│   │   ├── main.py              # /api/health, markets, analyse, recommendations, history, chat
│   │   ├── market_service.py    # تنسيق الأسواق والمصادر والتحليل
│   │   ├── ai_clients.py        # Gemini + Mistral
│   │   ├── db.py                # SQLAlchemy + SQLite/PostgreSQL
│   │   └── schemas.py
│   ├── engines/                 # التحليل الفني وهيكل السوق
│   ├── providers/               # twelve data, yahoo, eobridge, mt5, swissquote
│   ├── tests/                   # 18 اختباراً
│   └── Dockerfile / railway.json / requirements.txt / .env.example
├── mobile/                      # تطبيق iPhone (Expo / React Native)
│   ├── App.js
│   ├── src/screens/             # Home, MarketDetail, Recommendations, History, Chat, Settings
│   ├── src/state/               # Backend URL + حالة الاتصال
│   └── tests/                   # 3 اختبارات منطق
├── ios/                         # نسخة SwiftUI الأصلية (محفوظة، غير مستخدمة في بناء IPA الحالي)
├── backend-legacy/              # Backend سابق محفوظ للمرجع فقط
├── docs/                        # تقارير البناء والاختبار والتوقيع ومصادر البيانات
├── .github/workflows/           # CI + بناء IPA على macOS
├── Dockerfile                   # نشر من جذر المستودع
├── railway.json
└── .env.example                 # أسماء المتغيرات فقط، بدون أسرار
```

> `backend-legacy/` غير مستخدم في النشر ولا في التطبيق. أُبقي للمرجع فقط.

---

## 3. التشغيل المحلي

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

- الصحة: `http://localhost:8000/api/health`
- الوثائق: `http://localhost:8000/docs`
- الأسواق: `http://localhost:8000/api/markets`

### التطبيق

```bash
cd mobile
npm ci
npm test
npx expo start
```

افتح الإعدادات داخل التطبيق وأدخل رابط الـBackend (مثل `https://your-service.up.railway.app`). لا يوجد رابط إنتاجي مثبت داخل التطبيق ولا `localhost` كقيمة افتراضية.

---

## 4. واجهة الـAPI

| الطريقة | المسار | الوظيفة |
|---|---|---|
| GET | `/api/health` | حالة الخدمة وقاعدة البيانات والمزودين |
| GET | `/api/markets` | ملخص الأسواق السبعة |
| GET | `/api/markets/{key}` | لقطة سوق/أصل مع الشموع |
| POST | `/api/analyse` | تحليل كامل وإصدار توصية |
| GET | `/api/recommendations` | أفضل التوصيات الجاهزة |
| GET | `/api/history` | السجل والإحصائيات |
| POST | `/api/chat` | محادثة Gemini منفصلة عن محرك التحليل |

مثال `POST /api/analyse`:

```json
{
  "market": "FOREX",
  "asset": "EUR/USD",
  "duration_mode": "auto",
  "duration": null,
  "language": "ar"
}
```

`duration_mode`: `auto` (تحليل الوقت حسب الشمعة) أو `manual` مع `duration` بالثواني (5–3600).

---

## 5. مصادر البيانات

| السوق | المصدر | الحالة |
|---|---|---|
| FOREX | Twelve Data، ثم Yahoo fallback | يحتاج `TWELVE_DATA_API_KEY` |
| OTC | جسر ExpertOption | يحتاج `EO_BRIDGE_URL` + `EO_BRIDGE_KEY` |
| SMARTY | جسر ExpertOption / MT5 | يحتاج جسراً يثبت دعم Smarty |
| FOOTBALL / LUXURY / AI INDEX / CRICKET | جسر ExpertOption / MT5 | لا تُستخدم أسعار بديلة |
| GOLD | Twelve Data / Yahoo | يعتمد على تغطية الخطة |

التفاصيل والقيود في `docs/DATA-SOURCES.md`. لا يُعتبر أي سوق مدعوماً لمجرد وجود اسمه في القائمة.

---

## 6. متغيرات البيئة

كل الأسماء في `.env.example`، والقيم تُضبط في Railway Variables أو محلياً في `.env` غير المرفوع:

```
TWELVE_DATA_API_KEY=
EO_BRIDGE_URL=
EO_BRIDGE_KEY=
MT5_BRIDGE_URL=
MT5_BRIDGE_KEY=
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.0-flash
MISTRAL_API_KEY=
MISTRAL_MODEL=mistral-small-latest
DATABASE_URL=sqlite+aiosqlite:///./nexus.db
CORS_ORIGINS=*
LOG_LEVEL=INFO
SCANNER_ENABLED=true
HISTORY_LIMIT=200
REQUEST_MIN_INTERVAL=1.0
```

لإنتاج Railway استخدم PostgreSQL:

```
DATABASE_URL=postgresql+asyncpg://USER:PASSWORD@HOST:PORT/railway
```

لا تضع أي مفتاح داخل تطبيق iPhone أو GitHub أو السجلات.

---

## 7. النشر على Railway

1. أنشئ مشروعاً جديداً واربط مستودع GitHub.
2. أضف خدمة **PostgreSQL**.
3. من خدمة Backend أضف Reference لـ `DATABASE_URL` من خدمة PostgreSQL.
4. أضف المتغيرات السرية أعلاه.
5. اترك **Root Directory** فارغاً (جذر المستودع) لأن `Dockerfile` الجذر ينسخ `backend/`، أو اضبطه على `backend` لاستخدام `backend/Dockerfile`.
6. Start Command: `sh -c 'uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}'`.
7. Healthcheck: `/api/health`.
8. بعد النشر تحقق فعلياً:
   ```bash
   curl https://<service>.up.railway.app/api/health
   curl https://<service>.up.railway.app/api/markets
   ```
9. أدخل نفس الرابط في إعدادات التطبيق.

لم يُنفّذ النشر من مساحة العمل، لذلك لا توجد خدمة إنتاجية مُعلنة بعد.

---

## 8. بناء IPA والتوقيع

### بناء غير موقّع

```bash
cd mobile
npx expo prebuild --platform ios --no-install
cd ios && pod install
xcodebuild -workspace NEXUSAI.xcworkspace -scheme NEXUSAI \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO archive
```

أو شغّل workflow **Build Expo iOS IPA** على GitHub Actions (macOS 15).

الملف الحالي:

- `NEXUS-AI.ipa` — 5,086,426 بايت
- SHA-256: `764b08b606de63226cca4c4ff563e192af4d823f627a2150a1977c954da5be22`
- Bundle ID: `ai.nexus.app`
- arm64، iOS 15.1+
- **غير موقّع** ولم يُختبر تثبيته على جهاز

### التوقيع

- **ESign:** راجع `docs/ESIGN-INSTALL.md` و`docs/SIGNING.md`.
- **بناء موقّع من GitHub:** شغّل workflow **Build Signed Expo iOS App** بعد إضافة:
  - `IOS_CERT_P12_BASE64`
  - `IOS_CERT_PASSWORD`
  - `IOS_PROVISIONING_PROFILE_BASE64`
  - `IOS_TEAM_ID`

يحتاج البناء شهادة Apple صالحة، وProvisioning Profile من نوع Ad Hoc أو Development يطابق `ai.nexus.app`، وUDID الجهاز. الـ workflow يتحقق من ذلك قبل البناء ومن التوقيع بعده. دون هذه الأسرار يبقى الملف غير موقّع، ولا يصح وصفه بأنه جاهز للتثبيت.

مراجعة الحزمة والـ workflow: `docs/IPA-FINAL-REVIEW.md`.

---

## 9. الاختبارات

```bash
# Backend
cd backend && python -m pytest -q
# Mobile
cd mobile && npm test
```

النتائج الموثقة في `docs/TEST-REPORT.md` و`docs/NEXUS-AI-FINAL-REPORT.md`.

**لم تُختبر:** مكالمات Gemini/Mistral بمفتاح إنتاجي، النشر الفعلي على Railway، اتصال التطبيق بخادم منشور، بيانات OTC/Smarty الحقيقية، تثبيت IPA على جهاز.
