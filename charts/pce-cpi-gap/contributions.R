# Contributions of items to monthly core inflation, in percentage points, for
# PCE and CPI. Each takes a wide table of price indexes (and, for PCE, nominal
# spending) with one column per item plus `core`.

# PCE: an item's share of core spending last month times its price change.
pce_contributions <- function(prices, spending, items) {
  prices |>
    arrange(date) |>
    transmute(date, across(all_of(items), \(price) {
      share <- spending[[cur_column()]] / spending$core
      100 * lag(share) * (price / lag(price) - 1)
    }))
}

# CPI: an item's December relative importance, updated by its price change
# relative to core since December, times its price change, which is how BLS
# aggregates. `weights` has one row per December (`year`) and item.
cpi_contributions <- function(prices, weights, items) {
  december <- prices |>
    filter(month(date) == 12) |>
    mutate(year = year(date) + 1L) |>
    select(-date)
  weight_ratio <- weights |>
    pivot_wider(names_from = item, values_from = weight) |>
    mutate(across(all_of(items), \(weight) weight / core), year = year + 1L)

  prices |>
    arrange(date) |>
    mutate(year = year(date)) |>
    transmute(date, across(all_of(items), \(price) {
      item <- cur_column()
      base <- december[[item]][match(year, december$year)]
      core_base <- december$core[match(year, december$year)]
      ratio <- weight_ratio[[item]][match(year, weight_ratio$year)]
      100 * ratio * (lag(price) / base) / (lag(core) / core_base) * (price / lag(price) - 1)
    }))
}

# The October 2025 government shutdown left CPI without an October index for
# all items and without a November index for some. Missing months are filled
# log-linearly, which spreads the change over the gap evenly.
fill_missing_months <- function(prices) {
  tibble(date = seq(min(prices$date), max(prices$date), by = "month")) |>
    left_join(prices, by = "date") |>
    mutate(across(-date, \(index) exp(approx(date, log(index), xout = date)$y)))
}

twelve_month_sum <- \(x) slider::slide_dbl(x, sum, .before = 11, .complete = TRUE)
