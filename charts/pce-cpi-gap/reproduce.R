# Checks the gap against Mike Konczal, "Is the Actual Inflation Rate PCE and
# High or CPI and Low?", August 28, 2026, for the 12 months to July 2026.

library(dplyr)
library(tidyr)
library(readr)
library(lubridate)

source("R/fetch_bea.R")

gap <- read_csv("charts/pce-cpi-gap/output/pce-cpi-gap.csv", show_col_types = FALSE)
july <- filter(gap, date == ymd("2026-07-01"))

software_weight <- fetch_bea_nipa(c(pce = "DPCERC", software = "DPCSRC"), frequency = "M") |>
  filter(date == ymd("2026-07-01")) |>
  summarise(100 * software / pce) |>
  pull()

tribble(
  ~check, ~published, ~ours,
  "Core PCE, 12 months", 3.34, july$core_pce,
  "Core CPI, 12 months", 2.47, july$core_cpi,
  "Gap, core PCE minus core CPI", 0.87, july$gap,
  "Average gap, 2011 to 2019, core CPI minus core PCE", 0.34, -mean(gap$gap[between(year(gap$date), 2011, 2019)]),
  "Portfolio management's part of the gap", 0.31, july$portfolio_management,
  "Software, percent of PCE spending", 1.10, software_weight
) |>
  mutate(ours = round(ours, 2), matches = abs(published - ours) < 0.06) |>
  print(width = Inf)
