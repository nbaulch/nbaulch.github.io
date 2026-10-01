# Checks the gap against Mike Konczal, "Is the Actual Inflation Rate PCE and
# High or CPI and Low?", August 28, 2026, and checks that the CPI weights
# rebuild core CPI. Konczal's July figures predate BEA's September 2026 annual
# update, so they are checked against the July snapshots.

library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(stringr)
library(lubridate)

source("R/fetch_bls.R")
source("charts/pce-cpi-gap/contributions.R")

chart_dir <- "charts/pce-cpi-gap"
twelve_month_change <- \(index) 100 * (index / lag(index, 12) - 1)

july_vintage <- read_csv(file.path(chart_dir, "data", "bea_pce_2026-07-01.csv"), show_col_types = FALSE) |>
  inner_join(read_csv(file.path(chart_dir, "data", "fred_core_cpi_2026-07-01.csv"), show_col_types = FALSE), by = "date") |>
  arrange(date) |>
  transmute(date, core_pce = twelve_month_change(core), core_cpi = twelve_month_change(core_cpi), gap = core_pce - core_cpi)
july <- filter(july_vintage, date == ymd("2026-07-01"))

latest_snapshot <- \(prefix) max(list.files(file.path(chart_dir, "data"), str_glue("^{prefix}_"), full.names = TRUE))
current <- read_csv(latest_snapshot("bea_pce"), show_col_types = FALSE) |>
  select(date, pce = core) |>
  inner_join(read_csv(latest_snapshot("bls_cpi"), show_col_types = FALSE) |> fill_missing_months() |> select(date, cpi = core), by = "date") |>
  arrange(date) |>
  mutate(gap = twelve_month_change(pce) - twelve_month_change(cpi))

# Core CPI is goods plus services less energy; their weighted contributions
# should add up to its monthly change. Seasonally adjusted series don't add up
# exactly, because BLS adjusts some aggregates directly.
groups <- c(core = "All items less food and energy", goods = "Commodities less food and energy commodities", services = "Services less energy services")
cpi_groups <- fetch_bls_cpi(c(core = "CUSR0000SA0L1E", goods = "CUSR0000SACL1E", services = "CUSR0000SASLE")) |>
  filter(date >= ymd("2009-12-01")) |>
  fill_missing_months()
aggregation_errors <- cpi_groups |>
  cpi_contributions(fetch_bls_cpi_relative_importance(groups), c("goods", "services")) |>
  inner_join(transmute(cpi_groups, date, core = 100 * (core / lag(core) - 1)), by = "date") |>
  filter(year(date) >= 2010, !is.na(goods)) |>
  summarise(mean = mean(abs(core - goods - services)), max = max(abs(core - goods - services)))

tribble(
  ~check, ~published, ~ours, ~tolerance,
  "Core PCE, 12 months to July, July vintage", 3.34, july$core_pce, 0.06,
  "Core CPI, 12 months to July", 2.47, july$core_cpi, 0.06,
  "Gap, core PCE minus core CPI, July vintage", 0.87, july$gap, 0.06,
  "Average gap, 2011 to 2019, core CPI minus core PCE, current vintage", 0.34, -mean(current$gap[between(year(current$date), 2011, 2019)]), 0.06,
  "Average monthly gap rebuilding core CPI from its weights (points)", 0, aggregation_errors$mean, 0.01,
  "Largest monthly gap rebuilding core CPI from its weights (points)", 0, aggregation_errors$max, 0.05
) |>
  mutate(ours = round(ours, 3), matches = abs(published - ours) <= tolerance) |>
  print(width = Inf)
