library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)
library(ggplot2)

source("R/fetch_bea.R")
source("R/chart_style.R")

chart_dir <- "charts/software-electricity-prices"

# Price indexes (G) and spending (C) from NIPA table 2.4.4U and 2.4.5U.
pce_series <- c(
  headline_spending = "DPCERC",
  software = "DCPSRG", software_spending = "DCPSRC",
  electricity = "DELCRG", electricity_spending = "DELCRC"
)

pce <- fetch_bea_nipa(pce_series, frequency = "M")

# The download doesn't carry a release date, so the snapshot is named by the
# last month of data.
latest_month <- max(pce$date)
write_csv(pce, file.path(chart_dir, "data", str_glue("bea_pce_{latest_month}.csv")))

# An item's contribution is its share of spending a year earlier times its
# 12-month price change: how much of PCE inflation comes from that item's
# price. Taking the item out instead measures its price change relative to
# everything else, which is near zero for an item rising at the average rate.
contribution <- \(price, spending, total_spending) {
  100 * lag(spending / total_spending, 12) * (price / lag(price, 12) - 1)
}

contributions <- pce |>
  arrange(date) |>
  transmute(
    date,
    software = contribution(software, software_spending, headline_spending),
    electricity = contribution(electricity, electricity_spending, headline_spending)
  ) |>
  filter(!is.na(software))

contributions |>
  mutate(across(-date, \(x) round(x, 3))) |>
  write_csv(file.path(chart_dir, "output", "software-electricity-prices.csv"))

month_label <- format(latest_month, "%B %Y")

write_chart_notes(
  notes = c(
    str_glue(
      "**Contribution:** An item's share of consumer spending a year earlier times the 12-month change in its price. ",
      "It is the part of the 12-month change in the PCE price index that comes from that item."
    ),
    str_glue(
      "**Computer software and accessories:** Software bought by households, of all kinds, not only AI. Despite the ",
      "name, BEA's category includes no physical accessories."
    ),
    "**Electricity:** Electricity bought by households. It excludes electricity bought by businesses, including data centers."
  ),
  source = str_glue(
    "Source: Bureau of Economic Analysis, through {month_label}. The software series follows Barbarino, Diercks, ",
    "and Miran, [\"Measurement of 'Computer Software and Accessories' Inflation\"]",
    "(https://www.federalreserve.gov/econres/notes/feds-notes/measurement-of-computer-software-and-accessories-inflation-20260522.html), ",
    "FEDS Notes, May 22, 2026, adapted to contributions to headline PCE over 12 months. Related: Kay, Kilian, and ",
    "Taylor, [\"Data center boom expected to raise electricity component of PCE inflation\"]",
    "(https://www.dallasfed.org/research/economics/2026/0305-kay-datacenters), Federal Reserve Bank of Dallas, ",
    "March 5, 2026."
  ),
  csv_path = file.path(chart_dir, "output", "software-electricity-prices.csv"),
  path = file.path(chart_dir, "output", "software-electricity-prices-notes.md")
)

lines <- contributions |>
  filter(date >= ymd("2015-01-01")) |>
  pivot_longer(-date, names_to = "item", values_to = "contribution") |>
  mutate(item = factor(item, levels = c("software", "electricity")))

contributions_chart <- ggplot(lines, aes(date, contribution, colour = item)) +
  geom_hline(yintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
  geom_line(linewidth = 0.9) +
  scale_colour_manual(
    values = c(software = chart_colors[["blue"]], electricity = chart_colors[["orange"]]),
    labels = c(software = "Computer software and accessories", electricity = "Electricity")
  ) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  scale_y_continuous(breaks = scales::breaks_width(0.1)) +
  theme_chart()

title <- "Contributions of software and electricity prices to PCE inflation"
subtitle <- "Contribution to the 12-month change in the PCE price index, percentage points"
source_line <- "Source: Bureau of Economic Analysis. Software adapted from Barbarino, Diercks, and Miran, May 2026."

save_chart(
  contributions_chart + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "software-electricity-prices.png"),
  width = 8,
  height = 5
)

save_chart(
  contributions_chart +
    chart_labels(title, subtitle, source_line, width = 4.2) +
    guides(colour = guide_legend(ncol = 1)),
  file.path(chart_dir, "output", "software-electricity-prices-narrow.png"),
  width = 4.2,
  height = 5.8
)
