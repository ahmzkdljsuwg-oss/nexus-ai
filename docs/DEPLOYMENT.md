# نشر NEXUS AI على Railway

## 1. الخادم + قاعدة البيانات

1. أنشئ مشروعاً في Railway.
2. أضف **Database → PostgreSQL** (اسم الخدمة `Postgres`).
3. أضف **Service → Deploy from GitHub repo** واختر `ahmzkdljsuwg-oss/nexus-ai`.
4. اترك **Root Directory** فارغاً. Railway يقرأ `railway.json` و`Dockerfile` من جذر المستودع.
   - البديل: اترك Root Directory = `backend` لاستخدام `backend/railway.json` و`backend/Dockerfile`.
5. Variables (Service → Variables):

```
ENVIRONMENT=production
LOG_LEVEL=INFO
JWT_SECRET=<openssl rand -hex 48>
GEMINI_API_KEY=<مفتاح Google AI Studio>
GEMINI_MODEL=gemini-2.5-flash
DATABASE_URL=${{Postgres.DATABASE_URL}}
CORS_ORIGINS=*
```

`DATABASE_URL` من خدمة Postgres يجب أن يبقى بصيغة `postgresql+asyncpg://`. إن أعطاك Railway `postgresql://` فقط، استبدل البادئة بـ `postgresql+asyncpg://`.

6. Deploy. تحقق:

```bash
curl -s https://<service>.up.railway.app/api/health
# {"status":"ok","service":"NEXUS AI","database":"ok","gemini_configured":true,...}
```

7. تحقق من القاعدة والمخطط ثم من الاتصال الكامل:

```bash
cd backend
railway run --service <service-name> python scripts/init_db.py
python scripts/verify_production.py https://<service>.up.railway.app
```

`init_db.py` ينشئ الجداول إذا لم تكن موجودة، ويعرض: `chats, files, messages, projects, sessions, users`.

8. راقب Logs: يجب أن تظهر `Application startup complete` بدون `JWT_SECRET`.

## 2. تطبيق iOS

- افتح التطبيق → شاشة الدخول → Server URL = رابط Railway.
- أنشئ حساباً ثم سجّل الدخول.
- لا يحتاج التطبيق أي مفتاح API.

## 3. ملاحظات تشغيلية

- `healthcheckPath` هو `/api/health` مع مهلة 120 ثانية.
- إعادة التشغيل التلقائي: `ON_FAILURE` × 10.
- الحاوية تعمل بمستخدم غير جذري `nexus`.
- لا تضع `GEMINI_API_KEY` في GitHub أو داخل تطبيق iOS.

## 4. لماذا لا يوجد نشر تلقائي من بيئة العمل؟

النشر إلى حسابك يتطلب صلاحية Railway ورابط الخدمة ومفتاح Gemini. لم تُزوَّد بيئة العمل بها، لذلك لم يُنشر الخادم فعلياً. الملفات والخطوات أعلاه مكتملة، والتحقق النهائي يتم بعد النشر بكلمة `curl` أعلاه.
