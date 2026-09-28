# Checks the software numbers in Barbarino, Diercks, and Miran, "Measurement of
# 'Computer Software and Accessories' Inflation," FEDS Notes, May 22, 2026, under
# their method: four-month annualized changes through March 2026, with software
# taken out of core and core goods PCE. Also checks BEA's electricity prices
# against the CPI's, which BEA uses to build them.

library(dplyr)
library(tidyr)
library(readr)
library(lubridate)

source("R/fetch_bea.R")
source("R/price_indexes.R")

pce <- fetch_bea_nipa(
  c(
    headline = "DPCERG", headline_spending = "DPCERC",
    core = "DPCCRG", core_spending = "DPCCRC",
    goods = "DGDSRG", goods_spending = "DGDSRC",
    food = "DFXARG", food_spending = "DFXARC",
    energy_goods = "DGOERG", energy_goods_spending = "DGOERC",
    software = "DCPSRG", software_spending = "DCPSRC",
    electricity = "DELCRG", electricity_spending = "DELCRC"
  ),
  frequency = "M"
)

four_month_change <- \(index) 100 * ((index / lag(index, 4))^3 - 1)
twelve_month_change <- \(index) 100 * (index / lag(index, 12) - 1)

rates <- pce |>
  arrange(date) |>
  mutate(
    goods_excluding_food = index_excluding(goods, goods_spending, food, food_spending),
    core_goods = index_excluding(
      goods_excluding_food, goods_spending - food_spending, energy_goods, energy_goods_spending
    ),
    core_goods_spending = goods_spending - food_spending - energy_goods_spending,
    core_excluding_software = index_excluding(core, core_spending, software, software_spending),
    core_goods_excluding_software = index_excluding(core_goods, core_goods_spending, software, software_spending)
  ) |>
  transmute(
    date,
    core = four_month_change(core),
    core_software = core - four_month_change(core_excluding_software),
    core_goods = four_month_change(core_goods),
    core_goods_software = core_goods - four_month_change(core_goods_excluding_software),
    software_share_of_core = 100 * software_spending / core_spending,
    software_share_of_core_goods = 100 * software_spending / core_goods_spending
  )

march <- filter(rates, date == ymd("2026-03-01"))
since_2000 <- rates |>
  filter(year(date) >= 2000, date <= ymd("2026-03-01")) |>
  summarise(across(-date, mean))

electricity <- pce |>
  select(date, electricity) |>
  inner_join(tidyusmacro::getFRED(cpi_electricity = "CUSR0000SEHF01"), by = "date") |>
  arrange(date) |>
  mutate(across(-date, twelve_month_change)) |>
  filter(year(date) >= 2015, !is.na(cpi_electricity))

tribble(
  ~check, ~published, ~ours,
  "Core PCE, 4 months annualized, March 2026", 4.4, march$core,
  "Software's contribution to core", 0.67, march$core_software,
  "Core goods PCE, 4 months annualized, March 2026", 5.5, march$core_goods,
  "Software's contribution to core goods", 2.8, march$core_goods_software,
  "Software, percent of core PCE", 1.2, march$software_share_of_core,
  "Software, percent of core goods PCE", 5.1, march$software_share_of_core_goods,
  "Core PCE, average since 2000 (read from Figure 1)", 2.2, since_2000$core,
  "Core goods PCE, average since 2000 (read from Figure 1)", 0.2, since_2000$core_goods
) |>
  mutate(ours = round(ours, 2), matches = abs(published - ours) < 0.15) |>
  print(width = Inf)

# The chart measures each item's contribution as its share of spending times
# its own 12-month price change. The FEDS method, taking the item out, gives
# its price change relative to everything else instead.
chart <- read_csv("charts/software-electricity-prices/output/software-electricity-prices.csv", show_col_types = FALSE)
method_difference <- pce |>
  arrange(date) |>
  transmute(
    date,
    software_taken_out = twelve_month_change(headline) -
      twelve_month_change(index_excluding(headline, headline_spending, software, software_spending)),
    electricity_taken_out = twelve_month_change(headline) -
      twelve_month_change(index_excluding(headline, headline_spending, electricity, electricity_spending))
  ) |>
  inner_join(chart, by = "date") |>
  filter(year(date) >= 2015)

cat("\nContributions to headline PCE, 12 months, July 2026, chart method and taken out:\n")
method_difference |>
  filter(date == max(date)) |>
  mutate(across(-date, \(x) round(x, 2))) |>
  print(width = Inf)

cat(
  "\nLargest difference between the two methods since 2015 (points): software",
  round(max(abs(method_difference$software - method_difference$software_taken_out)), 2),
  "electricity",
  round(max(abs(method_difference$electricity - method_difference$electricity_taken_out)), 2),
  "\nElectricity, 12-month change since 2015, largest gap between BEA and CPI (points):",
  round(max(abs(electricity$electricity - electricity$cpi_electricity)), 2),
  "\n"
)
