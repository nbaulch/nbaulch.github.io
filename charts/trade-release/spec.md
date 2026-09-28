# Trade release

Status: built in R from the FT-900 for July 2026 (released September 3, 2026), the Census international trade API, and the Census trade store. A release-day page, `trade-release.qmd`, separate from the trade topic page. It follows no one's published analysis, so there is no `reproduce.R`.

## Question

What changed in the latest monthly trade report, seasonally adjusted and not? Seasonal adjustment of trade data has been harder since 2020, so the page shows both views where the data allow: seasonally adjusted figures against the previous month, and figures not seasonally adjusted against the same month a year earlier.

## Sources

| Data | Provider | Fetch | Fields |
|---|---|---|---|
| FT-900 exhibit 1: goods and services, balance of payments basis, seasonally adjusted | Census Bureau and BEA | `fetch_census_ft900_exhibit(1, ...)` | Balance, exports, imports: total, goods, services; the previous month as published a month earlier |
| FT-900 exhibit 6: goods by end-use category, Census basis, seasonally adjusted | Same | `fetch_census_ft900_exhibit(6, ...)` | Total, six principal categories, exports and imports |
| FT-900 exhibit 10: goods in chained 2017 dollars, Census basis, seasonally adjusted | Same | `fetch_census_ft900_exhibit(10, ...)` | Total, six categories, residual, exports and imports |
| FT-900 exhibit 19: goods by country, Census basis, seasonally adjusted | Same | `fetch_census_ft900_countries()` | Balance, exports, imports for the latest two months |
| Goods by end-use category, not seasonally adjusted | Census international trade API, `timeseries/intltrade/{imports,exports}/enduse` | `fetch_census_trade_end_use()` | `GEN_VAL_MO`, `ALL_VAL_MO` at levels EU1 and EU5 |
| Goods by product and country, not seasonally adjusted | Census trade store | `read_census_trade()` | `gen_val`, `all_val`, `con_val`, `cal_dut` |
| Product codes with end-use categories and descriptions | Census trade store | `read_census_trade_codes()` | `commodity`, `description`, `end_use` |
| Release dates | Census release schedule | `fetch_census_trade_schedule()` | First table (FT-900) |

Exhibits are read from `current_press_release/exh{n}.xlsx`, which holds only the latest release.

## Transformations

- **Headline table:** exhibit 1, billions of dollars. Change is the latest month less the previous month as revised. Revision is the previous month as revised less the previous month as published a month earlier.
- **Goods balance chart:** Census basis. Seasonally adjusted is exhibit 6 total exports less total imports. Not seasonally adjusted is the sum of the API's EU1 categories, exports less general imports.
- **Goods balance excluding gold:** the not seasonally adjusted balance less the gold balance from the trade store. Gold is `product_group()` in `R/trade_products.R`: heading 7108 and the heading 7115 lines whose description names gold, as on the goods balance chart. Census does not seasonally adjust gold at this detail, so there is no seasonally adjusted version.
- **Goods in chained dollars:** exhibit 10 totals. Monthly average over the current quarter to date and over the previous quarter. The percent change is annualized, (current / previous)^4 - 1. The balance is exports less imports in chained dollars, as BEA reports it.
- **By category:** exhibit 6 categories, latest less previous month. API EU1 categories, latest month less the same month a year earlier. The API's export code 6 (exports n.e.c. and reexports) is added to other goods (5), as in exhibit 6.
- **By product:** API EU5 categories, the ten largest absolute changes from a year earlier for each flow.
- **Computers, chips, and telecom equipment by country:** general imports from the trade store in the latest month and a year earlier, by `product_group()`: computers and parts (end use 21300, 21301) and semiconductors and telecom equipment (21320, 21400). Each product is classified with the code list for its year. The eight countries with the most imports of the two combined in the latest month; the rest are summed.
- **By country:** exhibit 19 balances for single countries; its areas (European Union, CAFTA-DR, South/Central America, all other countries) are left out. The twelve with the largest absolute balance in the latest month. The change from a year earlier is exports less general imports from the trade store, matched to exhibit 19 by country name.
- **Tariffs:** calculated duties (`cal_dut`) from the trade store by month, last 25 months. The tariff rate is duties over imports for consumption (`con_val`). Countries are the ten with the most duties in the latest month.

## Vintages

- `data/census_ft900_<release date>.csv` saves the exhibits as read; `data/census_end_use_<release date>.csv` saves the API pull. Census does not archive exhibits at a predictable URL, so these files are the record of each release.
- If the trade store does not yet hold the month the FT-900 covers, the build leaves the page as it is, so the page never mixes releases. The store adds a month a day or so after release, and the daily refresh then rebuilds the page.

## Known breaks and caveats

- Seasonally adjusted country data do not sum to the seasonally adjusted totals by commodity (exhibit 19 notes). Census finds no seasonal pattern in trade with Ireland and the Netherlands, so exhibit 19 shows them unadjusted.
- Balance of payments and Census bases differ by BEA's adjustments (exhibit 6, net adjustments), so the headline goods balance differs from the Census-basis goods balance.
- Each June, the annual revision revises seasonally adjusted and unadjusted data for several years.

## Decision log

- September 2026: a standalone release page rather than a release-day block on every chart, so the release view can be organized around the release.
- September 2026: both seasonally adjusted and unadjusted views, compared over a month and a year respectively, since a month-over-month change in unadjusted data mostly reflects seasonal patterns.
- September 2026: tables for the headline, chained dollars, and countries; charts where the comparison across rows matters more than the values.
