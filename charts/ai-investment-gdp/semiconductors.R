# Looks at semiconductor trade, which the FEDS Note leaves out of the import
# offset. BEA's semiconductor line follows Census end-use category 21320, which
# includes solid-state storage drives as well as chips.

library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(stringr)
library(lubridate)

source("R/fetch_census.R")
source("charts/ai-investment-gdp/contributions.R")

chart_dir <- "charts/ai-investment-gdp"

# HS 8541 (discrete semiconductors), 8542 (integrated circuits), and 8523.51
# (solid-state storage). Together they cover about nine tenths of end-use
# 21320 imports.
semiconductor_hs_codes <- c(
  "854110", "854121", "854129", "854130", "854141", "854142", "854143", "854149",
  "854151", "854159", "854160", "854190",
  "854231", "854232", "854233", "854239", "854290",
  "852351"
)

semiconductor_trade <- c("imports", "exports") |>
  map(\(flow) fetch_census_trade(flow, semiconductor_hs_codes, from = ymd("2024-01-01"))) |>
  list_rbind() |>
  summarise(value = sum(value), .by = c(date, flow, hs_code)) |>
  arrange(flow, hs_code, date)

write_csv(semiconductor_trade, file.path(chart_dir, "data", str_glue("census_semiconductor_trade_{today()}.csv")))

nipa <- list.files(file.path(chart_dir, "data"), "^bea_nipa_", full.names = TRUE) |>
  max() |>
  read_csv(show_col_types = FALSE)

# Annual rates in billions of dollars, by product, for complete quarters,
# alongside BEA's seasonally adjusted totals.
semiconductor_trade |>
  mutate(
    quarter = floor_date(date, "quarter") + months(2),
    product = case_when(
      hs_code == "854231" ~ "processors",
      hs_code == "854232" ~ "memory",
      hs_code == "852351" ~ "solid_state_storage",
      .default = "other_chips"
    )
  ) |>
  summarise(months = n_distinct(date), value = sum(value) * 4 / 1e9, .by = c(quarter, flow, product)) |>
  filter(months == 3) |>
  select(date = quarter, flow, product, value) |>
  pivot_wider(names_from = product, values_from = value) |>
  left_join(
    nipa |>
      transmute(date, imports = semiconductor_imports_nominal / 1e3, exports = semiconductor_exports_nominal / 1e3) |>
      pivot_longer(-date, names_to = "flow", values_to = "bea_total"),
    by = c("date", "flow")
  ) |>
  arrange(flow, date) |>
  print(n = Inf, width = Inf)

# Net semiconductor trade, scaled by the same weights as computer trade or not
# at all, added to the chart's net total.
semiconductor_net_exports <- function(nipa, trade_weights) {
  nipa |>
    inner_join(trade_weights, by = "date") |>
    arrange(date) |>
    transmute(
      date,
      semiconductor_net_exports =
        gdp_contribution(semiconductor_exports_nominal, semiconductor_exports_real, gdp_nominal, gdp_real, export_weight) -
        gdp_contribution(semiconductor_imports_nominal, semiconductor_imports_real, gdp_nominal, gdp_real, import_weight)
    )
}

latest_quarter <- max(nipa$date)

list(
  "Capital goods share (FEDS weights)" = capital_goods_weights(nipa),
  "No weight" = transmute(nipa, date, export_weight = 1, import_weight = 1)
) |>
  map(\(weights) semiconductor_net_exports(nipa, weights)) |>
  list_rbind(names_to = "semiconductor_weight") |>
  inner_join(ai_investment_contributions(nipa), by = "date") |>
  filter(date > latest_quarter - months(12)) |>
  transmute(
    semiconductor_weight,
    date,
    gross,
    net,
    semiconductor_net_exports,
    net_of_semiconductors = net + semiconductor_net_exports
  ) |>
  mutate(
    offset_share = 1 - mean(net) / mean(gross),
    offset_share_with_semiconductors = 1 - mean(net_of_semiconductors) / mean(gross),
    .by = semiconductor_weight
  ) |>
  print(n = Inf, width = Inf)
