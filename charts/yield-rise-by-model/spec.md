# The 10-year yield since February 2026, in two models

Status: built in R from the Fed Board's D'Amico, Kim, and Wei (DKW) estimates and the New York Fed's Adrian, Crump, and Moench (ACM) estimates, both through August 31, 2026 (fetched September 26, 2026). Original chart.

## Question

How do two widely used models split the change in the 10-year yield since February 2026 between expected short-term rates and the term premium?

## Related work

See `charts/yield-decomposition/spec.md` for the charts by Ernie Tedeschi and Moody's Analytics this follows. The chart doesn't maintain anyone's analysis, so there is no `reproduce.R`.

## Sources

| Data | Provider | Fetch | Series |
|---|---|---|---|
| DKW 10-year decomposition, daily | Fed Board staff, updated monthly | `fetch_frb_dkw()` | `nominal.yield.fitted.10`; expected rates = `exp.real.short.rate.10` + `exp.inflation.10`; term premium = `real.term.prem.10` + `inflation.risk.prem.10` |
| ACM 10-year decomposition, daily | New York Fed | `fetch_nyfed_acm()` | `ACMTermPremium.xls`, sheet "ACM Daily": `ACMY10`, `ACMRNY10` (expected rates), `ACMTP10` |

## Transformations

- The DKW model's four parts are combined into the two ACM has, so the panels compare like with like.
- Weekly averages (weeks starting Monday), then the change from the week of February 23, 2026.
- Both models stop at DKW's last day, since DKW is updated monthly and ACM daily.
- Each model's parts sum to its own fitted zero-coupon yield, so the two yield lines differ slightly.

## Vintages

- `data/frb_dkw_nyfed_acm_10_year_<last date>.csv`: both models' daily yield, expected rates, and term premium from the base week, named by the last day used. Both models are re-estimated from time to time, which revises history.

## Known breaks and caveats

- The base week is fixed, and the choice of base week affects the size of every change shown.
- Decompositions are model estimates. They separate expectations from compensation but can't identify why either moved.

## Decision log

- 2026-09-26: Show both models side by side, since term premium estimates depend on the model.
