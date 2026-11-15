# نشر NEXUS AI على Railway

## المسار الآلي (جاهز، يبدأ عند توفر RAILWAY_TOKEN)

1. أضف `RAILWAY_TOKEN` في **Settings → Secrets and variables → Actions**. استخدم Account Token من Railway (وليس Project Token)، لأنه يجب إنشاء مشروع وخدمات جديدة.
2. اختيارياً أضف `GEMINI_API_KEY` و`GEMINI_MODEL` (`gemini-2.5-flash`).
3. إن كان حسابك يحتوي أكثر من Workspace، أضف Variable باسم `RAILWAY_WORKSPACE` بقيمة اسم أو معرف الـ Workspace.
4. Actions → **Deploy Backend to Railway** → Run workflow.

الـ workflow ينفّذ `scripts/deploy_railway.py`، الذي:

- ينشئ مشروع `nexus-ai` أو يعيد استخدامه.
- يضيف خدمة PostgreSQL، ويضيف خدمة `nexus-api`.
- يضبط `ENVIRONMENT=production` و`JWT_SECRET` عشوائياً و`DATABASE_URL=${{Postgres.DATABASE_URL}}`.
- يضبط `GEMINI_API_KEY` فقط عند توفره.
- يرفع الكود ويشغّل الحاوية.
- ينشئ دومين عاماً، وينتظر `/api/health` حتى تصبح قاعدة البيانات `ok`.
- ينشئ حساب تحقق مؤقتاً ويستدعي `/api/assistant/chat` للتأكد من Gemini الحقيقي.
- يرفع `deployment.json` كـ artifact دون أي أسرار.

لا تعتبر النشر ناجحاً قبل ظهور `RESULT: deployed and verified` وartifact يحتوي `verification_exit_code: 0`.

### التشغيل من جهازك بدلاً من Actions

```bash
export RAILWAY_TOKEN=...        # في طرفيتك فقط، لا في ملف داخل المستودع
export GEMINI_API_KEY=...       # اختياري
python3 scripts/deploy_railway.py
```

`railway CLI` يجب أن يكون مثبتاً. السكربت لا يطبع أي مفتاح.

## المسار اليدوي

1. أنشئ مشروعاً في Railway.
2. أضف **Database → PostgreSQL** (اسم الخدمة `Postgres`).
3. أضف **Service → Deploy from GitHub repo** واختر `ahmzkdljsuwg-oss/nexus-ai`.
4. اترك **Root Directory** فارغاً. Railway يقرأ `railway.json` و`Dockerfile` من جذر المستودع.
   - البديل: Root Directory = `backend` لاستخدام `backend/railway.json` و`backend/Dockerfile`.
5. Variables:

```
ENVIRONMENT=production
LOG_LEVEL=INFO
JWT_SECRET=<openssl rand -hex 48>
GEMINI_API_KEY=<مفتاح Google AI Studio>
GEMINI_MODEL=gemini-2.5-flash
DATABASE_URL=${{Postgres.DATABASE_URL}}
CORS_ORIGINS=*
```

التطبيق يحوّل تلقائياً `postgres://` و`postgresql://` إلى `postgresql+asyncpg://`، فلا حاجة لتعديل القيمة يدوياً.

6. Deploy، ثم تحقق:

```bash
curl -s https://<service>.up.railway.app/api/health
# {"status":"ok","service":"NEXUS AI","database":"ok","gemini_configured":true,...}
```

7. التحقق الكامل (ينشئ حساب تحقق تلقائياً إذا لم تضبط بياناته):

```bash
cd backend
python scripts/verify_production.py https://<service>.up.railway.app --gemini
```

## تطبيق iOS

- افتح التطبيق → شاشة الدخول → Server URL = رابط Railway.
- أنشئ حساباً ثم سجّل الدخول.
- الرابط يُحفظ في `UserDefaults` ويمكن تغييره من شاشة الدخول/الإعدادات.
- التطبيق لا يحتاج أي مفتاح API.

## ملاحظات تشغيلية

- `healthcheckPath` هو `/api/health` مع مهلة 120 ثانية.
- إعادة التشغيل التلقائي: `ON_FAILURE` × 10.
- الحاوية تعمل بمستخدم غير جذري `nexus`.
- مخطط القاعدة يُنشأ تلقائياً عند الإقلاع عبر `init_db()`.
- لا تضع `GEMINI_API_KEY` في GitHub أو داخل تطبيق iOS.
- لم يُنشر الخادم فعلياً بعد لأن `RAILWAY_TOKEN` لم يصل. جميع الملفات أعلاه مكتملة.
