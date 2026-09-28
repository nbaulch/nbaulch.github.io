# Measures of underlying PCE inflation

Status: built in R from BEA's monthly NIPA files (fetched September 27, 2026, through July 2026) and the Cleveland, Dallas, and New York Fed measures through July 2026. `reproduce.R` checks the published numbers below.

## Question

How do the main measures of underlying PCE inflation compare, over time and in the latest month?

## Related work

- Federal Reserve Bank of St. Louis, "Between Headline and Core: Inflation Excluding Energy Goods," On the Economy, July 2026. https://www.stlouisfed.org/on-the-economy/2026/jul/between-headline-core-inflation-excluding-energy-goods. Proposes headline PCE excluding gasoline and other energy goods (about 2.8 percent of spending) and builds it with the residual Fisher method. The post quotes no values, so there is nothing to reproduce beyond the method.
- Omair Sharif, Inflation Insights, on X, September 16, 2026: market-based core PCE excluding housing, 12-month change, with a 1994 to 2025 average of 1.5 percent, a 2002 to 2007 average of 1.5 percent, a 2023 to 2025 low of 1.5, and a latest value of 3.23. No written method.
- Mike Konczal, "Is the Actual Inflation Rate PCE and High or CPI and Low?", August 28, 2026: core PCE 3.34 and market-based core 3.03 percent over the 12 months to July.
- Kevin Warsh, Jackson Hole keynote, August 28, 2026: headline PCE 3.7 percent over 12 months and 4.1 percent over six months, annualized. Prefers trimmed means for underlying inflation.
- Dallas Fed, August 2026, and Brookings, on alternative trims for trimmed mean inflation.

## Sources

| Measure | Provider | Fetch | Series |
|---|---|---|---|
| Headline, core, market-based core | BEA, NIPA table 2.4.4U (prices) and 2.4.5U (spending), monthly flat files | `fetch_bea_nipa(frequency = "M")` | DPCERG, DPCCRG, DPCXRG; spending DPCERC, DPCXRC |
| Excluding energy goods (built) | same | same | Removes DGOERG / DGOERC from DPCERG / DPCERC |
| Market-based core excluding housing (built) | same | same | Removes DHSMRG / DHSMRC (market-based housing services) from DPCXRG / DPCXRC |
| Median | Cleveland Fed | `fetch_clevelandfed_median_pce()` | `median-pce-full-history.csv`: monthly and 12-month change |
| Trimmed mean | Dallas Fed, from FRED | `tidyusmacro::getFRED()` | PCETRIM12M159SFRBDAL (12 months), PCETRIM6M680SFRBDAL (6 months, annualized) |
| Trend | New York Fed, Multivariate Core Trend | `fetch_nyfed_mct()` | `mct-chart-data.xlsx` (a CSV despite the name): central estimate and band |

FRED's DPCMRG3M086SBEA is total market-based PCE, not market-based core; market-based core is DPCXRG.

## Transformations

- A component is removed from an aggregate by solving BEA's monthly Fisher formula for the remainder's price change, given both price indexes and both nominal spending series (the residual Fisher method the St. Louis Fed uses). Rebuilding BEA's published market-based core from market-based PCE and its food and energy component matches to within 0.02 point on the 12-month change over the whole history.
- 12-month change = index over its value 12 months earlier. Six-month change, annualized = (index over its value six months earlier) squared, minus one.
- The median's six-month rate compounds its six latest monthly changes. The trimmed mean's six-month rate is the Dallas Fed's own. The New York Fed trend is already a trend estimate and has no six-month version.
- The top panel's gray range spans the six measures other than headline and core, in months when at least five are available.

## Vintages

- `data/<source>_<last month>.csv`: the BEA series used, the Cleveland median, the Dallas trimmed mean, and the New York Fed trend. None of the downloads carries a release date, so each is named by the last month it covers.
- BEA's annual update, due with the next PCE release, swaps in new source data for software, portfolio management, and legal services. Rerun and report how much each measure moves.

## Reproduction status, July 2026

| Check | Published | Ours |
|---|---|---|
| Core PCE, 12 months (Konczal) | 3.34 | 3.34 |
| Market-based core, 12 months (Konczal) | 3.03 | 3.03 |
| Headline PCE, 12 months (Warsh) | 3.7 | 3.70 |
| Headline PCE, 6 months annualized (Warsh) | 4.1 | 4.13 |
| Market-based core excluding housing, 1994 to 2025 average (Sharif) | 1.5 | 1.53 |
| Same, 2002 to 2007 average (Sharif) | 1.5 | 1.48 |
| Same, 2023 to 2025 low (Sharif) | 1.5 | 1.53 |
| Same, latest (Sharif) | 3.23 | 2.99 |

Sharif's latest value isn't matched. His tweet also mentions leaving out portfolio management, but removing it gives 2.50. The history matches, so the measure is shown as following Sharif, not reproducing him.

## Known breaks and caveats

- The Cleveland median and Dallas trimmed mean are computed by those banks from their own component detail; their revisions follow their schedules.
- The New York Fed trend is a model estimate and is revised as new data arrive.
- BEA is revising portfolio management and software prices, which enter the core and market-based measures.

## Decision log

- 2026-09-27: One figure in two panels: headline and core since 2019 with the range of the other measures, and every measure's latest 12-month and six-month rates. Side by side on desktops, stacked on phones, where side by side was too cramped.
- 2026-09-27: Market-based core excluding housing follows Sharif; the history matches his chart but the latest value doesn't (2.99 against 3.23).
