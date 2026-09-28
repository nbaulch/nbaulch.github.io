# Contribution of investment in software, computers, data centers, and power to GDP growth

Status: built in R from BEA data fetched on 2026-09-26, through 2026 Q2. Reproduces the published figure exactly under the FEDS method.

## Question

How much do investment in software, computers, data centers, and power, and net trade in computers, contribute to real GDP growth?

## Original analysis

Paul E. Soto, Mason Thieu, and Jeffrey S. Allen, "The AI Buildout and the Economy: Publicly Available Data to Assess AI's Impact," FEDS Notes, Federal Reserve Board, July 17, 2026.
https://www.federalreserve.gov/econres/notes/feds-notes/the-ai-buildout-and-the-economy-publicly-available-data-to-assess-ais-impact-20260717.html

Figure 7, "Contributions to GDP Growth from Software, Data Centers, and IT Equipment," 2022 Q1 to 2026 Q1. Figure data are published with the note and saved in `data/feds_ai_buildout_figure_data.xlsx`.

Related work, with different methods and results:

- Hannah Rubinton and Bontu Ankit Patro, "Tracking AI's Contribution to GDP Growth," On the Economy, St. Louis Fed, January 12, 2026. Includes software, research and development, information processing equipment, and data centers, with no import adjustment. 
- ING THINK, "How much is AI contributing to US economic growth?", August 2026. Subtracts net imports of semiconductors as well as computers.

The size of the import offset depends mostly on how much of computer imports is assumed to go into investment. This chart follows the FEDS Note.

## Sources

All from BEA's NIPA flat files (`https://apps.bea.gov/national/Release/TXT/`), read with `tidyusmacro::getNIPAFiles()` through `fetch_bea_nipa()`.

| Series | Nominal | Real (chained dollars) | Table |
|--------|---------|------------------------|-------|
| GDP | A191RC | A191RX | 1.1.5, 1.1.6 |
| Software | B985RC | B985RX | 5.3.5, 5.3.6 |
| Computers and peripheral equipment | B935RC | B935RX | 5.5.5, 5.5.6 |
| Data centers | LA001282 | LB001282 | 5.4.5 line 5, 5.4.6 |
| Power (structures) | W028RC | W028RX | 5.4.5 line 18, 5.4.6 |
| Exports of computers, peripherals, and parts | B850RC | B850RX | 4.2.5B, 4.2.6B |
| Imports of computers, peripherals, and parts | B852RC | B852RX | 4.2.5B, 4.2.6B |
| Exports of capital goods, except automotive | A640RC | | 4.2.5B line 22 |
| Exports of consumer goods, except food and automotive | A642RC | | 4.2.5B line 42 |
| Imports of capital goods, except automotive | A650RC | | 4.2.5B line 114 |
| Imports of consumer goods, except food and automotive | A652RC | | 4.2.5B line 134 |
| Consumer spending on personal computers, tablets, and peripherals | DCPPRC | | 2.4.5U line 49 |
| Final sales of computers | BB01RC | | 1.2.5 line 17 |
| Exports of semiconductors and related devices | LA001105 | LB001105 | 4.2.5B line 33, 4.2.6B |
| Imports of semiconductors and related devices | LA001145 | LB001145 | 4.2.5B line 125, 4.2.6B |

Consumer spending on computers and final sales of computers build the trade weight based on domestic spending on computers, used in the chart notes and in `trade_weights.R`. Semiconductor trade is used only in `semiconductors.R`.

## Transformations

For each component, the contribution to annualized real GDP growth is

`s_{t-1} * 400 * (R_t / R_{t-1} - 1) + (N_t / GDP_t) * [100 * ((Y_t / Y_{t-1})^4 - 1) - 400 * (Y_t / Y_{t-1} - 1)]`

where `s` is the component's nominal share of GDP, `R` its real value, `N` its nominal value, and `Y` real GDP. The second term converts a simple annualized rate to a compound one and is under 0.01 point here.

For computer trade, the lagged share is multiplied by the capital goods share of trade, `CG / (CG + CS)`, computed separately for exports and imports and lagged one quarter along with the share it scales. The FEDS Note text writes the weight as `w_t`. Only the lagged weight reproduces the published figure.

Net contribution = software + computers + data centers + power + net exports of computers.

The chart plots four-quarter averages of these quarterly contributions and combines data centers and power into one bar. The CSV has the averages, with data centers and power separate.

## Vintages

BEA's flat files carry no release date, so each fetch is saved as `data/bea_nipa_<fetch date>.csv`. The 2026-09-26 fetch runs through 2026 Q2 and matches the FEDS Note's figure data for every quarter from 2022 Q1 to 2026 Q1, so those quarters have not been revised since the note's data were pulled. BEA's annual update, usually published around late September, may revise them.

## Reproduction status

`reproduce.R` compares our five components with the published Figure 7 data. All 17 quarters match to two decimals for every component.

## Census crosswalk

Tests the capital goods weight on computer trade. `trade_weights.R` fetches the Census detail, saves the snapshot, and prints the comparison below. It does not change the chart.

- BEA's exports and imports of "computers, peripherals, and parts" (B850RC, B852RC) match Census end-use categories 21300 (computers) plus 21301 (computer accessories) within 1 to 3 percent in every quarter from 2022 Q1 to 2026 Q2. Compare Census's seasonally adjusted end-use series, summed to quarters and multiplied by four, with BEA's annual rates.
- Census publishes those seasonally adjusted end-use series monthly back to 1994, with no API key: `https://www.census.gov/foreign-trade/statistics/historical/imports_enduse.xlsx` and `exports_enduse.xlsx`.
- HS detail comes from the Census international trade API (`timeseries/intltrade/imports/hs` and `exports/hs`) through `fetch_census_trade()`: general imports (`GEN_VAL_MO`) and total exports (`ALL_VAL_MO`), monthly, by country, not seasonally adjusted. The API needs a free key, read from the `CENSUS_API_KEY` environment variable and never committed.
- Codes: all of HS 8471 at six digits (847130 laptops, 847141 and 847149 desktops and systems, 847150 processing units, which are mostly servers, 847160 input and output units, 847170 storage, 847180 other units, 847190 other) plus 847330, parts of 8471 machines. Together they are 86% of end-use 21300 plus 21301 imports in 2022 and 96% in 2026.
- Not covered, because they are outside BEA's computer line: GPUs and other chips shipped on their own (HS 8542), network switches and routers (8517.62), and power and cooling equipment for data centers.
- Snapshot: `data/census_trade_<fetch date>.csv`, monthly by HS code and partner, with partners grouped as Mexico, Taiwan, and all others. The full country detail is about 5 MB a pull, too large to commit on every refresh.

### Method notes

The weight on computer trade drives the size of the import offset. `trade_weights.R` compares the FEDS Note's capital goods weight with a weight from BEA's business share of domestic spending on computers and with a product-mix weight from Census HS detail. The BEA weight treats government spending on computers as the residual in final sales of computers, since it isn't published. A domestic content check, that counted net computer imports don't exceed business investment in computers, rules out the product-mix weight and no weight. The chart keeps the FEDS weight; the BEA weight is a refresh check.

Netting exports against imports handles round trips, such as parts and servers shipped through Mexico, as long as both sides get the same weight.

## Import price check

`import_prices.R` compares BEA's implied price of computer trade with BLS price indexes, read from FRED and saved as `data/fred_bls_prices_<fetch date>.csv`: import prices for computers, peripherals, and parts (IR213COM), for parts alone (IR21301), and for semiconductors (IR21320), and producer prices for electronic computers (PCU334111334111) and storage devices (PCU334112334112). BLS published no import prices for October 2025, during the government shutdown, so 2025 Q4 averages November and December.

The script compares price growth for BEA's computer imports, computer exports, and business investment in computers with the BLS indexes. Deflating computer trade with the investment price instead of the import price is a refresh check; the chart keeps BEA's import price, following the FEDS Note.

## Semiconductors

`semiconductors.R` saves Census HS detail as `data/census_semiconductor_trade_<fetch date>.csv` (HS 8541, 8542, and 8523.51 by month, not seasonally adjusted) and adds BEA's net semiconductor trade to the chart's net total, both with the FEDS weights and with no weight.

- BEA's semiconductor line matches Census end-use 21320, which includes solid-state storage drives (HS 8523.51) as well as chips. HS 8541, 8542, and 8523.51 together are 87 to 93 percent of end-use 21320 imports; the concordance itself has not been checked.
- BEA does not count separately bought chips or solid-state drives as equipment investment. Census's import concordance (`https://www.census.gov/foreign-trade/reference/codes/concordance/impconcord22.xlsx`) assigns solid-state drives (HS 8523510000) to end-use 21320 and NAICS 334613, blank recording media, and chips to NAICS 334413. BEA's bridge from products to equipment investment (`https://apps.bea.gov/industry/release/xlsx/PEQBridge_Detail.xlsx`, benchmark years 2007, 2012, and 2017) builds computers and peripheral equipment from 334111 computers, 334112 storage devices, 334118 peripherals, 541512 computer systems design, and used equipment. Neither 334413 nor 334613 appears in any equipment category. Imported chips and drives are therefore intermediate inputs: they are import content of computer investment only when a domestic producer builds them into computers that businesses buy, and otherwise they offset other final spending. The 2017 bridge is the latest; how BEA's current commodity flow treats solid-state drives bought separately for data centers is not documented there.
- Because imported chips and drives are intermediate inputs, only the part used by domestic computer makers would belong in the offset, and the data here can't separate it. The chart follows the FEDS Note and leaves semiconductors out.

## Open items

- **Colors.** Orange means data centers and power here and utilization on the productivity chart, on the same page.

## Known breaks and caveats

- There is no AI line in the national accounts. Software, computers, and power facilities include non-AI spending. Power covers all electric and other power structures.
- The capital goods weight assumes computer imports go to investment in the same proportion as goods trade overall goes to capital goods. That is the key assumption behind the size of the offset.
- Semiconductors and communication equipment are excluded, following the FEDS Note.

## Decision log

- 2026-09-26: Follow the FEDS Note method because it publishes figure data that can be reproduced exactly. Credit it as the source of the method.
- 2026-09-26: Pulled Census HS detail for computer trade and compared weights on computer trade. The product-mix weight is ruled out by the domestic content check. The chart keeps the FEDS weight, for exact replication; the BEA weight is a refresh check.
- 2026-09-26: Checked BEA's 2026 Q2 computer import prices against BLS import and producer prices; they are consistent with the source data. Deflating with the investment price is a refresh check.
- 2026-09-26: Checked how BEA treats chips and solid-state drives. They are not in equipment investment, so netting all semiconductor trade would overstate the offset. Semiconductors stay out, following the FEDS Note.
- 2026-09-26: Name the four components rather than calling the total "AI investment", since they also carry spending unrelated to AI.
- 2026-09-26: Plot four-quarter averages instead of quarterly contributions, since quarterly bars swing widely. `reproduce.R` still checks the quarterly figures.
