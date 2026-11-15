# نشر NEXUS AI على Railway

## 1. المتطلبات

- حساب Railway.
- مستودع GitHub متصل.
- مفاتيح: `TWELVE_DATA_API_KEY`، `GEMINI_API_KEY`، `MISTRAL_API_KEY`.
- جسر بيانات حقيقي للأسواق غير FOREX: `EO_BRIDGE_URL` + `EO_BRIDGE_KEY` أو `MT5_BRIDGE_URL` + `MT5_BRIDGE_KEY`.

## 2. الخطوات

1. New Project → Deploy from GitHub repo.
2. أضف **PostgreSQL**.
3. في خدمة التطبيق أضف:
   ```
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   GEMINI_API_KEY=...
   MISTRAL_API_KEY=...
   TWELVE_DATA_API_KEY=...
   EO_BRIDGE_URL=...
   EO_BRIDGE_KEY=...
   LOG_LEVEL=INFO
   ```
4. اترك Root Directory فارغاً (Dockerfile الجذر ينسخ `backend/`)، أو اضبطه على `backend`.
5. Healthcheck: `/api/health`.
6. انشر ثم تحقق:
   ```bash
   curl -fsS https://<service>.up.railway.app/api/health
   curl -fsS https://<service>.up.railway.app/api/markets
   ```

## 3. شروط النجاح

- `status` في `/api/health` يساوي `ok`.
- `database` يساوي `postgresql` وليس `sqlite`.
- `ai.gemini.configured` و`ai.mistral.configured` يساويان `true`.
- `/api/markets` يرجع الأسواق السبعة، مع `DATA_UNAVAILABLE` للأسواق التي لا جسر لها بدلاً من بيانات وهمية.

## 4. ما لم يُنفّذ

لم يُنشر المشروع من مساحة العمل لعدم توفر `RAILWAY_TOKEN`. لا توجد خدمة إنتاجية معلنة، ولا تُعلن حالة Online قبل التحقق الفعلي من العنوان.
