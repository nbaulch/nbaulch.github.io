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
trimmed_mean <- tidyusmacro::getFRED(
  twelve_month = "PCETRIM12M159SFRBDAL",
  six_month = "PCETRIM6M680SFRBDAL",
  one_month = "PCETRIM1M158SFRBDAL"
)
trend <- fetch_nyfed_mct()

# None of the sources dates its release in the download, so snapshots are named
# by the last month they cover.
latest_month <- max(pce$date)
list(bea_pce = pce, clevelandfed_median_pce = median_pce, dallasfed_trimmed_mean = trimmed_mean, nyfed_mct = trend) |>
  iwalk(\(data, name) write_csv(data, file.path(chart_dir, "data", str_glue("{name}_{latest_month}.csv"))))

annualized_change <- \(index, months) 100 * ((index / lag(index, months))^(12 / months) - 1)
# The median and trimmed mean come as monthly changes, so longer rates compound
# the latest `months` of them.
compounded_change <- \(monthly, months) {
  100 * (exp(12 / months * slide_dbl(log1p(monthly / 100), sum, .before = months - 1, .complete = TRUE)) - 1)
}

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
  mutate(
    twelve_month = annualized_change(index, 12),
    six_month = annualized_change(index, 6),
    three_month = annualized_change(index, 3),
    one_month = annualized_change(index, 1),
    .by = measure
  ) |>
  select(-index)

inflation <- bind_rows(
  measures_from_indexes,
  median_pce |>
    arrange(date) |>
    transmute(
      date,
      measure = "median",
      twelve_month,
      six_month = compounded_change(monthly, 6),
      three_month = compounded_change(monthly, 3),
      one_month = compounded_change(monthly, 1)
    ),
  # The Dallas Fed publishes 1-, 6-, and 12-month rates but no 3-month rate.
  trimmed_mean |>
    arrange(date) |>
    mutate(
      measure = "trimmed_mean",
      three_month = compounded_change(100 * ((1 + one_month / 100)^(1 / 12) - 1), 3)
    ),
  # The New York Fed measure is already an estimate of trend, so it has no
  # shorter versions.
  transmute(trend, date, measure = "trend", twelve_month = trend)
) |>
  filter(!is.na(twelve_month))

inflation |>
  pivot_wider(names_from = measure, values_from = c(twelve_month, six_month, three_month, one_month), names_glue = "{measure}_{.value}") |>
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

# The Cleveland, Dallas, and New York Feds publish after BEA, so on a PCE
# release day their measures keep their rows, with dashes, until they post.
latest <- measures |>
  left_join(filter(inflation, date == latest_month), by = "measure")
month_label <- format(latest_month, "%B %Y")

write_chart_notes(
  notes = c(
    str_glue("**{measures$label}:** {measures$definition}"),
    "**Dashed line:** The Federal Reserve's 2 percent inflation goal.",
    "**Shading:** Distance from the 2 percent goal, orange above and blue below."
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

# Bottom panel: every measure's latest rates over four horizons, shaded by
# distance from 2 percent, in two blocks: headline and core, then the measures
# in the top panel's gray range. The New York Fed trend has only a 12-month rate.
horizons <- c(twelve_month = "12 months", six_month = "6 months", three_month = "3 months", one_month = "1 month")

rate_table <- function(rates, label_width, header_width, text_size, title, show_headers) {
  table <- rates |>
    mutate(published = !is.na(twelve_month)) |>
    pivot_longer(all_of(names(horizons)), names_to = "horizon", values_to = "rate") |>
    mutate(
      horizon = factor(horizons[horizon], levels = horizons),
      label = factor(str_wrap(label, label_width), levels = rev(str_wrap(unique(label), label_width)))
    )
  ggplot(table, aes(horizon, label, fill = rate)) +
    geom_tile(colour = "white", linewidth = 1.5) +
    geom_text(
      data = filter(table, published),
      aes(label = if_else(is.na(rate), "\u2013", sprintf("%.1f", rate))),
      size = text_size, family = "Roboto Chart", colour = chart_greys[["title"]]
    ) +
    # Centered across the four columns.
    geom_text(
      data = distinct(filter(table, !published), label),
      aes(x = 2.5, y = label, label = "Not yet published"),
      inherit.aes = FALSE, size = text_size, family = "Roboto Chart", colour = chart_greys[["muted"]]
    ) +
    scale_fill_chart_diverging(midpoint = 2) +
    scale_x_discrete(
      position = "top",
      labels = if (show_headers) \(x) str_wrap(x, header_width) else NULL
    ) +
    scale_y_discrete(expand = expansion(0)) +
    labs(title = title) +
    theme_chart() +
    theme(
      panel.grid.major.y = element_blank(),
      axis.text.x = element_text(colour = chart_greys[["text"]], lineheight = 0.9),
      axis.text.y = element_text(lineheight = 0.9)
    ) +
    panel_title_style
}

latest_panel <- function(label_width, header_width, text_size) {
  headline_and_core <- filter(latest, measure %in% c("headline", "core"))
  others <- latest |>
    filter(!measure %in% c("headline", "core")) |>
    mutate(label = factor(label, levels = measures$label)) |>
    arrange(label) |>
    mutate(label = as.character(label))
  rate_table(
    headline_and_core, label_width, header_width, text_size,
    title = str_glue("Annualized change, {month_label}"), show_headers = TRUE
  ) /
    rate_table(others, label_width, header_width, text_size, title = "Other underlying measures", show_headers = FALSE) +
    plot_layout(heights = c(2, nrow(others)))
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

save_chart(
  annotate_panels(
    (
      free(history_panel + guides(colour = guide_legend(order = 1), fill = guide_legend(order = 2))) /
        free(latest_panel(label_width = 36, header_width = 12, text_size = 3.8))
    ) +
      plot_layout(heights = c(1, 1.1)),
    width = 8
  ),
  file.path(chart_dir, "output", "inflation-measures.png"),
  width = 8,
  height = 8.8
)

save_chart(
  annotate_panels(
    (free(history_panel + stacked_legends) / free(latest_panel(label_width = 16, header_width = 6, text_size = 3))) +
      plot_layout(heights = c(1, 1.3)),
    width = 4.2
  ),
  file.path(chart_dir, "output", "inflation-measures-narrow.png"),
  width = 4.2,
  height = 10.2
)
