# Contributions to U.S. labor productivity growth

Status: built in R from the September 3, 2026 release of the Fernald data. The published version has four components, splitting computer and software capital out of Tedeschi's deepening bar. `reproduce.R` checks the three-component numbers against his chart.

## Question

How much of U.S. labor productivity growth comes from technology and efficiency (utilization-adjusted TFP), from firms running existing capital and labor harder (utilization), and from capital deepening, including computers and software?

## Original analysis

Ernie Tedeschi, "AI and Productivity," Stripe Economics, July 23, 2026.
https://www.stripeeconomics.com/p/ai-and-productivity

Published chart: "Contributions to US labor productivity growth," subtitle "Percentage points, four-quarter annualized average," 2022 Q1 to 2026 Q1. Stacked bars with three components: labor and capital deepening, utilization-adjusted TFP, and utilization. Chart note: "Contributions sum to four-quarter US business sector productivity growth." Sources: BLS, Federal Reserve Bank of San Francisco, Stripe analysis.

Related work to credit:
- John Fernald, the quarterly utilization-adjusted TFP series, maintained by the San Francisco Fed.
- Boyle, Fernald, and Li (2026), "Higher utilisation explains recent surge in productivity growth," VoxEU. https://cepr.org/voxeu/columns/higher-utilisation-explains-recent-surge-productivity-growth

Approximate readings from the published chart, in percentage points:

| Quarter | Deepening | Utilization-adjusted TFP | Utilization |
|---------|-----------|--------------------------|-------------|
| 2022 Q1 | -1.4 | 0.9 | -0.1 |
| 2023 Q4 | 1.55 | 2.65 | -0.95 |
| 2025 Q4 | 1.25 | 0.3 | 1.05 |
| 2026 Q1 | 1.0 | 0.1 | 1.4 |

## Source

| Data | Provider | Fetch | Identifier |
|------|----------|-------|------------|
| Quarterly TFP and its components, U.S. business sector | San Francisco Fed (Fernald) | `fetch_sffed_tfp()`, `read_sffed_tfp()` | `quarterly_tfp.xlsx`, sheet "quarterly" |
| Capital input by asset, with income-share weights | San Francisco Fed (Fernald) | `read_sffed_capital()` | same file, sheet "Capital-input-details" |

Data URL: https://www.frbsf.org/wp-content/uploads/quarterly_tfp.xlsx

Columns used: `dLP`, `dk`, `dhours`, `dLQ`, `alpha`, `dtfp`, `dutil`, `dtfp_util`. All are quarterly log changes at an annual rate (400 times the log difference).

`dLP` is output growth minus hours growth, where output averages the expenditure and income sides. The BLS productivity release uses the expenditure side only, so `dLP` will not match the BLS headline exactly.

## Transformations

1. Components, each quarter. These identities hold exactly in the data:
   - Capital deepening: `alpha * (dk - dhours)`
   - Labor composition: `(1 - alpha) * dLQ`
   - Utilization: `dutil`
   - Utilization-adjusted TFP: `dtfp_util`
   - The four sum to `dLP`.
2. Tedeschi combines capital deepening and labor composition into one "labor and capital deepening" bar.
3. Four-component version: capital deepening split by asset. Capital input growth `dk` equals the weighted sum of asset growth rates exactly, using the `wgt_*` columns. Computer and software capital deepening is `alpha * (wgt_info_processing_equip * dk_info_processing_equip + wgt_software * dk_software - (wgt_info_processing_equip + wgt_software) * dhours)`. The remainder of capital deepening, plus labor composition, is the "other" bar. This covers all information processing equipment and software, not only AI.
4. Four-quarter trailing mean of each component. This matches "four-quarter annualized average" and keeps the sum equal to the four-quarter mean of `dLP`.

## Vintages

Fernald does not publish past vintages. Each fetch should save a dated snapshot, because revisions are large relative to the components.

- The September 3, 2026 release changed the labor composition series. The `labor composition` sheet has both versions: `dLC_current` and `dLC_through_2026.08`. Tedeschi's July chart used the earlier one.
- The change shifts capital-plus-labor deepening by up to 0.9 percentage points in some quarters. Example: 2023 Q1 is 0.60 under the current series and 1.48 under the earlier one. TFP absorbs the difference.

## Reproduction status

`reproduce.R` compares our four-quarter components with the readings above, using the earlier labor composition series.

- 2022 Q1 matches to within 0.16 point and 2023 Q4 to within 0.06.
- 2025 Q4 matches to within 0.1.
- 2026 Q1 differs by 0.21 on TFP (0.31 against about 0.1) and by 0.10 on utilization. The most likely cause is routine revision between Tedeschi's July vintage and the September release.

The July vintage is not public. An exact match would require asking Fernald's team for it.

## Known breaks and caveats

- Utilization is not observed. It is inferred from hours per worker, following Basu, Fernald, Fisher, and Kimball, so the split between utilization and TFP depends on that method.
- The computer and software bar is a proxy for AI investment. It includes all information processing equipment and software, and it leaves out data center buildings, which are in structures. It is a capital services measure, so a surge in investment shows up gradually as the stock grows.

## Decision log

Record decisions here with a date and the reason.

- 2026-09-26: Chose this chart over the industry AI adoption scatter. The question is macro: how much productivity growth comes from TFP and how much from utilization. The scatter answers a narrower cross-sectional question.
- 2026-09-26: Fernald release of 2026-09-03 inspected. Data run through 2026 Q2. Component identities verified.
- 2026-09-26: Credit. The data and the growth accounting are Fernald's, so the source line names his series and the San Francisco Fed. The chart's framing is Tedeschi's, so the note says "Chart adapted from" his post.
- 2026-09-26: No acronyms or formulas on the chart. Notes define each component in plain words. See `STYLE.md`.
- 2026-09-26: Added the four-component version, splitting computer and software capital out of capital deepening.
- 2026-09-26: Components are four-quarter trailing means of the quarterly annualized log changes. A black point shows labor productivity growth itself, since stacked bars with negative segments make the total hard to read.
- 2026-09-26: Publish the four-component version only. Short legend labels, each defined in one line of the notes.
