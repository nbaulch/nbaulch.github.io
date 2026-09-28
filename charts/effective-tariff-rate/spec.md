# Effective tariff rate

Status: built in R from the Census trade store (Census release through July 2026). `reproduce.R` checks the collected rate against the Federal Reserve Board and Penn Wharton.

## Question

What rate are U.S. imports paying in tariffs, and how much of that rate reflects the current mix of products and source countries rather than the rates themselves?

## Related work

- Sydney Eck, Trang Hoang, Carter Mix, and Madeleine Ray, "Mind the Gap: Announced versus Implied Tariff Rates in Recent Trade Policy Episodes," FEDS Notes, April 8, 2026. https://www.federalreserve.gov/econres/notes/feds-notes/mind-the-gap-announced-versus-implied-tariff-rates-in-recent-trade-policy-episodes-20260408.html. Calls the collected rate the realized effective tariff rate: calculated duties over the customs value of general imports, by country and 10-digit product. Compares it with an announced rate at 2017 or 2024 import weights and splits the gap into composition and rate discrepancy. Reports, for December 2025, an announced rate of 14.7 percent, 12.37 points above 2024, and a gap of 5.43 points; for December 2018, an announced rate up 1.93 points from 2017 and a collected rate up 1.49. No data file.
- Penn Wharton Budget Model, "Effective Tariff Rates and Revenues," updated September 9, 2026. https://budgetmodel.wharton.upenn.edu/p/2026-09-09-effective-tariff-rates-and-revenues-updated-september-9-2026/. Customs duties as a percent of imports, from USITC DataWeb: 2.3 percent in January 2025, 6.7 percent in July 2026, and 22.8 percent on imports from China in July 2026.
- Yale Budget Lab, Tariff Rate Tracker. https://github.com/Budget-Lab-Yale/tariff-rate-tracker. Computes collected rates as `cal_dut_mo / con_val_mo` by 10-digit product, country, and month.

## Sources

| Data | Provider | Fetch | Fields |
|---|---|---|---|
| Imports by 10-digit product, country, and rate provision, monthly | Census Bureau, IMDB bulk files, via the trade store | `read_census_trade("imports", ...)` | `con_val` (customs value, imports for consumption), `gen_val` (customs value, general imports, for the checks), `cal_dut` (calculated duty) |

## Transformations

- Collected rate = calculated duty over the customs value of imports for consumption, summed over all products and countries, including chapters 98 and 99.
- Rate at the 2024 mix = the average of each product and country's collected rate that month, weighted by its imports for consumption in 2024. Products are 6-digit codes. A product and country with no imports that month drops out, and the remaining weights are rescaled; `base_mix_coverage` in the CSV records the share of 2024 value still covered, 98 percent through July 2026.

## Vintages

- The trade store holds the latest Census release of each month and re-pulls months Census revises, as it does each June. `data/census_imports_by_country_<last month>.csv` keeps monthly totals by country from the build.

## Reproduction status, July 2026

| Check | Published | Ours, imports for consumption | Ours, general imports |
|---|---|---|---|
| Fed Board: collected rate, December 2025 (14.7 announced less 5.43 gap) | 9.27 | 9.34 | 9.20 |
| Fed Board: rise in collected rate, 2024 average to December 2025 | 6.94 | 6.98 | 6.85 |
| Fed Board: rise in collected rate, 2017 average to December 2018 | 1.49 | 1.20 | 1.22 |
| Penn Wharton: January 2025, without chapters 98 and 99 | 2.3 | 2.30 | 2.32 |
| Penn Wharton: July 2026, same | 6.7 | 6.73 | 6.58 |
| Penn Wharton: China, July 2026, same | 22.8 | 23.1 | 21.4 |

- The Fed Board's 2025 figures match within 0.1 point on either denominator. Its collected rate is not published directly; the check subtracts its reported gap from its announced rate.
- The Fed Board's 2018 rise does not match: 1.20 against 1.49. Measuring from December 2017 or January 2018 instead of the 2017 average gives 1.31 and 1.19, and dropping chapters 98 and 99 gives 1.26. The note publishes no data, so the difference is unresolved. The chart does not depend on that episode's figure.
- Penn Wharton's figures match imports for consumption without chapters 98 and 99, which hold special classifications such as U.S. goods returned. With those chapters, our figures are 2.22, 6.45, and 21.4.

## Known breaks and caveats

- Calculated duty is the duty assessed when goods enter. It does not reflect later refunds, such as those after the Supreme Court's February 20, 2026 ruling on tariffs imposed under the International Emergency Economic Powers Act. Goods withdrawn from bonded warehouses are counted, with their duty, in the month they are withdrawn.
- Tariff codes change each January at 10 digits, and at 6 digits with each Harmonized System revision, next in January 2027. A product whose code changes after 2024 drops out of the 2024 mix; at 10 digits, coverage fell to 89 percent by July 2026.

## Decision log

- 2026-09-27: Imports for consumption as the denominator, as in the Yale Budget Lab tracker. The Federal Reserve Board note uses general imports, but at the level of one product and country in a month, general imports can be near zero while duty on goods withdrawn from bonded warehouses is large: with general imports, the rate at the 2024 mix reached 20 percent in January 2026, against 12.4 with imports for consumption. The two denominators match the Fed Board's 2025 figures equally well. `reproduce.R` shows both.
- 2026-09-27: All chapters, including 98 and 99, as in the Fed Board note. Penn Wharton's published figures match without them.
- 2026-09-27: 6-digit products for the 2024 mix rather than 10-digit, so the mix keeps 98 percent of 2024 value instead of 89 percent. The rate at 6 digits is 0.1 to 0.3 point below the rate at 10 digits since mid-2025, since it misses shifts between 10-digit products within a 6-digit code.
