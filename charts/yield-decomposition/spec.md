# The 10-year Treasury yield since December 2023, split into expected rates and risk premiums

Status: built in R from the Fed Board's D'Amico, Kim, and Wei (DKW) estimates through August 31, 2026 (fetched September 26, 2026). Original chart in the style of decompositions by Ernie Tedeschi and Moody's Analytics.

## Question

How does the Fed Board's model split the change in the 10-year yield since December 2023 among expected real short-term rates, expected inflation, and the two risk premiums? `charts/yield-rise-by-model/` compares two models since February 2026.

## Related work

The model's authors are credited on the chart. The chart doesn't maintain anyone's analysis, so there is no `reproduce.R`; the model output is used as published.

Charts in the same style: Ernie Tedeschi, decomposition of the 30-year yield since December 31, 2025 from an ACM-type model with four parts (real policy rate, real term premium, expected inflation, inflation risk premium), on X, August 2026; Moody's Analytics (Mark Zandi), decomposition of the 10-year yield since the start of the Iran war, from Federal Reserve data, on X, July 2026.

Why models differ: Federal Reserve Board, "Robustness of Long-Maturity Term Premium Estimates," FEDS Notes, April 3, 2017. Most of the gap comes from Kim-Wright's use of survey forecasts of short rates; ACM with the same surveys gives similar estimates.

## Sources

| Data | Provider | Fetch | Series |
|---|---|---|---|
| 10-year yield decomposition, daily | Fed Board staff, DKW model, updated monthly | `fetch_frb_dkw()` | `DKW_updates.csv`: `nominal.yield.fitted.10`, `exp.real.short.rate.10`, `real.term.prem.10`, `exp.inflation.10`, `inflation.risk.prem.10` |

## Transformations

- The four parts sum to the fitted 10-year zero-coupon yield. The TIPS liquidity premium, also in the file, is part of inflation compensation measured from inflation-protected securities, not of the nominal yield, and is not used.
- Monthly averages of daily values, then the change from the December 2023 average.
- Term premium = real term premium plus inflation risk premium. Expected rates = expected real short-term rates plus expected inflation.
- The CSV has monthly levels since 1983 and changes since December 2023.

## Vintages

- `data/frb_dkw_10_year_<last date>.csv`: daily 10-year parts since 2015, named by the file's last observation, since it has no release date. The model is re-estimated from time to time (the current file uses data through November 12, 2025), which revises history; the git diff of the snapshot shows by how much.
- Updates come about the fourth business day of each month, so the chart runs through the end of the previous month.

## Known breaks and caveats

- The decomposition is a model estimate, not an observation, and uses survey forecasts of inflation and bill rates.
- The fitted zero-coupon yield differs from the market 10-year note yield by a few basis points, and monthly averages differ from end-of-period values.
- A decomposition separates expectations from compensation. It doesn't identify why either moved. Fiscal risk, Treasury supply, AI-related corporate borrowing, and foreign demand would all show up in the term premium together.

## Decision log

- 2026-09-26: Start the interest rates topic with a term premium chart.
- 2026-09-26: A monthly decomposition of the change since December 2023 from DKW, following how Tedeschi and Moody's chart it, replaces a two-model bar chart (ACM against Kim-Wright, change over one and two years). Time series of levels and of 12-month changes were tried and dropped as hard to read. DKW is the one public model that also splits real rates from inflation. Renamed from `charts/term-premium/`.
- 2026-09-26: A base of December 2021 was tried and dropped: the 2022 change in expected rates set the scale and made the other parts hard to see.
