# Checks our contributions against Figure 7 of Soto, Thieu, and Allen, "The AI
# Buildout and the Economy," FEDS Notes, July 17, 2026, using the figure data
# the Federal Reserve Board published with the note.

library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(lubridate)

source("charts/ai-investment-gdp/contributions.R")

nipa_path <- "charts/ai-investment-gdp/data/bea_nipa_2026-09-26.csv"
published_path <- "charts/ai-investment-gdp/data/feds_ai_buildout_figure_data.xlsx"

published <- read_excel(published_path, sheet = "Figure_7", skip = 2) |>
  filter(!is.na(`Capex - software`)) |>
  transmute(
    date = yq(Period) + months(2),
    software = as.numeric(`Capex - software`),
    data_centers = as.numeric(`Capex - data centers`),
    power = as.numeric(`Capex - power facilities`),
    computers = as.numeric(`Capex - computer and peripheral equipment`),
    computer_net_exports = as.numeric(`Net exports - computer, peripherals, and parts`)
  ) |>
  pivot_longer(-date, names_to = "series", values_to = "published")

comparison <- read_csv(nipa_path, show_col_types = FALSE) |>
  ai_investment_contributions() |>
  select(date, software, data_centers, power, computers, computer_net_exports) |>
  pivot_longer(-date, names_to = "series", values_to = "ours") |>
  inner_join(published, by = c("date", "series")) |>
  mutate(difference = round(ours, 2) - published)

comparison |>
  summarise(
    quarters = n(),
    max_abs_difference = max(abs(difference)),
    .by = series
  ) |>
  print()
