# Checks BEA's price of computer imports against BLS import
# and producer prices, and compares computer trade's contribution when it is
# deflated with investment prices instead of import prices.

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)
library(purrr)

source("charts/ai-investment-gdp/contributions.R")

chart_dir <- "charts/ai-investment-gdp"

# BLS import price indexes by end use and producer price indexes, from FRED.
bls_prices <- tidyusmacro::getFRED(
  import_computers_and_parts = "IR213COM",
  import_parts = "IR21301",
  import_semiconductors = "IR21320",
  producer_computers = "PCU334111334111",
  producer_storage = "PCU334112334112"
) |>
  filter(date >= ymd("2023-01-01"))

# FRED doesn't date its vintages, so the snapshot is named by the fetch date.
write_csv(bls_prices, file.path(chart_dir, "data", str_glue("fred_bls_prices_{today()}.csv")))

annualized_growth <- \(x) 100 * ((x / lag(x))^4 - 1)

nipa <- list.files(file.path(chart_dir, "data"), "^bea_nipa_", full.names = TRUE) |>
  max() |>
  read_csv(show_col_types = FALSE)

bea_prices <- nipa |>
  transmute(
    date,
    bea_imports = computer_imports_nominal / computer_imports_real,
    bea_exports = computer_exports_nominal / computer_exports_real,
    bea_investment = computers_nominal / computers_real
  )

# Quarterly averages of complete quarters, dated by their last month. BLS
# published no import prices for October 2025, during the government shutdown,
# so that quarter averages November and December.
bls_prices |>
  mutate(date = floor_date(date, "quarter") + months(2)) |>
  filter(n() == 3, .by = date) |>
  summarise(across(everything(), \(x) mean(x, na.rm = TRUE)), .by = date) |>
  full_join(bea_prices, by = "date") |>
  arrange(date) |>
  mutate(across(-date, annualized_growth)) |>
  filter(date >= ymd("2025-03-01")) |>
  print(width = Inf)

latest_quarter <- max(nipa$date)

list(
  "Trade price (BEA)" = nipa,
  "Investment price" = deflate_trade_with_investment_price(nipa)
) |>
  map(ai_investment_contributions) |>
  list_rbind(names_to = "trade_deflator") |>
  filter(date > latest_quarter - months(12)) |>
  select(trade_deflator, date, computers, computer_net_exports, gross, net) |>
  mutate(offset_share = 1 - mean(net) / mean(gross), .by = trade_deflator) |>
  print(n = Inf, width = Inf)
