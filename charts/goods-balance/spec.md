# Goods trade balance by product

Status: built in R from the Census trade store (Census release through July 2026). `reproduce.R` checks the store against Census's published end-use series.

## Question

How much of the U.S. goods balance comes from a few product groups whose trade moves for reasons of its own: computers, semiconductors and telecommunications equipment, pharmaceuticals, and gold?

## Related work

- No published analysis is reproduced. `CLAUDE.md` planned this chart to follow Brad Setser, but his published work in 2026 (Council on Foreign Relations, Follow the Money) does not include a breakdown of the U.S. goods balance by product with figures to check against. The categories are Census's own, so the check is against Census's published totals.
- Census Bureau and BEA, U.S. International Trade in Goods and Services (FT-900), monthly. Reports trade by end-use category, including the categories used here.

## Sources

| Data | Provider | Fetch | Fields |
|---|---|---|---|
| Imports and exports by 10-digit product, monthly | Census Bureau, IMDB and EXDB bulk files, via the trade store | `read_census_trade()` | `gen_val` (general imports), `all_val` (total exports) |
| Product codes with end-use categories, one list a year | Same files | `{flow}-codes-{year}.csv` in the store's release | `commodity`, `description`, `end_use` |

## Transformations

- Each product is classified with the code list for its year, since codes change each January.
- Categories, by Census end-use code:
  - Computers and parts: 21300 (computers) and 21301 (computer accessories, peripherals, and parts).
  - Semiconductors and telecom equipment: 21320 (semiconductors) and 21400 (telecommunications equipment).
  - Pharmaceuticals: 40100 (pharmaceutical preparations). It covers chapter 30 (medicaments, vaccines, and blood products) except dressings, sutures, first-aid kits, and ostomy appliances, which Census files under medical supplies (40140), and ricin; and all of heading 2937 (hormones in bulk, including 2937.19, polypeptide hormones, where GLP-1 ingredients such as semaglutide are classified), plus some lines of 2933, 2934, and 2936 (heterocyclic compounds and vitamins).
  - Gold: products in heading 7108 (nonmonetary gold) or heading 7115 whose description names gold, whatever their end-use code.
  - All other goods: everything else.
- Balance = exports less general imports, in billions of dollars a month, not seasonally adjusted: the Census basis of the monthly release. The chart starts in 2019; the CSV starts in 2017.

## Vintages

- The trade store holds the latest Census release of each month and re-pulls months Census revises. `data/census_trade_by_category_<last month>.csv` keeps monthly exports and imports by category from the build.

## Reproduction status, July 2026

For June 2019, March 2025, and July 2026, exports and imports of computers and parts, semiconductors and telecom equipment, pharmaceuticals, and all goods match Census's published end-use series to within rounding.

## Known breaks and caveats

- The balance is on the Census basis. BEA's balance of payments basis, the one in GDP, adjusts for coverage and timing, including some gold that is traded without changing ownership; its totals differ.
- Census files gold bars (7115.90.05.30, "articles of precious metal, in rectangular shapes, of gold") under end use 15200, finished metal shapes, not 14270, nonmonetary gold. In 2025 these bars were $72 billion of imports, against $30 billion under 7108.
- On the export side, 2025's code 7115.90.00.00 covers articles of all precious metals and does not name gold, so its exports stay in all other goods. From 2026, gold has its own code, 7115.90.00.10.
- Not seasonally adjusted, so months are not directly comparable across the year.

## Decision log

- 2026-09-28: Census end-use categories rather than chapters or a hand-built product list, so the categories match Census's own publication and can be checked against it.
- 2026-09-28: Gold from product codes and descriptions rather than end use 14270, because end use leaves gold bars under 7115 in finished metal shapes.
- 2026-09-28: Monthly, not seasonally adjusted, rather than quarterly. Census does not publish seasonally adjusted figures by product.
