library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(stringr)
library(lubridate)
library(ggplot2)

source("R/fetch_bea.R")
source("R/fetch_bls.R")
source("R/chart_style.R")
source("charts/pce-cpi-gap/contributions.R")

chart_dir <- "charts/pce-cpi-gap"

# Each item in both indexes: PCE price and spending (NIPA tables 2.4.4U and
# 2.4.5U), the CPI-U index, and its name in BLS's relative importance tables.
# BLS publishes software only without seasonal adjustment, and BEA deflates
# PCE software with that index, so the CPI side uses the PCE price.
items <- tribble(
  ~item, ~pce_price, ~pce_spending, ~cpi_index, ~cpi_weight,
  "core", "DPCCRG", "DPCCRC", "CUSR0000SA0L1E", "All items less food and energy",
  "computers", "DIPERG", "DIPERC", "CUSR0000SEEE01",
  "Personal computers and peripheral equipment|Computers, peripherals, and smart home assistants?( devices)?",
  "software", "DCPSRG", "DCPSRC", NA, "Computer software and accessories",
  "insurance", "DTINRG", "DTINRC", "CUSR0000SETE", "Motor vehicle insurance",
  "medical", "DHLCRG", "DHLCRC", "CUSR0000SAM2", "Medical care services"
)
parts <- setdiff(items$item, "core")

pce <- fetch_bea_nipa(c(set_names(items$pce_price, items$item), set_names(items$pce_spending, str_c(items$item, "_spending"))), frequency = "M")
cpi <- fetch_bls_cpi(set_names(items$cpi_index, items$item) |> na.omit()) |>
  left_join(select(pce, date, software), by = "date")
weights <- fetch_bls_cpi_relative_importance(set_names(items$cpi_weight, items$item))

# None of the downloads carries a release date, so snapshots are named by the
# last month of PCE data, and the weights by the last December they cover.
latest_month <- max(pce$date)
write_csv(pce, file.path(chart_dir, "data", str_glue("bea_pce_{latest_month}.csv")))
write_csv(cpi, file.path(chart_dir, "data", str_glue("bls_cpi_{latest_month}.csv")))
write_csv(weights, file.path(chart_dir, "data", str_glue("bls_relative_importance_{max(weights$year)}.csv")))

pce_parts <- pce_contributions(
  select(pce, date, all_of(items$item)),
  select(pce, date, core = core_spending, all_of(str_c(parts, "_spending"))) |> rename_with(\(x) str_remove(x, "_spending$")),
  parts
)
cpi_parts <- cpi |>
  filter(date >= ymd("2009-12-01")) |>
  fill_missing_months() |>
  cpi_contributions(weights, parts)
cpi_core <- cpi |>
  filter(date >= ymd("2009-12-01")) |>
  fill_missing_months() |>
  select(date, core)

twelve_month_change <- \(index) 100 * (index / lag(index, 12) - 1)

# Each part of the gap is the item's contribution to core PCE inflation minus
# its contribution to core CPI inflation over 12 months. Other is the rest of
# the gap.
gap <- bind_rows(pce = pce_parts, cpi = cpi_parts, .id = "index") |>
  pivot_longer(all_of(parts), names_to = "part") |>
  pivot_wider(names_from = index) |>
  arrange(date) |>
  mutate(value = twelve_month_sum(pce - cpi), .by = part) |>
  select(date, part, value) |>
  pivot_wider(names_from = part) |>
  inner_join(
    inner_join(select(pce, date, pce = core), rename(cpi_core, cpi = core), by = "date") |>
      arrange(date) |>
      transmute(date, gap = twelve_month_change(pce) - twelve_month_change(cpi)),
    by = "date"
  ) |>
  transmute(date, gap, computers_and_software = computers + software, car_insurance = insurance, medical_services = medical,
    other = gap - computers_and_software - car_insurance - medical_services) |>
  filter(!is.na(gap), !is.na(computers_and_software))

before_pandemic <- gap |>
  filter(between(year(date), 2011, 2019)) |>
  summarise(across(-date, mean))
change <- gap |>
  mutate(across(-date, \(x) x - before_pandemic[[cur_column()]]))

change |>
  mutate(across(-date, \(x) round(x, 3))) |>
  write_csv(file.path(chart_dir, "output", "pce-cpi-gap.csv"))

pieces <- tribble(
  ~piece, ~label, ~colour, ~definition,
  "computers_and_software", "Computers and software", chart_colors[["teal"]],
  "Computers, peripherals, and software, which weigh more in PCE.",
  "car_insurance", "Car insurance", chart_colors[["orange"]],
  "Motor vehicle insurance, which weighs more in CPI.",
  "medical_services", "Medical services", chart_colors[["blue"]],
  "Health care services, including care paid for by employers and government, which only PCE covers.",
  "other", "Other", chart_colors[["grey"]],
  "Everything else in core, including housing, which weighs more in CPI."
)
month_label <- format(latest_month, "%B %Y")

write_chart_notes(
  notes = c(
    "**Gap:** The 12-month change in core PCE prices minus core CPI prices, both excluding food and energy.",
    str_glue("**{pieces$label}:** {pieces$definition}"),
    "**Change from the 2011–19 average:** Each series, and each item's contribution to core PCE minus its contribution to core CPI, less its average from 2011 to 2019."
  ),
  source = str_glue(
    "Sources: Bureau of Economic Analysis, through {month_label}; Bureau of Labor Statistics, with CPI weights from its ",
    "[relative importance tables](https://www.bls.gov/cpi/tables/relative-importance/home.htm)."
  ),
  csv_path = file.path(chart_dir, "output", "pce-cpi-gap.csv"),
  path = file.path(chart_dir, "output", "pce-cpi-gap-notes.md")
)

chart_start <- ymd("2015-01-01")
bars <- change |>
  filter(date >= chart_start) |>
  pivot_longer(all_of(pieces$piece), names_to = "piece") |>
  # The last level stacks next to zero, so gray goes first and sits outside.
  mutate(piece = factor(piece, levels = rev(pieces$piece)))

# Bars are 75 percent of a month wide, leaving a gap between them.
gap_chart <- function(break_years, legend_columns) {
  ggplot(bars, aes(date, value)) +
    geom_col(aes(fill = piece), width = 23, colour = "white", linewidth = 0.2) +
    geom_hline(yintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
    geom_line(data = filter(change, date >= chart_start), aes(date, gap, colour = "gap"), linewidth = 0.8) +
    scale_fill_manual(values = set_names(pieces$colour, pieces$piece), labels = set_names(pieces$label, pieces$piece), breaks = pieces$piece) +
    scale_colour_manual(values = c(gap = chart_greys[["title"]]), labels = c(gap = "Gap")) +
    scale_x_date(date_breaks = str_glue("{break_years} years"), date_labels = "%Y") +
    scale_y_continuous(breaks = scales::breaks_width(0.5)) +
    guides(colour = guide_legend(order = 1), fill = guide_legend(order = 2, ncol = legend_columns)) +
    theme_chart()
}

title <- "Gap between core PCE and core CPI inflation"
subtitle <- "Change from the 2011–19 average, 12 months, percentage points"
source_line <- "Sources: Bureau of Economic Analysis; Bureau of Labor Statistics."

save_chart(
  gap_chart(break_years = 2, legend_columns = 4) + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "pce-cpi-gap.png"),
  width = 8,
  height = 5.2
)

save_chart(
  gap_chart(break_years = 3, legend_columns = 2) + chart_labels(title, subtitle, source_line, width = 4.2),
  file.path(chart_dir, "output", "pce-cpi-gap-narrow.png"),
  width = 4.2,
  height = 6
)
