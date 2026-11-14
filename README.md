# NEXUS AI

**نظام تشغيل ذكي مصغّر داخل iPhone** — تطبيق SwiftUI أصلي + خادم FastAPI حقيقي + PostgreSQL + Gemini على الخادم فقط.

> هذا المستودع يحتوي على المنتج الكامل: تطبيق iOS، الخادم، قاعدة البيانات، الاختبارات، ومسار بناء IPA عبر GitHub Actions.
> لا يوجد موقع ويب ولا لوحة ويب منفصلة؛ كل شيء داخل التطبيق.

---

## 1. ما الذي يعمل فعلياً (مُختبر)

| الوظيفة | الحالة | الدليل |
|---|---|---|
| تسجيل حساب جديد | ✅ يعمل | `tests/test_api.py::test_register_login_and_me` |
| تسجيل الدخول والجلسات | ✅ يعمل | `test_register_login_and_me`, `test_session_inventory_and_logout` |
| عزل بيانات المستخدمين | ✅ يعمل | `test_projects_crud_and_user_isolation`, `test_files_are_isolated_between_users` |
| المشاريع (إنشاء/قراءة/تعديل/حذف) | ✅ يعمل | `test_projects_crud_and_user_isolation` |
| الملفات الذكية (إنشاء/تعديل/حذف/مجلدات) | ✅ يعمل | `test_files_create_read_update_rename_delete_and_traversal` |
| المحادثات وسجلها | ✅ يعمل | `test_chats_store_messages_and_are_isolated` |
| الأدوات ومركز الأمان والإعدادات | ✅ يعمل | `test_tools_and_security_surfaces_are_real` |
| تحديث بيانات الحساب وكلمة المرور | ✅ يعمل | `test_account_update_name_and_password` |
| مساعد Gemini | ⚠️ الكود جاهز، يحتاج `GEMINI_API_KEY` | اختبار حقيقي تلقائي عند توفر المفتاح |
| ربط التطبيق بالخادم | ⚠️ يحتاج Build على macOS + جهاز/محاكي | لم يُشغّل هنا (بيئة Linux) |
| بناء IPA | ⚠️ جاهز عبر GitHub Actions | workflow: `.github/workflows/ios-build.yml` |

**نتيجة آخر تشغيل للاختبارات:** `42 passed, 1 skipped` على SQLite وPostgreSQL — التفاصيل في `docs/TEST-REPORT.md`.

---

## 2. الهيكل

```
nexus-ai/
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI + CORS + health
│   │   ├── config.py            # Settings من متغيرات البيئة
│   │   ├── db.py                # SQLAlchemy async engine/session
│   │   ├── models.py            # User, Session, Project, FileEntry, Chat, Message
│   │   ├── schemas.py           # Pydantic contracts
│   │   ├── deps.py              # Bearer auth + ownership
│   │   ├── security.py          # bcrypt + JWT
│   │   ├── routers/             # auth, account, projects, files, chats, assistant, tools
│   │   └── services/            # gemini.py, assistant.py
│   └── tests/                   # 18 اختباراً (17 نشط + 1 حقيقي اختياري)
├── ios/
│   ├── project.yml              # XcodeGen (بديل منظم لملف pbxproj)
│   └── NexusAI/
│       ├── NexusAIApp.swift
│       ├── Core/                # Models, Theme, Localization, APIClient, AppState, Keychain, VoiceRecognizer
│       ├── Components/          # المكونات البصرية المشتركة
│       ├── Views/               # Home, Auth, ControlCenter
│       └── Views/Apps/          # Assistant, Files, Projects, Studio, Security, Store, Settings
├── .github/workflows/           # iOS build + signed build
├── docs/                        # تقرير الاختبار، API، النشر، دليل IPA
├── Dockerfile
├── railway.json
├── .env.example
└── README.md
```

---

## 3. تشغيل الخادم محلياً

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
cp ../.env.example .env
# عدّل DATABASE_URL و JWT_SECRET
uvicorn app.main:app --reload --port 8080
```

- الصحة: `GET http://localhost:8080/api/health`
- التوثيق التفاعلي: `http://localhost:8080/api/docs`
- اختبارات: `pytest -q`

للاختبار على SQLite السريع:

```bash
DATABASE_URL=sqlite+aiosqlite:///./nexus.db JWT_SECRET=dev-secret uvicorn app.main:app --port 8080
```

---

## 4. تشغيل تطبيق iPhone

المتطلبات: macOS + Xcode 15+ + XcodeGen.

```bash
brew install xcodegen
cd ios
xcodegen generate
open NexusAI.xcodeproj
```

- اختر فريق التوقيع (Signing & Capabilities) إن أردت التشغيل على جهاز حقيقي.
- شغّل على محاكي أو جهاز.
- في شاشة الدخول اكتب عنوان الخادم، مثل `https://your-service.up.railway.app` أو `http://localhost:8080` على المحاكي.

> **مهم:** لا يوجد مفتاح Gemini داخل التطبيق. التطبيق يتحدث مع خادم NEXUS فقط.

---

## 5. النشر على Railway

1. أنشئ خدمة **PostgreSQL** في نفس المشروع.
2. أنشئ خدمة من مستودع GitHub هذا، وحدد **Root Directory = `backend`**.
3. Railway يلتقط `railway.json` و `Dockerfile` تلقائياً. Start: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`.
4. أضف Variables:

| المتغير | إلزامي | الوصف |
|---|---|---|
| `DATABASE_URL` | نعم | من خدمة Postgres — Railway يوفره تلقائياً عند الربط |
| `JWT_SECRET` | نعم | نص عشوائي طويل (مثال: `openssl rand -hex 48`) |
| `GEMINI_API_KEY` | لتشغيل المساعد | مفتاح Google AI Studio، يبقى على الخادم |
| `GEMINI_MODEL` | لا | الافتراضي `gemini-2.5-flash` |
| `ENVIRONMENT` | نعم | `production` |
| `LOG_LEVEL` | لا | `INFO` |
| `CORS_ORIGINS` | لا | الافتراضي `*` (التطبيق الأصلي لا يحتاج CORS) |

5. تحقق: `curl https://<your-service>/api/health` ويجب أن يعيد `"database":"ok"` و `"gemini_configured":true` بعد إضافة المفتاح.
6. افتح التطبيق واكتب عنوان الخادم.

> لم يُنشر هذا الخادم تلقائياً من بيئة العمل لأن نشر Railway يتطلب صلاحية حسابك ومفتاح Gemini الحقيقي. الخطوات أعلاه كاملة ومطابقة لملفات المشروع.

---

## 6. الأمان

- كلمات المرور: bcrypt (12 rounds).
- الجلسات: JWT موقّع بـ `JWT_SECRET`، وقاعدة البيانات تحتفظ بجلسة قابلة للإلغاء.
- كل استعلام مشروع/ملف/محادثة يتحقق من `user_id` — لا وصول عابر للحسابات.
- تغيير كلمة المرور يُلغي الجلسات النشطة (`PATCH /api/account`).
- لا تُسجَّل كلمة المرور أو التوكن أو `GEMINI_API_KEY` في السجلات.
- تطبيق iOS يخزّن التوكن في Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).

---

## 7. دليل IPA

راجع `docs/IPA-GUIDE.md` للفرق بين:

- **Unsigned IPA**: يُبنى بدون شهادة توقيع؛ لا يثبَّت مباشرة، ويحتاج إعادة توقيع عبر ESign/Sideloadly بحسابك.
- **Signed IPA**: موقّع بشهادة Apple صالحة + Provisioning Profile، ويعمل على الأجهزة المصرح بها.

GitHub Actions:
- `Build iOS App` → ينتج `NexusAI-unsigned-ipa` artifact في كل Push.
- `Build Signed iOS App` → يدوي، يحتاج Secrets التوقيع.

---

## 8. ما تبقى بصراحة

- **Build iOS لم يُنفَّذ في بيئة العمل الحالية** (Linux بدون Xcode). الـ workflow جاهز، وأول تشغيل على GitHub Actions سيثبت النتيجة.
- **Gemini لم يُختبر بمفتاح حقيقي هنا** لأنه لا يوجد `GEMINI_API_KEY`; الاختبار يعمل تلقائياً عند توفره.
- **النشر على Railway** يحتاج تنفيذه من حسابك أو تزويدنا بصلاحية؛ لم يُنشر بعد.
- **اختبار الصوت/الميكروفون** يحتاج جهاز iPhone؛ الأذونات مضافة في `Info.plist` والكود جاهز.

لا يُعتبر أي بند أعلاه مكتملاً لمجرد وجود الكود؛ الحالة المذكورة هي ما تم التحقق منه فعلياً.
