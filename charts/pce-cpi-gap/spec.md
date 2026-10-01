# Gap between core PCE and core CPI inflation

Status: built in R from BEA's monthly NIPA files and BLS's CPI flat files and relative importance tables (fetched October 1, 2026, through August 2026). `reproduce.R` checks Konczal's numbers and the CPI weights.

## Question

How far is the gap between core PCE and core CPI inflation from its pre-pandemic average, and which items account for the difference?

## Original analysis

Mike Konczal, "Is the Actual Inflation Rate PCE and High or CPI and Low?", August 28, 2026. https://newsletter.mikekonczal.com/p/is-the-actual-inflation-rate-pce. Charts the 12-month core CPI and core PCE rates and their difference back to 1960. Quotes core PCE 3.34 and core CPI 2.47 percent over the 12 months to July 2026, a 0.87 point difference; an average of 0.34 point with CPI higher from 2011 to 2019; portfolio management accounting for about 0.31 point; and software weights of 1.10 percent in PCE against 0.03 percent in CPI. Cites BEA table 9.1U for the full reconciliation.

## Sources

| Data | Provider | Fetch | Series |
|---|---|---|---|
| Core PCE prices and spending | BEA, NIPA tables 2.4.4U and 2.4.5U, monthly | `fetch_bea_nipa(frequency = "M")` | DPCCRG, DPCCRC |
| Information processing equipment | same | same | DIPERG, DIPERC |
| Computer software and accessories | same | same | DCPSRG, DCPSRC |
| Net motor vehicle and other transportation insurance | same | same | DTINRG, DTINRC |
| Health care services | same | same | DHLCRG, DHLCRC |
| Core CPI and items, CPI-U, seasonally adjusted | BLS flat files | `fetch_bls_cpi()` | CUSR0000SA0L1E; computers, peripherals, and smart home assistants CUSR0000SEEE01; motor vehicle insurance CUSR0000SETE; medical care services CUSR0000SAM2 |
| CPI weights, each December | BLS relative importance tables | `fetch_bls_cpi_relative_importance()` | CPI-U column, percent of all items: text archives for 2009 to 2019, one spreadsheet a year from 2020 |

BLS asks scripted downloads to send a contact email as the user agent; `R/fetch_bls.R` sends Nicholas's.

## Transformations

- PCE contribution of an item in a month = its share of core PCE spending the month before × its price change. The shares come from nominal spending, which approximates BEA's Fisher aggregation.
- CPI contribution = the item's December relative importance over core's, updated by the item's price change relative to core since December, × its price change. This is how BLS aggregates. Weights for each year come from the previous December's table.
- Software: BLS publishes the CPI software index only without seasonal adjustment, and BEA deflates PCE software with that index, so the CPI side uses the PCE software price with the CPI software weight, about 0.03 percent of core.
- Each item's part of the gap = its PCE contribution minus its CPI contribution, summed over 12 months. Computers and software are combined. Other = the gap minus the named parts, so it includes housing and everything else.
- Gap = 12-month change in core PCE minus 12-month change in core CPI, from the indexes.
- Change from the 2011–19 average: each series minus its average over the 12-month periods ending January 2011 to December 2019. The chart shows these changes from January 2015; the CSV runs from December 2010.
- Missing CPI months: the October 2025 shutdown left no October 2025 index for any CPI series and no November index for some. Missing months are filled log-linearly, which spreads the change across the gap evenly. The 12-month gap for October 2025 rests on the filled index.

## Vintages

- `data/bea_pce_<last month>.csv`, `data/bls_cpi_<last month>.csv`, and `data/bls_relative_importance_<last December>.csv`. None of the downloads carries a release date, so the first two are named by the last month of PCE data. The older `fred_core_cpi_*.csv` snapshots are from the first version of the chart and are kept for `reproduce.R`.
- BEA's annual update in September 2026 revised PCE from 2021. Konczal's July figures are checked against the July 2026 snapshots, from before the update.
- BLS revises seasonal factors each February for the past five years and publishes new relative importance each January.

## Reproduction status, October 2026

| Check | Published | Ours |
|---|---|---|
| Core PCE, 12 months to July 2026, July vintage | 3.34 | 3.34 |
| Core CPI, 12 months to July 2026 | 2.47 | 2.47 |
| Gap, July vintage | 0.87 | 0.88 |
| Average gap, 2011 to 2019, CPI minus PCE, current vintage | 0.34 | 0.34 |
| Core CPI rebuilt from goods and services less energy with BLS weights, average monthly error | 0 | 0.006 point |
| Same, largest monthly error | 0 | 0.027 point |

Konczal's gap differs in the second decimal because he subtracts rounded rates. The rebuild of core CPI isn't exact because BLS seasonally adjusts some aggregates directly.

## Known breaks and caveats

- The items pair BEA and BLS categories that don't match exactly. PCE health care services include care paid for by employers and government; CPI medical care services cover only what households pay. PCE motor vehicle insurance is net of claims; CPI's is the premium.
- Seasonally adjusted CPI items don't aggregate exactly to seasonally adjusted core, so a little of Other is aggregation error.
- Spending shares approximate BEA's Fisher aggregation; the small difference also lands in Other.
- BEA's table 9.1U reconciles headline PCE and CPI by formula, weight, and scope effects, but not core.

## Decision log

- 2026-09-27: Two lines, the gap and the gap excluding portfolio management and software. Starts in 2011 to include Konczal's 2011 to 2019 comparison period.
- 2026-10-01: Replaced by item contributions to the gap, as changes from the 2011–19 average. After BEA's annual update, portfolio management explained little of the gap's rise. A ranking of items by their change from the 2011–19 average put car insurance, computers, medical services, and software at the top; housing and prescription drugs moved the other way. Computers and software are combined, matching the productivity chart's label. Built from BLS's published weights rather than estimated ones. The method is adapted from Konczal, and the chart says so.
- 2026-10-01: Stacked bars of the parts with a line for the gap, from 2015. Bars are 75 percent of a month wide, and Other, in gray, stacks outside the colored parts.
