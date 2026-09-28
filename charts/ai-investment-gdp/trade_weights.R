# Compares weights on computer trade. The FEDS Note counts only the capital
# goods share of computer trade, using goods trade overall as the guide. Census
# product detail splits the trade into servers, storage, and parts, which go to
# business investment, and laptops and desktops, which are split between
# households and businesses.

library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(stringr)
library(lubridate)

source("R/fetch_census.R")
source("charts/ai-investment-gdp/contributions.R")

chart_dir <- "charts/ai-investment-gdp"

# All of HS 8471 (computers and their units) plus 8473.30 (their parts). These
# cover 86 to 96 percent of the Census end-use categories that match BEA's
# computer trade line.
computer_hs_codes <- c(
  "847130", "847141", "847149", "847150", "847160", "847170", "847180", "847190", "847330"
)
personal_computer_hs_codes <- c("847130", "847141", "847149")

census_trade <- c("imports", "exports") |>
  map(\(flow) fetch_census_trade(flow, computer_hs_codes, from = ymd("2021-10-01"))) |>
  list_rbind()

# The country detail is several megabytes a pull, so the committed snapshot
# keeps the partners that matter for round trips of servers and parts.
computer_trade <- census_trade |>
  mutate(partner = if_else(country %in% c("Mexico", "Taiwan"), country, "Other")) |>
  summarise(value = sum(value), .by = c(date, flow, hs_code, partner)) |>
  arrange(flow, hs_code, partner, date)

write_csv(computer_trade, file.path(chart_dir, "data", str_glue("census_trade_{today()}.csv")))

# Quarters are dated by their last month, as in the NIPA files. Seasonal
# patterns mostly cancel in a share, so unadjusted data are fine here.
personal_computer_share <- computer_trade |>
  mutate(quarter = floor_date(date, "quarter") + months(2)) |>
  summarise(
    months = n_distinct(date),
    share = sum(value[hs_code %in% personal_computer_hs_codes]) / sum(value),
    .by = c(quarter, flow)
  ) |>
  filter(months == 3) |>
  select(date = quarter, flow, share) |>
  pivot_wider(names_from = flow, values_from = share, names_prefix = "personal_share_")

nipa <- list.files(file.path(chart_dir, "data"), "^bea_nipa_", full.names = TRUE) |>
  max() |>
  read_csv(show_col_types = FALSE)

# Servers, storage, other units, and parts count fully as capital goods.
# Laptops and desktops keep the FEDS weight, since households buy them too.
# Shares are lagged a quarter, like the FEDS weight.
product_weights <- capital_goods_weights(nipa) |>
  inner_join(personal_computer_share, by = "date") |>
  arrange(date) |>
  transmute(
    date,
    export_weight = 1 - lag(personal_share_exports) * (1 - export_weight),
    import_weight = 1 - lag(personal_share_imports) * (1 - import_weight)
  )

trade_weights <- list(
  "Capital goods share (FEDS Note)" = capital_goods_weights(nipa),
  # Isolates the effect of weighting exports more heavily than imports.
  "Capital goods share of imports, both sides" = capital_goods_weights(nipa) |>
    mutate(export_weight = import_weight),
  "Business share of domestic spending (BEA)" = domestic_use_weights(nipa),
  "Product mix (Census)" = product_weights,
  "No weight" = transmute(nipa, date, export_weight = 1, import_weight = 1)
)

contributions_by_weight <- trade_weights |>
  map(\(weights) ai_investment_contributions(nipa, weights)) |>
  list_rbind(names_to = "weight") |>
  inner_join(list_rbind(trade_weights, names_to = "weight"), by = c("weight", "date")) |>
  filter(date >= ymd("2022-03-01"), !is.na(net))

latest_quarter <- max(contributions_by_weight$date)

contributions_by_weight |>
  filter(date > latest_quarter - months(12)) |>
  summarise(
    export_weight = mean(export_weight),
    import_weight = mean(import_weight),
    gross = mean(gross),
    net = mean(net),
    .by = weight
  ) |>
  mutate(offset_share = 1 - net / gross) |>
  print(width = Inf)

contributions_by_weight |>
  select(date, weight, net) |>
  pivot_wider(names_from = weight, values_from = net) |>
  print(n = Inf, width = Inf)

# A weight is too high if the net computer imports it counts exceed business
# investment in computers, which would leave investment with no domestic
# content. The BEA weight passes by construction, since it is built from final
# sales.
trade_weights |>
  list_rbind(names_to = "weight") |>
  inner_join(nipa, by = "date") |>
  filter(date > latest_quarter - months(12), date <= latest_quarter) |>
  transmute(
    date,
    weight,
    counted_imports_to_investment = (import_weight * computer_imports_nominal -
      export_weight * computer_exports_nominal) / computers_nominal
  ) |>
  pivot_wider(names_from = weight, values_from = counted_imports_to_investment) |>
  print(width = Inf)
