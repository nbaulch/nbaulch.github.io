# Contributions of software and electricity prices to PCE inflation

Status: built in R from BEA's monthly NIPA files (fetched September 28, 2026, through July 2026). `reproduce.R` checks the FEDS Note's software numbers under its own method.

## Question

How much of PCE inflation comes from two prices tied to AI: computer software and accessories, and electricity?

## Original analysis

- Anthony M. Barbarino, Anthony M. Diercks, and Stephen Miran, "Measurement of 'Computer Software and Accessories' Inflation," FEDS Notes, May 22, 2026. https://www.federalreserve.gov/econres/notes/feds-notes/measurement-of-computer-software-and-accessories-inflation-20260522.html. Figure 1 compares core and core goods PCE inflation with and without software, as four-month annualized rates through March 2026 and as averages since 2000. The text gives core PCE 4.4 percent, software's contribution two-thirds of a point, core goods 5.5 percent, software's contribution to core goods about 2.8 points, and software weights of 1.2 percent of core and 5.1 percent of core goods. The note discusses three possible sources of measurement error in the category.
- Related, not reproduced: Owen Kay, Lutz Kilian, and Reid Taylor, "Data center boom expected to raise electricity component of PCE inflation," Federal Reserve Bank of Dallas, March 5, 2026. https://www.dallasfed.org/research/economics/2026/0305-kay-datacenters. Model-based estimates of data center demand's effect on electricity prices.

## Sources

| Data | Provider | Fetch | Series |
|---|---|---|---|
| Total PCE spending | BEA, NIPA table 2.4.5U, monthly | `fetch_bea_nipa(frequency = "M")` | DPCERC |
| Computer software and accessories, prices and spending | BEA, NIPA tables 2.4.4U and 2.4.5U | same | DCPSRG, DCPSRC |
| Electricity, prices and spending | same | same | DELCRG, DELCRC |
| For `reproduce.R`: headline, core, goods, food off premises, and gasoline and other energy goods | same | same | DPCERG, DPCCRG/C, DGDSRG/C, DFXARG/C, DGOERG/C |
| For `reproduce.R`: CPI electricity, seasonally adjusted | BLS, from FRED | `tidyusmacro::getFRED()` | CUSR0000SEHF01 |

## Transformations

- Contribution = the item's share of total PCE spending 12 months earlier times the 12-month percent change in its price index. This is the item's part of the 12-month change in the PCE price index, to a close approximation of BEA's chained Fisher formula for items this small.
- The chart starts in 2015. The CSV runs from 1978, a year after BEA's software series begins.
- `reproduce.R` follows the FEDS Note: core goods = goods with food off premises and energy goods taken out; software is then taken out of core and core goods, all with the residual Fisher method in `R/price_indexes.R`. Software's contribution = the four-month annualized rate minus the same rate excluding software.

## Vintages

- `data/bea_pce_<last month>.csv`. The download doesn't carry a release date, so it is named by the last month of data.
- The FEDS Note, published May 22, 2026, used data through March 2026 from a release before then. The check uses the latest release, so March 2026 includes later revisions.
- BEA's annual update, due with the next PCE release, brings new source data for software. Rerun and report how much the software line moves.

## Reproduction status, March 2026

| Check | FEDS Note | Ours |
|---|---|---|
| Core PCE, four months annualized | 4.4 | 4.48 |
| Software's contribution to core | 0.67 | 0.65 |
| Core goods PCE, four months annualized | 5.5 | 5.51 |
| Software's contribution to core goods | about 2.8 | 2.75 |
| Software, percent of core PCE | 1.2 | 1.25 |
| Software, percent of core goods PCE | 5.1 | 5.10 |
| Core PCE, average since 2000 | about 2.2, read from Figure 1 | 2.14 |
| Core goods PCE, average since 2000 | about 0.2, read from Figure 1 | 0.06 |

The March figures match to within later revisions. The averages since 2000 are read from a bar chart on a scale of 0 to 6, so a gap of 0.1 to 0.2 point can't be resolved; the note doesn't state the averages or the start month.

Electricity: BEA builds the PCE electricity price from the CPI's. The 12-month changes of the two differ by at most 0.44 point in any month since 2015.

## Known breaks and caveats

- Neither item is a measure of AI. Software covers all software bought by households. Electricity covers what households buy, not what data centers buy, and its price reflects fuel costs, grid investment, and regulation as well as demand.
- The FEDS Note argues part of the software index's recent movement may be measurement error, from a mismatch between the CPI and PCE categories and from quality adjustment.
- BEA's category is named "computer software and accessories" but includes no physical accessories, according to the FEDS Note. The CPI category it is deflated with does.

## Decision log

- 2026-09-28: Contributions to headline PCE over 12 months, instead of the FEDS Note's four-month annualized rates for core PCE. Electricity is not in core, so headline puts both items on one basis, and 12-month changes are the basis of the other inflation charts. `reproduce.R` keeps the FEDS method.
- 2026-09-28: Share times price change, instead of the FEDS Note's difference between inflation with and without the item. Taking an item out measures its price change relative to everything else, which is near zero for an item whose price rises at the average rate, so it doesn't answer how much of inflation comes from the item. Consistency check: the two methods differ by at most 0.08 point for software and 0.10 point for electricity in any month since 2015, about the item's weight times overall inflation, as expected. The chart says the method is adapted.
- 2026-09-28: The items are named for what they are, not labeled AI, since neither is specific to AI.
