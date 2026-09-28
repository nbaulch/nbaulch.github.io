# AI adoption by firm size

Status: built in R from the Business Trends and Outlook Survey published September 24, 2026 (survey through September 6, 2026), weighted with Statistics of U.S. Businesses firm counts for 2022. `reproduce.R` also checks worker figures from the Generative AI Adoption Tracker, fetched September 26, 2026. It matches every number checked from the original.

## Question

What share of U.S. firms use AI, by firm size?

## Original analysis

Jeffrey S. Allen, "Monitoring AI Adoption in the U.S. Economy," FEDS Notes, Federal Reserve Board, April 3, 2026.
https://www.federalreserve.gov/econres/notes/feds-notes/monitoring-ai-adoption-in-the-u-s-economy-20260403.html

Figure 2 shows BTOS firm adoption (current and planned, September 2023 to end of 2025) and RPS generative AI adoption (work and non-work, August 2024 to November 2025). Figure 3 shows adoption by firm size in BTOS and in the Atlanta Fed's Survey of Business Uncertainty. The note publishes no figure data; the accessible version describes the figures without values.

Related work:

- Alexander Bick, Adam Blandin, David Deming, Nicola Fuchs-Schündeln, and Jonas Jessen, "Measuring AI Adoption by Firms: How You Ask Matters," On the Economy, St. Louis Fed, June 1, 2026. https://www.stlouisfed.org/on-the-economy/2026/jun/measuring-ai-adoption-firms-how-you-ask-matters. Compares the BTOS with the EU's firm survey and concludes that the narrow wording of the original BTOS question explains most of the gap between firm and worker adoption: "That disconnect was mostly illusory: Once you account for the narrowness of the BTOS question, firm and worker adoption rates are much more similar."

## Sources

| Measure | Survey | Fetch | Series |
|---|---|---|---|
| Firms, old question | Census, Business Trends and Outlook Survey | `fetch_census_btos("AI Core Questions.xlsx", "National Estimates")` | Question 7, answer "Yes", national, periods 202319 to 202520 |
| Firms, new question | same | `fetch_census_btos("National.xlsx", "Response Estimates")` | Question 7, answer "Yes", national, periods from 202524 |
| Firms by employment size | same | `fetch_census_btos("Employment Size Class.xlsx", "Response Estimates")` | Question 7, answer "Yes", size classes A (1 to 4 employees) to G (250 or more) |
| Survey dates | same | `fetch_census_btos_periods()` | "Collection and Reference Dates" sheet of `National.xlsx` |
| Workers (for `reproduce.R` only) | Real-Time Population Survey (Bick, Blandin, and Deming), from the Generative AI Adoption Tracker | `fetch_rps_genai()` | `GenAI_All.csv`: sample "Employed", use "For Work", "Share Using GenAI", mean |
| Firm counts by size, for weights | Census, Statistics of U.S. Businesses, 2022 | `fetch_census_susb(2022)` | U.S., all industries, detailed enterprise sizes |
| Jobs at firms using AI (no longer shown) | Atlanta Fed, Survey of Business Uncertainty | none | 78 percent, November 2025, as reported by Allen |

BTOS downloads: `https://www.census.gov/hfp/btos/downloads/<file>`. The data page (https://www.census.gov/hfp/btos/data_downloads) builds its links in JavaScript, so the file names were read from its script.

Tracker downloads: `https://www.genaiadoptiontracker.com/GenAI_All.csv`. The site loads its charts from this file; it has no download button, so the address could change without notice.

## Definitions

- BTOS question 7, September 2023 to October 2025: "In the last two weeks, did this business use Artificial Intelligence (AI) in producing goods or services?" From November 2025: "... in any of its business functions?" Both give examples: machine learning, natural language processing, virtual agents, voice recognition. Estimates are shares of employer businesses, each counted equally.
- RPS: "Do you use Generative AI for your job?", with generative AI defined as AI that creates text, images, audio, or video from prompts, such as ChatGPT, Gemini, and Midjourney. Share of employed adults. Quarterly since August 2024, about 5,000 to 6,000 responses.
- SBU: executives report whether their firm uses any of seven AI technologies; the estimate weights firms by employment. Asked once, in November 2025. Equal-weighted, the same survey gives 69 percent.

## Transformations

- Each BTOS period is dated by the end of the two-week reference period it asks about. RPS survey months are dated on the first of the month.
- Old and new BTOS questions are separate series with a gap between them: no AI estimates are published for periods 202521 to 202523 (October and November 2025, which include the federal shutdown).
- The chart groups the seven BTOS size classes into fewer than 50 employees (A to D), 50 to 249 (E and F), and 250 or more (G). Each group is the average of its classes weighted by the number of firms in each, from SUSB. SUSB's 200 to 299 class straddles the 250 cutoff and is split evenly between F and G.
- Each plotted point is the average of the latest three survey periods (six weeks), because single size classes, especially G, swing by several points from survey to survey. BTOS estimates are not seasonally adjusted.
- Size-class estimates are published only for the new question, so the chart starts in November 2025 and has no wording break.

## Vintages

- SUSB snapshot: `data/census_susb_firms_2022.csv`, firm counts by BTOS size class. The full table is cached in `cache/census_susb/`.
- BTOS snapshot: `data/census_btos_ai_<publication date>.csv`, the AI question rows only (national old and new wording and size classes), named by the publication date of the latest survey period. The full downloads are over a megabyte each.
- RPS snapshot: `data/rps_genai_<fetch date>.csv`, the whole `GenAI_All.csv` in long form. The tracker gives no release date.
- The SBU value is quoted, not fetched. The Atlanta Fed publishes no data file for these questions. This is an exception to the rule against hand-entered data, approved on 2026-09-26.

## Reproduction status

`reproduce.R` compares the snapshots with the values in Allen's text. All match at his rounding: the change in the old-question firm share from September 2023 to October 2025, 6.3 points (about 6); 17.8 percent of firms at the end of 2025 (18); 33.3 and 40.7 percent of workers using generative AI for work in August 2024 and November 2025 (33 and 41); 36.0 and 49.7 percent of adults using it outside work (36 and 50); and in November 2025, 35.2 percent using it for work in the last week and 12.0 percent every day. The current downloads were used; BTOS and RPS don't publish earlier vintages.

## Known breaks and caveats

- The BTOS wording changed in November 2025, so estimates before and after are not comparable. The two series should not be joined.
- Firm, worker, and job measures of AI use differ in unit, in weighting, and in the question asked, so they aren't comparable. Bick and coauthors attribute much of the gap between firm and worker surveys to question wording.

## Decision log

- 2026-09-26: A first version showed firms (BTOS, both wordings), workers (RPS), and jobs at firms using AI (SBU, one point quoted from Allen). It was replaced with firm use by size over time: the single SBU point confused readers, and a job-weighted line built from BTOS size classes and SUSB employment was hard to read next to the other lines and is a lower bound, because the 250-plus class is open-ended.
