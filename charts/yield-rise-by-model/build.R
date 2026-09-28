library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(stringr)
library(lubridate)
library(ggplot2)

source("R/fetch_frb.R")
source("R/fetch_nyfed.R")
source("R/chart_style.R")

chart_dir <- "charts/yield-rise-by-model"

# This year's rise, measured from the week of the February low. The Fed Board
# model is updated monthly, so both models stop at its last day. Its four parts
# are combined into the two the New York Fed model has.
base_week <- ymd("2026-02-23")

board <- fetch_frb_dkw() |>
  filter(!is.na(nominal_yield_fitted_10)) |>
  transmute(
    date,
    yield = nominal_yield_fitted_10,
    expected_rates = exp_real_short_rate_10 + exp_inflation_10,
    term_premium = real_term_prem_10 + inflation_risk_prem_10
  )

new_york <- fetch_nyfed_acm() |>
  transmute(date, yield = acmy10, expected_rates = acmrny10, term_premium = acmtp10)

end_date <- max(board$date)

models <- bind_rows(board = board, new_york = new_york, .id = "model") |>
  filter(date >= base_week, date <= end_date)

# Neither source dates its releases, so the snapshot is named by the last day used.
write_csv(models, file.path(chart_dir, "data", str_glue("frb_dkw_nyfed_acm_10_year_{end_date}.csv")))

weekly_changes <- models |>
  mutate(date = floor_date(date, "week", week_start = 1)) |>
  summarise(across(c(yield, expected_rates, term_premium), mean), .by = c(model, date)) |>
  mutate(across(c(yield, expected_rates, term_premium), \(x) x - x[date == base_week]), .by = model)

weekly_changes |>
  pivot_wider(names_from = model, values_from = c(yield, expected_rates, term_premium), names_glue = "{model}_{.value}") |>
  select(week_starting = date, starts_with("board"), starts_with("new_york")) |>
  mutate(across(-week_starting, \(x) round(x, 3))) |>
  write_csv(file.path(chart_dir, "output", "yield-rise-by-model.csv"))

model_names <- c(board = "Fed Board model", new_york = "New York Fed model")
parts <- tribble(
  ~part, ~label, ~colour,
  "term_premium", "Term premium", chart_colors[["orange"]],
  "expected_rates", "Expected short-term rates", chart_colors[["blue"]]
)

write_chart_notes(
  notes = c(
    "**Expected short-term rates:** The average short-term interest rate investors expect over 10 years.",
    "**Term premium:** The extra return investors require to hold a 10-year bond instead of rolling over short-term bills.",
    "**Fed Board and New York Fed models:** D'Amico, Kim, and Wei; and Adrian, Crump, and Moench. Each splits its own estimate of the 10-year yield."
  ),
  source = str_glue(
    "Sources: Federal Reserve Board, D'Amico, Kim, and Wei model, ",
    "[\"Tips from TIPS: Update and Discussions\"]",
    "(https://www.federalreserve.gov/econres/notes/feds-notes/tips-from-tips-update-and-discussions-20190521.html), ",
    "FEDS Notes; Federal Reserve Bank of New York, [term premia]",
    "(https://www.newyorkfed.org/research/data_indicators/term-premia-tabs). Through {format(end_date, '%B %-d, %Y')}."
  ),
  csv_path = file.path(chart_dir, "output", "yield-rise-by-model.csv"),
  path = file.path(chart_dir, "output", "yield-rise-by-model-notes.md")
)

panels <- weekly_changes |>
  mutate(model = factor(model_names[model], levels = model_names))

bars <- panels |>
  pivot_longer(c(expected_rates, term_premium), names_to = "part", values_to = "change") |>
  mutate(part = factor(part, levels = parts$part))

yield_rise_chart <- ggplot(bars, aes(date, change)) +
  geom_col(aes(fill = part), width = 5.5, colour = "white", linewidth = 0.2) +
  geom_hline(yintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
  geom_line(data = panels, aes(y = yield, linetype = "10-year yield"), colour = chart_greys[["title"]], linewidth = 0.8) +
  facet_wrap(vars(model)) +
  scale_fill_manual(
    values = setNames(parts$colour, parts$part),
    labels = setNames(parts$label, parts$part),
    breaks = rev(parts$part)
  ) +
  scale_linetype_manual(values = "solid") +
  scale_x_date(date_breaks = "2 months", date_labels = "%b", expand = expansion(mult = c(0.02, 0.04))) +
  scale_y_continuous(breaks = scales::breaks_width(0.2)) +
  guides(fill = guide_legend(order = 1), linetype = guide_legend(order = 2)) +
  theme_chart() +
  theme(
    strip.text = element_text(hjust = 0, size = rel(0.95), colour = chart_greys[["text"]]),
    panel.spacing = unit(1.4, "lines")
  )

title <- "Change in the 10-year Treasury yield and its parts since February 2026, in two models"
subtitle <- "Measured from the week of February 23, weekly average, percentage points"
source_line <- "Sources: Federal Reserve Board (D'Amico, Kim, and Wei); Federal Reserve Bank of New York (Adrian, Crump, and Moench)."

save_chart(
  yield_rise_chart + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "yield-rise-by-model.png"),
  width = 8,
  height = 5
)

save_chart(
  yield_rise_chart +
    chart_labels(title, subtitle, source_line, width = 4.2) +
    facet_wrap(vars(model), ncol = 1) +
    guides(fill = guide_legend(ncol = 1, order = 1)) +
    theme(legend.box = "vertical", legend.spacing.y = unit(2, "pt")),
  file.path(chart_dir, "output", "yield-rise-by-model-narrow.png"),
  width = 4.2,
  height = 8
)
