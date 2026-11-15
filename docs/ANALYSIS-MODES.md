# NEXUS AI — Analysis Modes

Two real server-side modes are exposed through `POST /api/analyse` with
`"analysis_mode": "normal" | "strong"`. The mobile market screen sends the
selected mode and shows `mode_label`, `strong_gate` and duplicate status.

## NORMAL ANALYSIS (`normal`)

- Scores one appropriate frame: 1 minute for ExpertOption assets, 5 minutes for
  Forex / MT5 / Gold.
- Uses the market's registered strategy profile, indicators, SMC and
  Alligator / MA 200 rules already present in `engines/`.
- Faster than strong mode. It still refuses to publish a recommendation when
  candles fail validation or the deterministic engine returns NO TRADE.

## STRONG ANALYSIS (`strong`)

- Scores every supported expiry for the asset's market and keeps the strongest
  verified structure (the engine proposes the duration).
- Requires all of the following before a direction is published:
  - at least 3 independent confirmed strategies,
  - confidence >= 70%,
  - data quality >= 65.
- If the gate fails, the response is `NO TRADE` with each failed check listed
  in `strong_gate`. Gemini and Mistral are not called in that case, which
  avoids spending model quota on an unconfirmed setup.
- When the gate passes, Gemini and Mistral analyse the same payload
  independently and `compare_ai` keeps the engine direction only when the
  three-way comparison does not split.

## Candle handling

- Only closed candles are scored. The live bar is reported separately as
  `technical.candle_analysis.forming_candle` with `current_candle_closes_at`.
- The background scanner runs once per new closed candle per market, not on
  every timer tick.
- Duplicate active recommendations for the same asset and direction are not
  stored again; the response sets `duplicate: true` and reuses the open record.

## Data honesty

- Mode logic never fabricates candles or prices.
- A market without a verified feed raises `DATA UNAVAILABLE` and produces no
  recommendation.
- Tests for the mode logic use simulated candles. They prove code paths only;
  they are not evidence that an ExpertOption market feed is available.
