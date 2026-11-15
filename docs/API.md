# NEXUS AI API

Base URL: عنوان خدمة Railway، وكل المسارات تحت `/api`.
لا يوجد مصادقة مستخدم في نسخة التوصيات الحالية؛ لا تُستخدم لحفظ بيانات شخصية.

| Method | Path | الغرض |
|---|---|---|
| GET | `/api/health` | حالة الخدمة، القاعدة، والمزودون (بدون أسرار) |
| GET | `/api/markets` | الأسواق السبعة وملخص الحالة |
| GET | `/api/markets/{key}` | لقطة سوق أو أصل، مع الشموع |
| POST | `/api/analyse` | تحليل كامل وإصدار توصية |
| GET | `/api/recommendations` | أفضل التوصيات الجاهزة |
| GET | `/api/history?limit=50` | السجل والإحصائيات |
| POST | `/api/chat` | محادثة Gemini (منفصلة عن التحليل) |

مفاتيح `key`: `OTC`, `SMARTY`, `FOOTBALL`, `LUXURY`, `AI`, `CRICKET`, `FOREX`.

## POST /api/analyse

```json
{
  "market": "FOREX",
  "asset": "EUR/USD",
  "duration_mode": "auto",
  "duration": null,
  "language": "ar"
}
```

- `duration_mode=auto`: يحلل الشموع ويختار المدة مع ذكر السبب.
- `duration_mode=manual`: يستخدم `duration` بالثواني (5–3600) ولا يغيّره.

الاستجابة تحتوي `direction` (`UP` / `DOWN` / `NO TRADE`)، `reasons`، `duration_label`، `entry`، `evidence_score`، `confidence`، و`source`.

## الأخطاء

- `503 DATA_UNAVAILABLE`: المصدر غير متاح أو البيانات قديمة/غير صالحة؛ لا توصية.
- `503 GEMINI_UNAVAILABLE`: الدردشة بلا مفتاح أو فشل مؤقت.
- `429`: تجاوز حد الطلبات.

لا تُعاد المفاتيح أو قيمها في أي استجابة أو سجل.
