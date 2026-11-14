# NEXUS AI — تقرير الاختبار الفعلي

**تاريخ التشغيل:** 2026-11-14
**البيئة:** Linux (بيئة العمل)، Python 3.13 داخل `.venv`، SQLite مؤقت + PostgreSQL 18.7 محلي.
**الأمر:**

```bash
cd backend
.venv/bin/python -m pytest -q
```

**النتيجة الفعلية:**

```
.................s.........................                              [100%]
42 passed, 1 skipped in 7.51s
```

نفس المجموعة على PostgreSQL 18.7:

```bash
NEXUS_TEST_DATABASE_URL='postgresql+asyncpg://nexus@127.0.0.1:55432/nexus_test' \
  .venv/bin/python -m pytest -q
# 42 passed, 1 skipped in 7.00s
```

الاختبار المتخطى هو اتصال Gemini الحقيقي. يعمل تلقائياً بمجرد وجود `GEMINI_API_KEY`:

```bash
GEMINI_API_KEY=... .venv/bin/python -m pytest tests/test_assistant.py -q
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
| 18 | `test_health_over_real_http` | الخادم يعمل عبر TCP حقيقي ويقرأ PostgreSQL/SQLite |
| 19 | `test_register_login_and_read_account_over_real_http` | تسجيل ودخول وقراءة الحساب عبر HTTP فعلي |
| 20 | `test_protected_route_rejects_missing_token_over_real_http` | رفض الطلبات المحمية بلا توكن عبر HTTP |
| 21 | `test_railway_uses_dockerfile_and_health_check` | إعداد Railway يبني Dockerfile ويفحص `/api/health` |
| 22 | `test_dockerfile_runs_as_non_root_and_exposes_port` | الحاوية تعمل بمستخدم غير جذري وتفتح المنفذ |
| 23 | `test_env_example_lists_required_runtime_variables_without_values` | المتغيرات المطلوبة موجودة بلا قيم أسرار |

---

## ما لم يُختبر في هذه البيئة (بصراحة)

| البند | السبب | كيف يُختبر |
|---|---|---|
| بناء مشروع Xcode | لا يوجد macOS/Xcode في بيئة Linux | ✅ نجح في GitHub Actions run `43600526631` |
| محتوى IPA | تم تنزيله وفحصه محلياً | ✅ `Payload/NexusAI.app/{Info.plist,NexusAI}` موجودان |
| تشغيل التطبيق على iPhone | لا جهاز/محاكي iOS هنا | جهاز حقيقي بعد التوقيع |
| اتصال التطبيق بالخادم حياً | يحتاج Build + خادم منشور | افتح التطبيق واكتب عنوان الخادم |
| Gemini حقيقي | لا يوجد `GEMINI_API_KEY` في بيئة العمل | يعمل الاختبار تلقائياً عند توفر المفتاح |
| الميكروفون والتعرف على الكلام | يحتاج جهاز iOS وأذونات فعلية | جرّب زر الميكروفون وارفض/اقبل الإذن |
| نشر Railway | يحتاج حساب Railway وصلاحيات | `docs/DEPLOYMENT.md` |

---

## ملاحظات جودة

- الاختبارات تستخدم `MockTransport` لـ Gemini عند الحاجة، وتفصل بوضوح بين محاكاة الشبكة والاتصال الحقيقي (المتخطى).
- لا توجد أسعار أو بيانات أعمال وهمية في أي مسار إنتاجي.
- اختبارات الملفات تتحقق من منع Path Traversal.
- اختبارات العزل تتحقق من 404 عند محاولة الوصول لبيانات مستخدم آخر.
