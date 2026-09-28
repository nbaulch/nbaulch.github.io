# Gap between core PCE and core CPI inflation

Status: built in R from BEA's monthly NIPA files and BLS core CPI from FRED (fetched September 27, 2026, through July 2026). `reproduce.R` checks Konczal's numbers.

## Question

How far apart are core PCE and core CPI inflation, and how much of the difference comes from portfolio management and software, two items weighted far more heavily in PCE?

## Original analysis

Mike Konczal, "Is the Actual Inflation Rate PCE and High or CPI and Low?", August 28, 2026. https://newsletter.mikekonczal.com/p/is-the-actual-inflation-rate-pce. Charts the 12-month core CPI and core PCE rates and their difference back to 1960, as core CPI minus core PCE. Quotes core PCE 3.34 and core CPI 2.47 percent over the 12 months to July 2026, a 0.87 point difference; an average of 0.34 point with CPI higher from 2011 to 2019; portfolio management accounting for about 0.31 point; and software weights of 1.10 percent in PCE against 0.03 percent in CPI. Cites BEA table 9.1U for the full reconciliation.

## Sources

| Data | Provider | Fetch | Series |
|---|---|---|---|
| Core PCE prices and spending | BEA, NIPA tables 2.4.4U and 2.4.5U, monthly | `fetch_bea_nipa(frequency = "M")` | DPCCRG, DPCCRC |
| Portfolio management and investment advice services | same | same | DPMIRG, DPMIRC |
| Computer software and accessories | same | same | DCPSRG, DCPSRC |
| Core CPI, seasonally adjusted | BLS, from FRED | `tidyusmacro::getFRED()` | CPILFESL |
| Total PCE spending, for the software weight check | BEA | `fetch_bea_nipa(frequency = "M")` in `reproduce.R` | DPCERC |

## Transformations

- Gap = 12-month percent change in core PCE minus 12-month percent change in core CPI. The sign is the reverse of Konczal's, so a positive gap means PCE is higher.
- Portfolio management is removed from core PCE, then software from the remainder, with the residual Fisher method used in `charts/inflation-measures/`. Each item's part of the gap is how much core PCE's 12-month change falls when it is removed. Portfolio management is outside the CPI's scope, and software's CPI weight is about 0.03 percent, so the CPI side is left unchanged.
- Gap excluding portfolio management and software = gap minus both parts.
- Dashed line = average gap, January 2011 to December 2019.
- The chart starts in 2011; the CSV runs from 1960.

## Vintages

- `data/bea_pce_<last month>.csv` and `data/fred_core_cpi_<last month>.csv`. Neither download carries a release date, so each is named by the last month of PCE data.
- BEA's annual update, due with the next PCE release, brings new source data for software, portfolio management, and legal services. Rerun and report how much the gap and both parts move.
- Seasonal factors for CPI are revised each February for the past five years.

## Reproduction status, July 2026

| Check | Konczal | Ours |
|---|---|---|
| Core PCE, 12 months | 3.34 | 3.34 |
| Core CPI, 12 months | 2.47 | 2.47 |
| Gap | 0.87 | 0.88 |
| Average gap, 2011 to 2019 (CPI minus PCE) | 0.34 | 0.34 |
| Portfolio management's part | about 0.31 | 0.32 |
| Software, percent of PCE spending | 1.10 | 1.08 |

The gap differs in the second decimal because Konczal subtracts rounded rates. His method for the portfolio management figure isn't stated.

## Known breaks and caveats

- The split covers two items only. BEA's table 9.1U reconciles headline PCE and CPI monthly into formula, weight, scope, and other effects, but not core inflation over 12 months.
- Removing items in a different order changes each part slightly, since the Fisher formula isn't additive.

## Decision log

- 2026-09-27: Two lines, the gap and the gap excluding portfolio management and software, instead of stacked monthly contributions, which were hard to read. Starts in 2011 to include the 2011 to 2019 comparison period Konczal uses.
