# Checks the collected tariff rate against published figures. Run build.R
# first; this reads the totals by country it saves.

library(dplyr)
library(purrr)
library(readr)
library(stringr)
library(lubridate)

source("R/fetch_census.R")

chart_dir <- "charts/effective-tariff-rate"
china <- "5700"

totals_by_country <- list.files(file.path(chart_dir, "data"), "^census_imports_by_country_", full.names = TRUE) |>
  max() |>
  read_csv(col_types = cols(country_code = "c"))

# The chart divides by imports for consumption; the Federal Reserve Board note
# divides by general imports. Penn Wharton's figures match imports for
# consumption without chapters 98 and 99, which hold special classifications
# such as U.S. goods returned; the totals by country include everything, so
# that check reads the trade store.
without_special_chapters <- function(month) {
  read_census_trade("imports", month, month) |>
    filter(!substr(commodity, 1, 2) %in% c("98", "99")) |>
    summarise(across(c(con_val, gen_val, cal_dut), sum), .by = c(date, country_code)) |>
    collect()
}

collected_rate <- function(totals) {
  summarise(totals, consumption = 100 * sum(cal_dut) / sum(con_val), general = 100 * sum(cal_dut) / sum(gen_val))
}

rate_in <- function(months, countries = unique(totals_by_country$country_code)) {
  totals_by_country |>
    filter(date %in% months, country_code %in% countries) |>
    collected_rate()
}

months_of <- \(year) seq(make_date(year), make_date(year, 12), by = "month")

rise_from <- function(month, base_year) {
  rate_in(month) - rate_in(months_of(base_year))
}

bind_rows(
  "Fed Board: collected rate, December 2025 (14.7 announced less 5.43 gap)" =
    tibble(published = 14.7 - 5.43, rate_in(ymd("2025-12-01"))),
  "Fed Board: rise in collected rate, 2024 to December 2025 (12.37 less 5.43)" =
    tibble(published = 12.37 - 5.43, rise_from(ymd("2025-12-01"), 2024)),
  "Fed Board: rise in collected rate, 2017 to December 2018" =
    tibble(published = 1.49, rise_from(ymd("2018-12-01"), 2017)),
  "Penn Wharton: January 2025, without chapters 98 and 99" =
    tibble(published = 2.3, collected_rate(without_special_chapters(ymd("2025-01-01")))),
  "Penn Wharton: July 2026, same" =
    tibble(published = 6.7, collected_rate(without_special_chapters(ymd("2026-07-01")))),
  "Penn Wharton: China, July 2026, same" =
    tibble(published = 22.8, collected_rate(filter(without_special_chapters(ymd("2026-07-01")), country_code == china))),
  .id = "check"
) |>
  mutate(across(where(is.numeric), \(x) round(x, 2))) |>
  print(width = Inf)
