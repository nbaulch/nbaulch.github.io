# Checks the measures against the numbers others have published for July 2026:
# Konczal (August 28, 2026), Warsh's Jackson Hole remarks (August 28, 2026), and
# Omair Sharif's chart of market-based core excluding housing (September 16,
# 2026). Also checks that removing a component by solving BEA's Fisher formula
# reproduces a series BEA publishes.

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)

source("R/fetch_bea.R")
source("R/price_indexes.R")

chart_dir <- "charts/inflation-measures"

measures <- read_csv(file.path(chart_dir, "output", "inflation-measures.csv"), show_col_types = FALSE)
july <- filter(measures, date == ymd("2026-07-01"))

# Market-based core rebuilt from market-based PCE and its food and energy.
method_check <- fetch_bea_nipa(
  c(
    market = "DPCMRG", market_spending = "DPCMRC",
    food_energy = "DPMFRG", food_energy_spending = "DPMFRC",
    market_core = "DPCXRG"
  ),
  frequency = "M"
) |>
  arrange(date) |>
  mutate(
    rebuilt = index_excluding(market, market_spending, food_energy, food_energy_spending),
    gap = 100 * (rebuilt / lag(rebuilt, 12) - market_core / lag(market_core, 12))
  )

sharif <- measures |>
  select(date, value = market_core_excluding_housing_twelve_month) |>
  filter(!is.na(value))

tribble(
  ~check, ~published, ~ours,
  "Konczal: core PCE, 12 months to July", 3.34, july$core_twelve_month,
  "Konczal: market-based core PCE, 12 months to July", 3.03, july$market_core_twelve_month,
  "Warsh: headline PCE, 12 months", 3.7, july$headline_twelve_month,
  "Warsh: headline PCE, 6 months annualized", 4.1, july$headline_six_month,
  "Sharif: market-based core excluding housing, 1994 to 2025 average", 1.5, mean(sharif$value[year(sharif$date) %in% 1994:2025]),
  "Sharif: same, 2002 to 2007 average", 1.5, mean(sharif$value[year(sharif$date) %in% 2002:2007]),
  "Sharif: same, 2023 to 2025 low", 1.5, min(sharif$value[year(sharif$date) %in% 2023:2025]),
  "Sharif: same, latest", 3.23, july$market_core_excluding_housing_twelve_month,
  "Method: largest gap rebuilding market-based core (points)", 0, max(abs(method_check$gap), na.rm = TRUE)
) |>
  mutate(ours = round(ours, 2), matches = abs(published - ours) < 0.06) |>
  print(width = Inf)
