# Checks our decomposition against Tedeschi's published chart (Stripe Economics,
# July 23, 2026). His chart predates the September 2026 change to Fernald's
# labor composition series, so this swaps the earlier series back in. The
# release carries both, and the readme gives the adjustment to TFP.

library(dplyr)
library(tidyr)
library(readxl)
library(stringr)
library(lubridate)
library(slider)

source("R/fetch_sffed.R")
source("charts/productivity-decomposition/contributions.R")

tfp_path <- "charts/productivity-decomposition/data/sffed_tfp_2026-09-03.xlsx"

earlier_labor_composition <- read_excel(tfp_path, sheet = "labor composition", skip = 2) |>
  filter(str_detect(date, "^\\d{4}:Q\\d$")) |>
  transmute(date = yq(date), dLQ_earlier = as.numeric(dLC_through_2026.08))

# Read off the published chart by eye, so expect differences of about 0.1.
published <- tribble(
  ~date,        ~deepening, ~tfp_util_adjusted, ~utilization,
  "2022-01-01", -1.4,        0.9,               -0.1,
  "2023-10-01",  1.55,       2.65,              -0.95,
  "2025-10-01",  1.25,       0.3,                1.05,
  "2026-01-01",  1.0,        0.1,                1.4
) |>
  mutate(date = ymd(date)) |>
  pivot_longer(-date, names_to = "series", values_to = "published")

read_sffed_tfp(tfp_path) |>
  left_join(earlier_labor_composition, by = "date") |>
  mutate(
    dtfp_util = dtfp_util + (1 - alpha) * (dLQ - dLQ_earlier),
    dLQ = dLQ_earlier
  ) |>
  labor_productivity_contributions(read_sffed_capital(tfp_path)) |>
  inner_join(published, by = c("date", "series")) |>
  mutate(difference = four_quarter_mean - published) |>
  print(n = Inf)
