# Businesses paying for AI, by provider

Status: built in R from the Ramp AI Index on FRED, through August 2026, fetched October 6, 2026. Not a reproduction: the chart plots Ramp's published series without transformation.

## Question

What share of businesses pay for AI each month, and which AI companies do they pay?

## Original analysis

Ramp AI Index, Ramp Economics Lab, led by Ara Kharazian. https://ramp.com/data/ai-index

## Sources

| Measure | FRED series |
|---|---|
| Any AI provider | RAMPAIALL |
| OpenAI | RAMPAIOPENAI |
| Anthropic | RAMPAIANTHROPIC |
| xAI | RAMPAIXAI |

Fetched with `tidyusmacro::getFRED()`. FRED release: Ramp AI Index. Monthly, percent, not seasonally adjusted, from January 2023.

## Definitions

From Ramp and the FRED series notes:

- Adoption: "the share of businesses with an observed payment for an AI product or service in a given month." Payments are corporate card, invoice, and ACH transactions processed by Ramp; merchant names and line-item details identify qualifying payments.
- Sample: more than 70,000 U.S. businesses on Ramp's card and bill-pay platform.
- Provider series: the share of businesses with a payment to that company in the month. A business can pay more than one provider, so the provider series don't sum to the total.

## Transformations

None. The CSV keeps the series as published, rounded to three decimals.

## Vintages

- Snapshot: `data/fred_ramp_ai_<latest month>.csv`, named by the last month of data, because the FRED download carries no release date.
- FRED keeps earlier vintages in ALFRED.

## Known breaks and caveats

- Ramp's customers are not a random sample of U.S. businesses, and the sample changes as Ramp gains and loses customers. Ramp does not say whether it reweights.
- Free tools and AI paid for on personal accounts don't appear. Ramp says its results likely understate adoption for this reason.
- Not comparable with the Census Business Trends and Outlook Survey in `charts/ai-adoption/`: that survey asks about use, not payment, and weights businesses to represent all U.S. employer firms.

## Decision log

- 2026-10-06: Plotted by provider rather than by company size. FRED also carries Ramp series for small businesses, mid-market, and enterprise (RAMPAISMB, RAMPAIMIDMARKET, RAMPAIENTERPRISE), but Ramp publishes no employee cutoffs for them, and the total (RAMPAIALL) sits below all three, so the size series appear to leave out Ramp's smallest segment, which its own site calls micro-SMB. Firm size is covered by the Census chart.
- 2026-10-06: xAI is shown in grey: it is the third provider FRED carries, and leaving it out would imply only two are tracked.
