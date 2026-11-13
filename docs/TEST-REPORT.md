# NEXUS AI — تقرير الاختبار الفعلي

**تاريخ التشغيل:** 2026-11-09
**البيئة:** Linux (بيئة العمل)، Python 3.13 داخل `.venv`، SQLite مؤقت للاختبار.
**الأمر:**

```bash
cd backend
.venv/bin/python -m pytest -q
```

**النتيجة الفعلية:**

```
.................s                                                        [100%]
17 passed, 1 skipped in 5.88s
```

الاختبار المتخطى هو اتصال Gemini الحقيقي، ويُفعّل صراحةً:

```bash
NEXUS_REAL_GEMINI=1 GEMINI_API_KEY=... .venv/bin/python -m pytest tests/test_assistant.py -q
```

---

## ما تم التحقق منه فعلياً

| # | الاختبار | ماذا يثبت |
|---|---|---|
| 1 | `test_register_login_and_me` | إنشاء حساب، تسجيل دخول (ببريد مختلف الأحرف)، قراءة `/auth/me` |
| 2 | `test_duplicate_registration_and_bad_password` | منع التكرار (409)، رفض كلمة مرور خاطئة (401) |
| 3 | `test_protected_routes_require_a_valid_session` | رفض الطلبات بلا توكن أو بتوكن غير صالح |
| 4 | `test_session_inventory_and_logout` | جلسة حالية، إلغاء الجلسة عند logout |
| 5 | `test_settings_are_persisted` | حفظ اللغة والصوت في قاعدة البيانات |
| 6 | `test_account_update_name_and_password` | تحديث الاسم وكلمة المرور، رفض القديمة وقبول الجديدة |
| 7 | `test_projects_crud_and_user_isolation` | CRUD المشاريع + منع وصول مستخدم آخر (404) |
| 8 | `test_files_create_read_update_rename_delete_and_traversal` | الملفات والمجلدات وإعادة التسمية والحذف ومنع `..` |
| 9 | `test_files_are_isolated_between_users` | عزل ملفات المستخدمين |
| 10 | `test_chats_store_messages_and_are_isolated` | تخزين الرسائل وعزلها |
| 11 | `test_tools_and_security_surfaces_are_real` | قائمة الأدوات وحالة الأمان مبنية على بيانات حقيقية |
| 12 | `test_assistant_requires_gemini_configuration` | بدون مفتاح: 503 `GEMINI_NOT_CONFIGURED` بدلاً من رد وهمي |
| 13 | `test_assistant_saves_history_and_sends_context` | حفظ سجل المحادثة وإرسال سياق المشروع/الملف إلى Gemini |
| 14 | `test_assistant_tool_creates_project_and_file` | تنفيذ أدوات Gemini لإنشاء مشروع وملف فعلياً |
| 15 | `test_assistant_cannot_attach_another_users_project` | منع ربط مشروع مستخدم آخر |
| 16 | `test_gemini_client_uses_header_key_and_surfaces_rate_limit` | المفتاح في هيدر، معالجة 429 |
| 17 | `test_health_reports_database_and_gemini_state` | `/api/health` يعكس حالة القاعدة وGemini |
| 18 (skip) | `test_real_gemini_connection_when_explicitly_enabled` | اتصال Gemini حقيقي عند توفير المفتاح |

---

## ما لم يُختبر في هذه البيئة (بصراحة)

| البند | السبب | كيف يُختبر |
|---|---|---|
| بناء مشروع Xcode | لا يوجد macOS/Xcode في بيئة Linux | GitHub Actions → `Build iOS App` |
| تشغيل التطبيق على iPhone | لا جهاز/محاكي iOS هنا | جهاز حقيقي بعد التوقيع |
| اتصال التطبيق بالخادم حياً | يحتاج Build + خادم منشور | افتح التطبيق واكتب عنوان الخادم |
| Gemini حقيقي | لا يوجد `GEMINI_API_KEY` في بيئة العمل | شغّل اختبار `NEXUS_REAL_GEMINI` أو استخدم المساعد |
| الميكروفون والتعرف على الكلام | يحتاج جهاز iOS وأذونات فعلية | جرّب زر الميكروفون وارفض/اقبل الإذن |
| نشر Railway | يحتاج حساب Railway وصلاحيات | `docs/DEPLOYMENT.md` |

---

## ملاحظات جودة

- الاختبارات تستخدم `MockTransport` لـ Gemini عند الحاجة، وتفصل بوضوح بين محاكاة الشبكة والاتصال الحقيقي (المتخطى).
- لا توجد أسعار أو بيانات أعمال وهمية في أي مسار إنتاجي.
- اختبارات الملفات تتحقق من منع Path Traversal.
- اختبارات العزل تتحقق من 404 عند محاولة الوصول لبيانات مستخدم آخر.
