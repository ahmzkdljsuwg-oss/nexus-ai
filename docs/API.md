# NEXUS AI API

Base URL: `https://<server>/api`
Auth: `Authorization: Bearer <jwt>` لكل المسارات عدا register/login/health.

| Method | Path | الغرض | Auth |
|---|---|---|---|
| GET | `/health` | حالة الخادم والقاعدة وGemini | لا |
| POST | `/auth/register` | تسجيل حساب | لا |
| POST | `/auth/login` | تسجيل دخول وإصدار JWT | لا |
| POST | `/auth/logout` | إلغاء الجلسة الحالية | نعم |
| GET | `/auth/me` | بيانات الحساب | نعم |
| GET | `/auth/sessions` | قائمة الجلسات | نعم |
| DELETE | `/auth/sessions/{id}` | إلغاء جلسة | نعم |
| GET | `/account` | بيانات الحساب | نعم |
| PATCH | `/account` | تعديل الاسم/كلمة المرور (يلغي الجلسات عند تغيير كلمة المرور) | نعم |
| POST | `/account/change-password` | تغيير كلمة المرور فقط | نعم |
| GET | `/settings` | التفضيلات | نعم |
| PATCH | `/settings` | اللغة/المظهر/الصوت/الصوت المساعد | نعم |
| GET | `/security/status` | حالة الجلسات والبيانات والفحوصات | نعم |
| GET | `/projects` | قائمة المشاريع | نعم |
| POST | `/projects` | إنشاء مشروع | نعم |
| GET | `/projects/{id}` | مشروع واحد | نعم |
| PATCH | `/projects/{id}` | تعديل مشروع | نعم |
| DELETE | `/projects/{id}` | حذف مشروع | نعم |
| GET | `/files` | قائمة الملفات (فلترة `project_id` و`folder`) | نعم |
| POST | `/files` | إنشاء ملف | نعم |
| GET | `/files/{id}` | قراءة ملف | نعم |
| PATCH | `/files/{id}` | تعديل/إعادة تسمية/نقل | نعم |
| DELETE | `/files/{id}` | حذف ملف | نعم |
| GET | `/chats` | قائمة المحادثات | نعم |
| POST | `/chats` | إنشاء محادثة | نعم |
| GET | `/chats/{id}` | محادثة مع رسائلها | نعم |
| PATCH | `/chats/{id}` | إعادة تسمية/ربط مشروع | نعم |
| DELETE | `/chats/{id}` | حذف محادثة | نعم |
| POST | `/assistant/chat` | سؤال Gemini وسياق المشروع/الملف | نعم |
| GET | `/tools` | الأدوات المتاحة فعلياً | نعم |

## Assistant request

```json
{
  "message": "لخّص ملف notes.md وأنشئ قائمة مهام",
  "chat_id": null,
  "project_id": null,
  "mode": "text"
}
```

Response:

```json
{
  "chat_id": "...",
  "answer": "...",
  "model": "gemini-2.5-flash",
  "actions": ["create_file"],
  "created_files": ["/tasks.md"],
  "used_context": ["project:...", "file:..."]
}
```

- بدون `GEMINI_API_KEY` → `503 {"detail":"GEMINI_NOT_CONFIGURED"}` ولا يوجد رد وهمي.
- كل مشروع له سياقه المستقل؛ لا يمكن تمرير `project_id` يملكه مستخدم آخر.
- أدوات Gemini محصورة في إنشاء/تعليم الملفات والمشاريع داخل حساب المستخدم الحالي.
