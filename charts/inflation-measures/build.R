library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(stringr)
library(lubridate)
library(ggplot2)
library(slider)
library(patchwork)

source("R/fetch_bea.R")
source("R/price_indexes.R")
source("R/fetch_clevelandfed.R")
source("R/fetch_nyfed.R")
source("R/chart_style.R")

chart_dir <- "charts/inflation-measures"

# Price indexes (G) and spending (C) from NIPA table 2.4.4U and 2.4.5U.
pce_series <- c(
  headline = "DPCERG", headline_spending = "DPCERC",
  core = "DPCCRG",
  market_core = "DPCXRG", market_core_spending = "DPCXRC",
  energy_goods = "DGOERG", energy_goods_spending = "DGOERC",
  market_housing = "DHSMRG", market_housing_spending = "DHSMRC"
)

pce <- fetch_bea_nipa(pce_series, frequency = "M")
median_pce <- fetch_clevelandfed_median_pce()
trimmed_mean <- tidyusmacro::getFRED(twelve_month = "PCETRIM12M159SFRBDAL", six_month = "PCETRIM6M680SFRBDAL")
trend <- fetch_nyfed_mct()

# None of the sources dates its release in the download, so snapshots are named
# by the last month they cover.
latest_month <- max(pce$date)
list(bea_pce = pce, clevelandfed_median_pce = median_pce, dallasfed_trimmed_mean = trimmed_mean, nyfed_mct = trend) |>
  iwalk(\(data, name) write_csv(data, file.path(chart_dir, "data", str_glue("{name}_{latest_month}.csv"))))

twelve_month_change <- \(index) 100 * (index / lag(index, 12) - 1)
six_month_change <- \(index) 100 * ((index / lag(index, 6))^2 - 1)

measures_from_indexes <- pce |>
  arrange(date) |>
  transmute(
    date,
    headline,
    core,
    excluding_energy_goods = index_excluding(headline, headline_spending, energy_goods, energy_goods_spending),
    market_core,
    market_core_excluding_housing = index_excluding(market_core, market_core_spending, market_housing, market_housing_spending)
  ) |>
  pivot_longer(-date, names_to = "measure", values_to = "index") |>
  mutate(twelve_month = twelve_month_change(index), six_month = six_month_change(index), .by = measure) |>
  select(-index)

inflation <- bind_rows(
  measures_from_indexes,
  median_pce |>
    arrange(date) |>
    transmute(
      date,
      measure = "median",
      twelve_month,
      six_month = 100 * (exp(2 * slide_dbl(log1p(monthly / 100), sum, .before = 5, .complete = TRUE)) - 1)
    ),
  mutate(trimmed_mean, measure = "trimmed_mean"),
  # The New York Fed measure is already an estimate of trend, so it has no
  # six-month version.
  transmute(trend, date, measure = "trend", twelve_month = trend)
) |>
  filter(!is.na(twelve_month))

inflation |>
  pivot_wider(names_from = measure, values_from = c(twelve_month, six_month), names_glue = "{measure}_{.value}") |>
  select(date, where(\(x) any(!is.na(x)))) |>
  arrange(date) |>
  mutate(across(-date, \(x) round(x, 2))) |>
  write_csv(file.path(chart_dir, "output", "inflation-measures.csv"), na = "")

measures <- tribble(
  ~measure, ~label, ~definition,
  "headline", "Headline", "All consumer spending.",
  "core", "Core", "Excluding food and energy.",
  "excluding_energy_goods", "Excluding energy goods", "Excluding gasoline and other fuels, but keeping food and energy services.",
  "market_core", "Market-based core", "Core, excluding prices the government estimates rather than observes, such as for free bank services.",
  "market_core_excluding_housing", "Market-based core excluding housing", "Market-based core, also excluding rents.",
  "median", "Median", "The price change in the middle of the distribution each month.",
  "trend", "New York Fed trend", "A model estimate of trend inflation from 17 sectors.",
  "trimmed_mean", "Trimmed mean", "The average price change after dropping the largest and smallest each month."
)

latest <- inflation |>
  filter(date == latest_month) |>
  left_join(measures, by = "measure")
month_label <- format(latest_month, "%B %Y")

write_chart_notes(
  notes = c(
    str_glue("**{measures$label}:** {measures$definition}"),
    "**Dashed line:** The Federal Reserve's 2 percent inflation goal."
  ),
  source = str_glue(
    "Sources: Bureau of Economic Analysis, through {month_label}; Federal Reserve Bank of Cleveland, ",
    "[median PCE](https://www.clevelandfed.org/indicators-and-data/median-pce-inflation); Federal Reserve Bank of ",
    "Dallas, [trimmed mean PCE](https://www.dallasfed.org/research/pce), from FRED; Federal Reserve Bank of New York, ",
    "[Multivariate Core Trend](https://www.newyorkfed.org/research/policy/mct). Excluding energy goods follows the ",
    "Federal Reserve Bank of St. Louis, [\"Between Headline and Core\"]",
    "(https://www.stlouisfed.org/on-the-economy/2026/jul/between-headline-core-inflation-excluding-energy-goods), ",
    "July 2026; market-based core excluding housing follows Omair Sharif, Inflation Insights."
  ),
  csv_path = file.path(chart_dir, "output", "inflation-measures.csv"),
  path = file.path(chart_dir, "output", "inflation-measures-notes.md")
)

# Each panel's title reads as a heading under the chart's own title.
panel_title_style <- theme(plot.title = element_text(size = rel(0.95), face = "plain", colour = chart_greys[["text"]]))

# Top panel: headline and core over time, with the range of the other measures.
history_start <- ymd("2019-01-01")
other_range <- inflation |>
  filter(!measure %in% c("headline", "core"), date >= history_start) |>
  summarise(low = min(twelve_month), high = max(twelve_month), measures = n(), .by = date) |>
  filter(measures >= 5)

history_panel <- ggplot() +
  geom_ribbon(data = other_range, aes(date, ymin = low, ymax = high, fill = "range"), alpha = 0.35) +
  geom_line(
    data = filter(inflation, measure %in% c("headline", "core"), date >= history_start),
    aes(date, twelve_month, colour = measure),
    linewidth = 0.9
  ) +
  geom_hline(yintercept = 2, colour = chart_greys[["muted"]], linetype = "dashed", linewidth = 0.4) +
  scale_colour_manual(
    values = c(headline = chart_colors[["orange"]], core = chart_colors[["blue"]]),
    labels = c(headline = "Headline", core = "Core"),
    breaks = c("headline", "core")
  ) +
  scale_fill_manual(values = c(range = chart_greys[["muted"]]), labels = c(range = "Range of other underlying measures")) +
  scale_x_date(breaks = seq(history_start, latest_month, by = "2 years"), date_labels = "%Y") +
  scale_y_continuous(breaks = scales::breaks_width(1)) +
  labs(title = "12-month change, since 2019") +
  theme_chart() +
  panel_title_style

# Bottom panel: every measure's latest 12-month and six-month rates.
latest_panel <- function(label_width) {
  latest |>
    pivot_longer(c(twelve_month, six_month), names_to = "window", values_to = "rate") |>
    filter(!is.na(rate)) |>
    mutate(label = factor(str_wrap(label, label_width), levels = str_wrap(arrange(latest, twelve_month)$label, label_width))) |>
    ggplot(aes(rate, label)) +
    geom_vline(xintercept = 2, colour = chart_greys[["muted"]], linetype = "dashed", linewidth = 0.4) +
    geom_line(aes(group = label), colour = chart_greys[["grid"]], linewidth = 1.2) +
    geom_point(aes(colour = window), size = 2.6) +
    scale_colour_manual(
      values = c(twelve_month = chart_colors[["grey"]], six_month = chart_greys[["title"]]),
      labels = c(twelve_month = "Past 12 months", six_month = "Past 6 months, annualized"),
      breaks = c("twelve_month", "six_month")
    ) +
    scale_x_continuous(breaks = scales::breaks_width(1), expand = expansion(add = 0.3)) +
    labs(title = str_glue("By measure, {month_label}")) +
    theme_chart() +
    theme(
      panel.grid.major.y = element_blank(),
      panel.grid.major.x = element_line(colour = chart_greys[["grid"]], linewidth = 0.35)
    ) +
    panel_title_style
}

title <- "Measures of underlying inflation"
subtitle <- "PCE price inflation, percent"
source_line <- "Sources: Bureau of Economic Analysis; Federal Reserve Banks of Cleveland, Dallas, and New York."

annotate_panels <- function(panels, width) {
  panels +
    plot_annotation(
      title = wrap_without_orphan(title, floor((width - 0.4) * 8.5)),
      subtitle = wrap_without_orphan(subtitle, floor((width - 0.4) * 12)),
      caption = wrap_without_orphan(source_line, floor((width - 0.4) * 15.5)),
      theme = theme_chart()
    )
}

stacked_legends <- list(
  guides(colour = guide_legend(ncol = 1, order = 1), fill = guide_legend(order = 2)),
  theme(legend.box = "vertical", legend.spacing.y = unit(0, "pt"))
)

# Side by side on desktops, stacked on phones.
save_chart(
  annotate_panels(
    (history_panel + stacked_legends | latest_panel(26) + guides(colour = guide_legend(ncol = 1))) +
      plot_layout(widths = c(1.15, 1)),
    width = 8
  ),
  file.path(chart_dir, "output", "inflation-measures.png"),
  width = 8,
  height = 6
)

save_chart(
  annotate_panels(
    (free(history_panel + stacked_legends) / free(latest_panel(22) + guides(colour = guide_legend(ncol = 1)))) +
      plot_layout(heights = c(1, 1.3)),
    width = 4.2
  ),
  file.path(chart_dir, "output", "inflation-measures-narrow.png"),
  width = 4.2,
  height = 10
)
