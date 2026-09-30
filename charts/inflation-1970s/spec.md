# Inflation today and in the 1970s

Status: built in R from BLS CPI on FRED (fetched September 30, 2026, through August 2026).

## Question

How does consumer price inflation since 2015 compare with inflation from the late 1960s to the early 1980s, set on the same timeline?

## Related work

No single original author is identified. Versions checked:

- ING THINK, "Inflation's second wave: Are we really watching a 70s rerun?", August 30, 2023. https://think.ing.com/articles/inflations-second-wave-are-we-really-watching-a-70s-rerun/. Draws its own version, headline inflation lagged 571 months, and notes that many similar charts were already on social media. The shift here is theirs.
- Torsten Slok, Apollo. Core CPI, 1966 to 1982 against 2014 onward, on separate scales. Shown by John Cochrane in May 2024 (https://www.grumpy-economist.com/p/inflation-analogy) and posted again by Slok on August 31, 2025 (https://www.apolloacademy.com/will-we-see-a-repeat-of-2021-and-the-1970s/).
- Jim Reid, Deutsche Bank, Chart of the Day, March 9, 2026, which says Deutsche Bank used the chart a few years earlier.
- James Smith, ING THINK, May 22, 2026. https://think.ing.com/opinions/think-ahead-inflations-second-wave-is-history-really-repeating-itself/. Repeats the 571-month version.

## Sources

| Data | Provider | Fetch | Series |
|---|---|---|---|
| Consumer price index, all urban consumers, all items, seasonally adjusted | BLS, from FRED | `tidyusmacro::getFRED()` | CPIAUCSL |

## Transformations

- Inflation = 100 × (index over its value 12 months earlier − 1).
- The 1970s line is the same series shifted forward 571 months (47 years and 7 months): its value at each date is inflation 571 months earlier. The shift sets June 2022 on November 1974.
- The chart shows January 2015 to December 2030, so the 1970s line covers June 1967 to May 1983. The bottom axis gives today's years; the top axis gives the 1970s line's years, placed where they fall after the shift.
- The CSV runs from 1948, with a row for every month through December 2030; `inflation_571_months_earlier` is the 1970s line.

## Vintages

- `data/fred_cpi_<last month>.csv`. FRED's download carries no release date, so it is named by the last month it covers.
- BLS revises seasonal factors each February for the past five years. Earlier data are not revised.

## Checks

The seasonally adjusted series gives the figures quoted in the pieces on this chart: 12.2 percent in November 1974, 14.6 percent in March 1980, 9.0 percent in June 2022, 2.3 percent in April 2025, and 4.2 percent in May 2026.

## Known breaks and caveats

- The CPI treated homeownership costs differently before 1983, when BLS switched to owners' equivalent rent. The 1970s line uses the index as published then, not the research series (R-CPI-U-RS) that applies today's methods to earlier years.
- The 571-month shift is taken from the circulating chart, not chosen here.

## Decision log

- 2026-09-30: Headline CPI, seasonally adjusted, which matches the figures quoted for the circulating chart. The shift follows ING's 2023 version.
- 2026-09-30: No credit line on the chart or sources page, at Nicholas's call, since the chart has no single original author.
