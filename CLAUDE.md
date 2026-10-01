# Nicholas Baulch's website

## What this is

My personal website: a home page about me, my resume, and a section of charts on the U.S. economy worth watching, built from public data and kept current. The charts are organized into a small number of topics. Each chart comes with a short note I write. Being selective matters more than being comprehensive, and each chart should earn its place by answering a distinct question.

Topics so far: the AI economy, interest rates, inflation, and trade. Build the site so adding a topic is straightforward, but don't build for topics that don't exist yet.

I'm a macroeconomist. I know the data and the economics well. I'm less experienced with web development and production engineering, so explain tradeoffs there plainly and don't assume I'll catch problems in that part of the stack.

## Why it exists

Much of the best analysis in this area is published once, as a blog post or a Fed note, and then goes stale. The site's value is keeping a few of those analyses current, with credit to the original authors, and adding charts of measures worth tracking.

## I do the writing

All page text, analysis, and commentary on the site is mine, as the home page says. Build the chart and show it to me; I write the words around it. When I give you text, use it as written, and point out anything that looks like a typo rather than changing it.

Claude still writes what belongs to the chart itself (title, subtitle, legend, source line, and definitions on the sources page) and the spec, code comments, and commit messages. Those stay factual: what is shown and how it was built, not what it means. Leave interpretation for me.

## Topics and charts

- **The AI economy**: `charts/ai-investment-gdp/`, `charts/ai-adoption/`, `charts/productivity-decomposition/`.
- **Interest rates**: `charts/yield-decomposition/`, `charts/yield-rise-by-model/`, `charts/duration-supply/`. Candidate: the 10-year yield split into inflation-protected yield and breakeven inflation, with the 2-year yield.
- **Inflation**, started September 2026: `charts/inflation-measures/` (measures of underlying inflation over time, and a table of their latest rates over 12, 6, 3, and 1 months), `charts/inflation-1970s/` (today set against the 1970s, with the 571-month shift of the widely shared version), `charts/inflation-breadth/` (reproduces Warsh's share of PCE categories rising faster than 3 percent), `charts/pce-cpi-gap/` (the gap between core PCE and core CPI by item, as changes from the 2011–19 average), and `charts/software-electricity-prices/` (contributions of software and electricity prices, adapted from the FEDS Note on software prices). Planned: inflation expectations. Release-day tools (PCE implied by CPI and PPI, surprises) come later; surprises need a public benchmark, such as the Cleveland Fed nowcast, since consensus forecasts are proprietary.
- **Trade**, started September 2026, built on the Census trade store: `charts/effective-tariff-rate/` (the collected tariff rate, following the Fed Board's April 2026 FEDS Note, and the rate at the 2024 mix of products and countries) and `charts/goods-balance/` (the goods balance by Census product category: computers, semiconductors and telecom equipment, pharmaceuticals, gold, and the rest). Planned: imports from China as reported by the United States and by China, with partner shares. Candidate: imports by size of tariff increase.

## Chart candidates

These are the analyses I've been considering. Treat them as starting points. Verify sources, figures, and URLs yourself before relying on them.

- **AI investment's contribution to real GDP growth**, gross versus net of imported computers and semiconductors. Built in `charts/ai-investment-gdp/`, following the FEDS Note method.
  - Related work: Federal Reserve FEDS Note on publicly available AI data (July 2026), ING THINK (August 2026), St. Louis Fed On the Economy (January 2026).
  - Data: BEA NIPA investment detail, Census trade data, Census construction spending.
- **AI adoption by firm size.** Built in `charts/ai-adoption/`: the Census BTOS share of firms using AI in three size groups, weighted by Census firm counts. The earlier version across denominators (firms, workers, and one employment-weighted survey point) was dropped as hard to read. `reproduce.R` also checks worker figures from the Real-Time Population Survey.
  - Related work: Allen, FEDS Note, April 2026; Bick and coauthors, St. Louis Fed, June 2026, on question wording.
  - Known break: BTOS changed its AI question wording in November 2025. Size-class estimates exist only for the new wording.
- **Employment of young workers by occupational AI exposure**, from CPS microdata. Dropped in September 2026 because the Stanford and ADP Canaries dashboard already tracks it monthly.
  - Related work: Dallas Fed, January 2026.
- **Electricity demand and prices by state.** Built from EIA Form 861M and dropped in September 2026, because the link to AI is indirect and the investment chart already covers data centers and power.
- **Labor productivity versus utilization-adjusted TFP**, showing the utilization contribution. Built in `charts/productivity-decomposition/`.
  - Related work: Ernie Tedeschi, Stripe Economics, July 2026.
  - Data: BLS productivity, SF Fed (Fernald) TFP.
- **Supply- versus demand-driven inflation** (Shapiro, San Francisco Fed). Built and dropped in September 2026, because the San Francisco Fed already maintains and charts the series monthly.
- **Tariffs and inflation.** Explored and dropped in September 2026. Aggregate estimates of the tariff effect on prices (St. Louis Fed, April 2026 FEDS Note, Minneapolis Fed) depend on import-content, pass-through, and timing assumptions that could not be reproduced cleanly from public data, and a product-level version was not pursued.
- **Industry AI adoption versus labor productivity growth**, before and after removing 2016 to 2019 trends. Set aside: it answers a narrower cross-sectional question.
  - Related work: same Tedeschi post.
  - Data: BTOS, Chicago Fed industry productivity.

## How I want to work

- Start with one chart and get it right before building a framework around it.
- Don't commit or push until we've discussed the change and I've said to. Make edits locally, show me the result, and wait. One commit when we agree beats several along the way.
- Before pushing to a branch with a pull request, check that the pull request is still open; I often merge right away. If it's merged or closed, start a new branch from `main` and open a new pull request. Never tell me a change is in an open pull request without checking.
- When a chart starts from someone else's analysis, check it against their published numbers where you can, and tell me what differs. A mismatch is worth knowing, not a reason to stop.
- Reproduction checks are for building a chart. Once it's set up, refreshes and revisions don't need `reproduce.R` rerun, and a later mismatch from revised data isn't a problem to fix.
- Measuring the right thing matters more than matching the original. When a chart departs from the work it started from, record why in the spec's decision log.
- Each chart should have a written spec: sources, series identifiers, transformations, vintage handling, and known breaks. The spec is what makes refreshes reliable and reviewable.
- Refreshes are automatic (see Publishing). What a refresh changed, and what it might mean, goes to me privately by email from the Claude Routine, never into the repo.
- Credit and link the original analysis when a chart reproduces or closely follows someone else's work. A chart that only borrows an idea or a comparison period doesn't need a credit line; I decide the close calls.
- Prefer boring, durable choices for data and hosting. This is a side project and needs to survive long gaps between sessions.

## Constraints

- Public data and personal tools and accounts only.
- Nothing publishes without my review, except data refreshes: they rerun reviewed code on new data and write no text. Code, page text, and new charts go through pull requests.
- I prefer to work in R.

## Repo layout

```
_quarto.yml, *.qmd      the site: config, index.qmd (home), resume.qmd, sources.qmd, and one page per chart topic
images/                 headshot and link preview image
styles.css              site styling, matched to STYLE.md
R/                      fetch_<agency>_<dataset>() functions, one file per agency, chart_style.R, and price_indexes.R
fonts/                  bundled chart font, used by charts and the site
charts/<chart-name>/
  spec.md               sources, series IDs, transformations, vintages, breaks, decision log
  build.R               fetch, transform, plot, top to bottom
  reproduce.R           check against the original analysis, for charts that maintain someone else's work
  data/                 small dated snapshots of fetched data (committed)
  output/               chart images (wide and narrow) and CSV of the plotted series, all committed and published
scripts/                jobs that maintain shared data, such as update_census_trade.R
cache/                  large raw downloads (not committed)
```

- Organize by chart. Code moves to `R/` only when a second chart needs it.
- Use `tidyusmacro` (CRAN) for BLS, BEA NIPA, and FRED. Write `fetch_*` functions only for sources it doesn't cover.
- Census goods trade comes from the trade store: monthly imports and exports by 10-digit product and country from January 2010, one Parquet file per flow and month, attached to the `census-trade-data` release of this repo. `read_census_trade(flow, from, to)` downloads the months a chart needs into `cache/` and returns an Arrow dataset. `.github/workflows/census-trade-data.yml` runs `scripts/update_census_trade.R` daily to add new months and re-pull any that Census revises. Imports keep the rate provision (duty-free under a trade agreement, dutiable, and so on); exports keep domestic versus re-exported goods; customs districts are summed out.
- A topic is one `.qmd` page that shows its charts in order. Add it to `render`, the Charts menu in `_quarto.yml`, and the list on the home page.
- `resume.qmd` is the single source for the resume: Quarto renders it as the web page and, through Typst, as `nicholas-baulch-resume.pdf`. Edit only that file.
- Every chart on the site has a link to download its CSV. Under each chart, one link goes to its entry on `sources.qmd`, which holds the definitions, sources, release dates, credit links, and CSV download.
- No `legacy/`, `_backup`, `_v2`, or `_old` files. Git is the history.
- Every chart names its source and data release in the notes. Series identifiers and formulas go in the spec, not on the chart.

## Publishing

The site is https://nbaulch.github.io/, built from the `nbaulch/nbaulch.github.io` repo with Quarto and hosted on GitHub Pages.

- `main` is protected. Every change goes through a pull request that I review and merge.
- Any push to `main` runs `.github/workflows/publish.yml`, which renders the pages and publishes them. It does not run R.
- Two workflows run R. `census-trade-data.yml` maintains the Census trade store; it changes only release assets. `refresh-charts.yml` runs after it each day: it reruns every chart's `build.R` and commits the charts whose plotted CSV changed, so new data and revisions publish the same day. A failed build leaves that chart as it was and marks the run failed, which GitHub emails me about. It pushes to `main` with a deploy key that the `main` ruleset lets bypass its pull request rule, and needs the repository secrets `DEPLOY_KEY` and `CENSUS_API_KEY`.
- A Claude Routine, separate from the workflows, reads each day's refresh commit on `main` and emails me a private interpretation of what changed. It never writes to the repo or GitHub. Its prompt lives in the Routine, not here.
- A new chart's `build.R` must run unattended from a fresh checkout, since the refresh workflow runs it daily.

## Code style

The standard is a repo Hadley Wickham would be proud of: well thought out, functional, organized, and easy to read. Over-engineered code is a failure, not a safe default.

- Follow the [tidyverse style guide](https://style.tidyverse.org/). Use tidyverse packages and idioms (dplyr, tidyr, purrr, readr, ggplot2) unless there's a clear reason not to.
- Name objects and functions so a reader can tell what they hold or do without a comment: `snake_case`, nouns for data, verbs for functions.
- Functions that pull raw data are named for their source, as `fetch_<agency>_<dataset>()`: `fetch_census_btos()`, `fetch_bls_productivity()`. The agency prefix gives an unfamiliar acronym context and groups fetchers by source. A survey usually covers more than one topic, so the name shouldn't claim a single use.
- Everything after the fetch step is named for what it contains, not where it came from: `adoption_by_industry`, `productivity_growth`. Acronyms a general economics reader knows on sight (`gdp`, `cpi`, `tfp`) are fine anywhere.
- Write small, pure functions that take data and return data. Build steps with pipes, not intermediate `df1`, `df2`, `tmp`.
- Keep code tight. No speculative abstraction, config layers, wrapper functions around a single call, or defensive checks for cases that can't happen. Add structure only when a second real use shows up.
- Comment why, not what. No boilerplate headers, no comments restating the code.
- Delete dead code rather than commenting it out.
- If a simpler version would do the same job, write the simpler version.

## Environment notes

- Run scripts from the project root, for example `Rscript charts/productivity-decomposition/build.R`. Paths are relative to it.
- R packages are pinned in `renv.lock`. Run `renv::restore()` at the start of a session, and `renv::snapshot()` after adding a package.
- The cloud container is ephemeral and starts without R. `.claude/hooks/session-start.sh` runs at the start of every Claude Code on the web session and installs R, the graphics libraries `ragg` needs, Quarto 1.10.18 (matching the publish workflow), and the packages in `renv.lock`. It skips anything already installed. It installs packages as prebuilt Linux binaries from Posit rather than compiling from CRAN source, which takes seconds instead of many minutes. The lockfile itself points at plain CRAN, so it works on a Mac or Windows machine unchanged.
- On your own machine, install R and Quarto normally, then run `renv::restore()` once.
- Keep data pulls scripted and reproducible. Don't commit hand-edited data.

## Writing

These rules apply to the text Claude writes: chart titles, subtitles, legends, notes, and specs. The standard is text an Economist sub-editor would pass and a busy senior official would thank you for: plain, short, specific, and neutral. Readers come for the charts. Text exists to get them to the chart and to make it readable, then gets out of the way. Wordy text is a failure, not a safe default.

- **Every sentence earns its place.** Before keeping one, ask what a reader loses if it goes. If the answer is nothing, or something said elsewhere, cut it. The first edit of any draft removes; rewording comes second.
- **Say it once, in the right place.** Each fact has one home: what is shown in the title; units, basis, and adjustment in the subtitle; series names in the legend; definitions on the sources page; method, caveats, and reasoning in the spec. Page text never restates any of them.
- **Page text is mine.** Leave the paragraph above a new chart for me to write, with a placeholder if the page needs one to render.
- **No explaining the method on the page.** Why a series is adjusted, how a measure is built, what a revision means: the spec holds it, or the sources page if a reader needs it to read the chart.
- **Plain words, named for what they are.** "Imports of computers", not "AI hardware". Everyday terms over jargon; no acronyms a general reader doesn't know on sight. If a category is broader than its label, name the components.
- **No filler.** No "this chart shows", "it is worth noting", "importantly", "key", or "notably". No hedges, no throat-clearing, no summary of what was just said. Titles are under ten words, subtitles one line.
- **The same thing has the same name everywhere**: in titles, legends, tables, notes, and page text.
- Plain, measured, declarative. No marketing language. Em dashes for an aside, not for effect. Sentence case.

Charts follow `STYLE.md`. The title names what the chart shows, never a finding. Annotations are neutral references only, such as a policy goal or a historical average. Smooth data when noise hides the signal, and say how in the subtitle.

## Design

The standard is a site Edward Tufte would recognize: quiet, printed-report restraint, where the charts are the only thing that draws the eye. It should feel like a well-set page, not a web app. Decoration is a failure, not polish.

- **Content first; the design disappears.** No cards, boxes, shadows, icons, badges, banners, animations, or hero images. The photo on the home page and the favicon, a robin perched on a chart line that also appears on the page-not-found page, are the only images that aren't data. Keep the robin to those two places.
- **Hierarchy comes from size, weight, and space, never from color or ornament.** One thing is the heading on any part of the page, and nothing competes with it. On a chart section that is the chart's own title.
- **Space shows what belongs together.** Things that go together sit close; separate things sit clearly apart. Space within a unit is always smaller than space between units. One spacing scale, used everywhere; no one-off margins.
- **One column, one left edge.** The navbar, text, charts, tables, and footer share a 720px column and align to the same left edge. Nothing is centered except by accident of width.
- **One pattern per element.** A chart, a table, a section, a source line, and a link each look the same on every page. A new element reuses an existing pattern before a new one is invented, and a change to one instance is made to every instance.
- **Color is for data.** Page chrome is paper, ink, and greys; one accent blue marks links and nothing else.
- **Type:** a serif for reading text, the chart sans for everything else, no third family. Body text near 18px, lines of 65 to 75 characters.
- **Phones are not an afterthought.** Every page works at 390px wide, nothing scrolls sideways, and narrow chart versions are drawn for it.
- **Add structure only when a second real use shows up**, as in the code. No design for pages or elements that don't exist yet.

## Reviewing published work

Review the page, not the diff, and review it as a skeptical editor who didn't write it. Before calling any change to the site done:

- Render it and look at every affected page top to bottom, on a desktop and at phone width.
- Read every piece of text and ask whether it needs to exist, following the writing rules above.
- Check the page against the design rules above: competing headings, uneven or stacked spacing, anything repeated, anything misaligned, any element treated differently from its siblings.
- Fix the rule, not the instance: when something is wrong in one place, find every other place the same rule applies and fix those too.
- Show me before and after screenshots.

When I ask for options, give a recommendation. When I'm unsure, show me a preview rather than describing it.

## Vintages and revisions

- Charts show the latest release of their data.
- Each fetch saves the source release as a dated file in the chart's `data/` folder, named by the source's release date when the source gives one. Git keeps the history.
- The refresh workflow commits a chart when its plotted CSV changes. The git diff of the CSV is the record of new data and revisions.
- Reproductions of someone else's work use the vintage closest to theirs when it is available, and say so when it isn't.

## Open questions

None right now. When a new decision about the stack, data, or publishing comes up, ask me rather than deciding it silently.
