# NEXUS AI — تقرير الاختبار الفعلي

**تاريخ التشغيل:** 2026-11-09
**البيئة:** Linux، Python 3.13 (مجلد افتراضي مشترك)، SQLite مؤقت للاختبار.
**ملاحظة:** `backend-legacy/` هو Backend قديم غير مرتبط بالتطبيق، وتقريره محفوظ في `backend-legacy/TEST-REPORT-legacy.md`.

---

## 1. Backend

```bash
cd backend
python -m pytest -q
```

**النتيجة الفعلية:**

```
..................                                                       [100%]
18 passed in 1.19s
```

| # | الاختبار | ما تم التحقق منه |
|---|---|---|
| 1 | `test_market_keys_and_durations` | مفاتيح الأسواق السبعة والمدد المدعومة |
| 2 | `test_ai_json_parser_rejects_markdown_and_clamps` | رفض JSON غير صالح وتقييد القيم |
| 3 | `test_compare_ai_without_models_keeps_engine` | غياب النماذج لا يوقف المحرك الفني |
| 4 | `test_compare_ai_blocks_three_way_split` | منع الخلاصة عند تعارض النموذجين |
| 5 | `test_analysis_persists_only_actionable_results` | لا يُحفظ إلا التحليل القابل للتنفيذ |
| 6 | `test_health_and_markets_shapes` | شكل `/api/health` و`/api/markets` |
| 7 | `test_market_snapshot_supports_detail_screen` | بيانات شاشة تفاصيل السوق |
| 8 | `test_analyse_manual_contract` | عقد `/api/analyse` مع مدة يدوية |
| 9 | `test_auto_duration_reports_reason` | «تحليل الوقت حسب الشمعة» يشرح سبب اختيار المدة |
| 10 | `test_recommendations_and_history_match_mobile` | توافق التوصيات والسجل مع التطبيق |
| 11 | `test_chat_reports_missing_key_without_inventing` | الدردشة بلا مفتاح ترجع خطأ صريحاً لا رداً مخترعاً |
| 12 | `test_market_snapshot_switches_asset` | تبديل الأصل داخل السوق |
| 13 | `test_pinned_asset_never_silently_switches` | عدم تبديل الأصل المثبت بصمت |
| 14 | `test_no_trade_is_not_stored` | `NO TRADE` لا يُسجل كتوصية |
| 15 | `test_paid_routes_are_rate_limited` | تقييد معدل الطلبات المكلفة |
| 16 | `test_both_models_receive_identical_market_payload` | Gemini وMistral يستلمان نفس بيانات السوق |
| 17 | `test_gemini_error_does_not_leak_key` | الخطأ لا يكشف المفتاح |
| 18 | `test_chat_uses_separate_chat_prompt` | الدردشة منفصلة عن محرك التحليل |

### ما لا تثبته هذه الاختبارات

- لا تتصل بمصادر أسعار حقيقية؛ تستخدم مزودات اختبار حتمية.
- لا تنفّذ مكالمات Gemini أو Mistral بمفاتيح إنتاجية.
- لا تثبت أن OTC أو Smarty متاحان؛ غياب الجسر يعطي `DATA_UNAVAILABLE`.

---

## 2. Mobile

```bash
cd mobile
npm test
```

**النتيجة الفعلية:** 3 اختبارات منطق ناجحة (تسميات الاتجاه والنتيجة بالعربية والإنجليزية، ومعالجة `UNVERIFIED`).

```bash
npx expo export --platform ios
```

**النتيجة:** نجح، وأنتج حزمة Hermes iOS.

---

## 3. بناء IPA (GitHub Actions)

- Workflow: `.github/workflows/expo-ios-build.yml`
- Run: `43714673687` — **success**
- Runner: `macos-15`
- Artifact: `NEXUSAI-unsigned-ipa` — 5,086,426 بايت
- SHA-256: `764b08b606de63226cca4c4ff563e192af4d823f627a2150a1977c954da5be22`
- Bundle ID: `ai.nexus.app`
- Binary: `NEXUSAI` — Mach-O 64-bit arm64، 6,389,352 بايت
- `main.jsbundle` موجود — 2,650,717 بايت
- لا `_CodeSignature` ولا `embedded.mobileprovision` → غير موقّع
- فحص الأسرار داخل الحزمة: لا مفاتيح Google/Mistral/OpenAI ولا مفاتيح خاصة

---

## 4. غير مختبر

- نشر Railway فعلي وPostgreSQL إنتاجي.
- `/api/health` و`/api/markets` و`/api/analyse` و`/api/recommendations` و`/api/history` و`/api/chat` على خدمة منشورة.
- اتصال تطبيق iPhone بخادم إنتاجي.
- توقيع IPA وتثبيته عبر ESign على جهاز.
- بيانات OTC/Smarty/Football/Luxury/AI/Cricket الحقيقية.
