library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)
library(ggplot2)

source("R/fetch_bea.R")
source("R/price_indexes.R")
source("R/chart_style.R")

chart_dir <- "charts/pce-cpi-gap"

# Price indexes (G) and spending (C) from NIPA table 2.4.4U and 2.4.5U.
pce_series <- c(
  core = "DPCCRG", core_spending = "DPCCRC",
  portfolio_management = "DPMIRG", portfolio_management_spending = "DPMIRC",
  software = "DCPSRG", software_spending = "DCPSRC"
)

pce <- fetch_bea_nipa(pce_series, frequency = "M")
cpi <- tidyusmacro::getFRED(core_cpi = "CPILFESL") |>
  select(date, core_cpi)

# Neither source dates its release in the download, so snapshots are named by
# the last month of PCE data.
latest_month <- max(pce$date)
write_csv(pce, file.path(chart_dir, "data", str_glue("bea_pce_{latest_month}.csv")))
write_csv(cpi, file.path(chart_dir, "data", str_glue("fred_core_cpi_{latest_month}.csv")))

twelve_month_change <- \(index) 100 * (index / lag(index, 12) - 1)

# Each item's contribution is how much core PCE inflation falls when it is
# taken out: portfolio management first, then software. Both have little or no
# weight in core CPI, so the contributions count toward the gap in full.
gap <- pce |>
  arrange(date) |>
  mutate(
    core_excluding_portfolio_management = index_excluding(
      core, core_spending, portfolio_management, portfolio_management_spending
    ),
    core_excluding_both = index_excluding(
      core_excluding_portfolio_management, core_spending - portfolio_management_spending,
      software, software_spending
    )
  ) |>
  inner_join(cpi, by = "date") |>
  arrange(date) |>
  transmute(
    date,
    core_pce = twelve_month_change(core),
    core_cpi = twelve_month_change(core_cpi),
    gap = core_pce - core_cpi,
    portfolio_management = core_pce - twelve_month_change(core_excluding_portfolio_management),
    software = twelve_month_change(core_excluding_portfolio_management) - twelve_month_change(core_excluding_both),
    everything_else = gap - portfolio_management - software
  ) |>
  filter(!is.na(gap))

gap |>
  mutate(across(-date, \(x) round(x, 3))) |>
  write_csv(file.path(chart_dir, "output", "pce-cpi-gap.csv"))

before_pandemic <- gap |>
  filter(between(year(date), 2011, 2019)) |>
  summarise(mean(gap)) |>
  pull()

month_label <- format(latest_month, "%B %Y")

write_chart_notes(
  notes = c(
    "**Gap:** The 12-month change in core PCE prices minus the 12-month change in core CPI prices. Both leave out food and energy.",
    str_glue(
      "**Gap excluding portfolio management and software:** The same gap with two items taken out of core PCE: fees ",
      "for managing investments and giving investment advice, which are in PCE but not CPI, and computer software and ",
      "accessories, which weigh far more in PCE than in CPI."
    ),
    "**Dashed line:** The average gap from 2011 to 2019."
  ),
  source = str_glue(
    "Sources: Bureau of Economic Analysis, through {month_label}; Bureau of Labor Statistics, from FRED. Follows ",
    "Mike Konczal, [\"Is the Actual Inflation Rate PCE and High or CPI and Low?\"]",
    "(https://newsletter.mikekonczal.com/p/is-the-actual-inflation-rate-pce), August 28, 2026."
  ),
  csv_path = file.path(chart_dir, "output", "pce-cpi-gap.csv"),
  path = file.path(chart_dir, "output", "pce-cpi-gap-notes.md")
)

lines <- gap |>
  filter(date >= ymd("2011-01-01")) |>
  transmute(date, gap, gap_excluding = gap - portfolio_management - software) |>
  pivot_longer(-date, names_to = "series", values_to = "gap") |>
  mutate(series = factor(series, levels = c("gap", "gap_excluding")))

gap_chart <- ggplot(lines, aes(date, gap, colour = series)) +
  geom_hline(yintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
  geom_hline(yintercept = before_pandemic, colour = chart_greys[["muted"]], linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 0.9) +
  scale_colour_manual(
    values = c(gap = chart_colors[["blue"]], gap_excluding = chart_colors[["orange"]]),
    labels = c(gap = "Gap", gap_excluding = "Gap excluding portfolio management and software")
  ) +
  scale_x_date(date_breaks = "3 years", date_labels = "%Y") +
  scale_y_continuous(breaks = scales::breaks_width(0.5)) +
  theme_chart()

title <- "Gap between core PCE and core CPI inflation"
subtitle <- "Core PCE minus core CPI, 12-month change, percentage points"
source_line <- "Sources: Bureau of Economic Analysis; Bureau of Labor Statistics. Follows Mike Konczal, August 2026."

save_chart(
  gap_chart + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "pce-cpi-gap.png"),
  width = 8,
  height = 5
)

save_chart(
  gap_chart +
    chart_labels(title, subtitle, source_line, width = 4.2) +
    guides(colour = guide_legend(ncol = 1)),
  file.path(chart_dir, "output", "pce-cpi-gap-narrow.png"),
  width = 4.2,
  height = 5.8
)
