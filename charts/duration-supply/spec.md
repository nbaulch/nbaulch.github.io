# Duration supplied to private investors by Treasury and big tech bonds

Status: built in R from data through August 2026 (fetched September 26, 2026), with big tech bonds back to each company's first registered bond. Original chart, prompted by Alex Etra's; it doesn't reproduce his numbers (see below).

## Question

How much long-term debt, measured in 10-year equivalents, do Treasury and the largest AI borrowers add to private investors' holdings each year?

## Related work

- Alex Etra, Exante Data, "Net duration supplied to the US private market," chart on X, September 2026, shared by Brad Setser. Change in the stock of 10-year equivalents over 12 months, monthly: Treasury net of Fed holdings and buybacks, hyperscalers, other nonfinancial corporates, and financials. Sources on the chart: TreasuryDirect auction history, New York Fed holdings, Fiscal Data buybacks, and Bloomberg for corporate bonds. His methods note is referenced but not public, and the corporate data are proprietary, so the chart is credited as related work, not reproduced.
- Hugo De Vere, Srini Ramaswamy, and Seth Searls, "How AI debt financing impacts duration supply and interest rates," Federal Reserve Bank of Dallas, February 10, 2026. https://www.dallasfed.org/research/economics/2026/0210-searls-aifinancing. About $300 billion of AI-related investment-grade issuance in 2026, about $360 billion in 10-year equivalents, "an eighth of the duration supply from U.S. Treasury issuance." That compares with gross Treasury issuance; this chart is net.

## Sources

| Data | Provider | Fetch |
|---|---|---|
| Marketable Treasury securities outstanding by CUSIP, month end, net of buybacks | Treasury, Monthly Statement of the Public Debt, Fiscal Data API | `fetch_treasury_mspd_marketable()` |
| Fed holdings by CUSIP, weekly | New York Fed, System Open Market Account API | `fetch_nyfed_soma_treasury()`, `fetch_nyfed_soma_dates()` |
| Big tech bonds: currency, amount, coupon, and maturity of each tranche | SEC EDGAR, covers of final 424B2 and 424B5 prospectus supplements, plus two exchange offers (424B3) | `fetch_sec_filings()`, `fetch_sec_prospectus_tranches()` |
| Nominal and real Treasury yield curves | Fed Board H.15, from FRED | `tidyusmacro::getFRED()`: DGS1MO to DGS30, DFII5 to DFII30 |

- EDGAR requires a user agent with a contact email, read from the `SEC_USER_AGENT` environment variable and never committed.
- Downloads that don't change are cached in `cache/` (not committed): weekly Fed holdings and SEC filings.
- Companies: Alphabet (CIK 1652044) and Google Inc. before it (1288776), Amazon (1018724), Meta (1326801), Microsoft (789019), Oracle (1341439). Filings from each company's first bond, 2007 for Oracle and 2009 for Microsoft. Microsoft has registered no bonds since 2017.

## Transformations

- Treasury held privately = amount outstanding minus Fed holdings on the last Wednesday on or before the month end. Buybacks are already netted out of amounts outstanding.
- Big tech bonds outstanding at a month end = dollar tranches issued on or before it and not yet matured. Each tranche's currency is read from its own symbol on the cover; Canadian-dollar, euro, sterling, and yen tranches are excluded. Maturity is the date in the title when given, otherwise the maturity year with the issue's month and day. Tranches listed twice on a cover (different spacing or a full maturity date) are matched on amount, coupon, and year.
- Two deals were first sold privately and registered later through exchange offers: Amazon's $16 billion on August 22, 2017 (accession 0001193125-18-154502) and Meta's $10 billion on August 9, 2022 (0000950103-22-020353). They are dated by those issue dates, which the filings state.
- Modified duration of each security from its coupon and remaining maturity, priced on the latest month-end yield curve for every month. Bills are zero-coupon, floating rate notes count as zero duration, inflation-protected securities are priced on real yields, and corporate bonds on the Treasury curve without a credit spread.
- 10-year equivalents = amount times duration divided by the duration of a new 10-year note on the same curve.
- The chart plots the 12-month change in each stock. It includes new issuance, maturities, buybacks, changes in Fed holdings, and bonds aging toward maturity.

## Vintages

- `data/treasury_held_privately_<latest month end>.csv`: privately held amounts by month and security type. Security-level data, about 100,000 rows, are rebuilt from the sources on each run.
- `data/sec_hyperscaler_bonds_<fetch date>.csv`: every big tech dollar tranche used, with issue date, accession number, amount, coupon, and maturity.
- Because every month is priced on the latest curve, the whole history shifts slightly on each refresh.

## Comparison with Etra

12-month change in Treasury held privately, billions of 10-year equivalents:

| | Ours | Etra (read off his chart) |
|---|---|---|
| 2016 to 2019 | 430 to 700 | about 500 |
| Mid-2020 | about -400 | about 0 |
| 2021 to 2022 peak | about 1,650 | about 1,300 |
| August 2025 | 1,004 | about 1,050 |
| August 2026 | 980 | about 800 |

Big tech, August 2026: ours 255, his about 400. His Bloomberg data likely include private placements (such as the roughly $27 billion Meta Hyperion financing) and possibly other issuers.

Valuation choice: priced at each month's own yields, our Treasury series swings with rates (620 in February 2026, 1,153 in August 2026). The fixed curve removes that.

## Known breaks and caveats

- Early redemptions, tender offers, and debt swaps aren't captured. Microsoft's exchange offers of 2020 and 2021, which swapped about $18 billion of older notes for new 2050 to 2062 notes, are left out entirely, since counting the new notes without retiring the old ones would double count. Notes assumed in acquisitions (Whole Foods, Activision Blizzard) are also left out.
- Private placements, other AI borrowers (such as data center developers and chip makers), and foreign-currency bonds are excluded.
- Other corporate and financial bonds, which Etra includes, aren't covered: no free source gives their maturities.
- Mid-2020: our series and Etra's differ in sign. Unresolved.

## Decision log

- 2026-09-26: Build from public data; credit Etra and the Dallas Fed as related work rather than reproducing Etra, whose method and corporate data aren't public.
- 2026-09-26: Value every month on the latest yield curve, so the series reflects what was issued rather than yield swings.
- 2026-09-26: Dollar bonds only, since the question is the U.S. market.
- 2026-09-26: Read big tech bonds from prospectus covers instead of structured filing fee exhibits, which start only in August 2024. Covers go back to each company's first bond, so the chart shows big tech from 2011 and subtracts older bonds' aging. On the 2024 to 2026 deals the covers match the fee exhibits to within $0.4 billion of $283 billion; the exhibits sometimes give offering prices, the covers face amounts. The change also fixed Canadian-dollar tranches (Alphabet C$8.5 billion, Amazon C$14 billion in 2026) that the old currency check read as U.S. dollars. Together these moved the August 2026 figure from $284 billion to $255 billion.
