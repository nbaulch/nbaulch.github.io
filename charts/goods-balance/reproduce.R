# Checks the store's totals by category against Census's published end-use
# series, from its API. Run build.R first; this reads the totals it saves.
# Gold is left out: the chart adds gold bars that Census files under another
# end use, so its gold differs from Census's nonmonetary gold by design.

library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(stringr)
library(lubridate)

chart_dir <- "charts/goods-balance"
months <- ymd(c("2019-06-01", "2025-03-01", "2026-07-01"))

end_uses <- tribble(
  ~category, ~end_use,
  "computers", "21300",
  "computers", "21301",
  "chips_telecom", "21320",
  "chips_telecom", "21400",
  "pharmaceuticals", "40100",
  "total", "-"
)

fetch_census_end_use <- function(flow, month) {
  field <- if (flow == "imports") "I_ENDUSE" else "E_ENDUSE"
  value <- if (flow == "imports") "GEN_VAL_MO" else "ALL_VAL_MO"
  response <- httr::GET(
    str_glue("https://api.census.gov/data/timeseries/intltrade/{flow}/enduse"),
    query = list(get = str_glue("{value},{field}"), time = format(month, "%Y-%m"), CTY_CODE = "-", key = Sys.getenv("CENSUS_API_KEY"))
  )
  rows <- jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8"))
  tibble(flow, date = month, end_use = rows[-1, 2], published = as.numeric(rows[-1, 1]) / 1e9)
}

published <- expand_grid(flow = c("imports", "exports"), month = months) |>
  pmap(fetch_census_end_use) |>
  list_rbind() |>
  inner_join(end_uses, by = "end_use") |>
  summarise(published = sum(published), .by = c(flow, date, category))

ours <- list.files(file.path(chart_dir, "data"), "^census_trade_by_category_", full.names = TRUE) |>
  max() |>
  read_csv(show_col_types = FALSE) |>
  filter(date %in% months)

ours |>
  bind_rows(summarise(ours, value = sum(value), .by = c(date, flow)) |> mutate(category = "total")) |>
  rename(ours = value) |>
  inner_join(published, by = c("flow", "date", "category")) |>
  mutate(difference = ours - published, across(where(is.numeric), \(x) round(x, 2))) |>
  arrange(date, flow, category) |>
  print(n = Inf)
