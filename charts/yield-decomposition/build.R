library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)
library(ggplot2)

source("R/fetch_frb.R")
source("R/chart_style.R")

chart_dir <- "charts/yield-decomposition"

# The model splits the fitted 10-year zero-coupon yield into four parts that add
# up to it. The TIPS liquidity premium belongs to inflation compensation, not
# the nominal yield, so it is left out.
dkw <- fetch_frb_dkw() |>
  transmute(
    date,
    yield = nominal_yield_fitted_10,
    real_rate = exp_real_short_rate_10,
    real_term_premium = real_term_prem_10,
    expected_inflation = exp_inflation_10,
    inflation_risk_premium = inflation_risk_prem_10
  ) |>
  filter(!is.na(yield))

# The file carries no release date, so the snapshot is named by its last day.
write_csv(
  filter(dkw, year(date) >= 2015),
  file.path(chart_dir, "data", str_glue("frb_dkw_10_year_{max(dkw$date)}.csv"))
)

# Daily estimates are noisy, so the chart uses monthly averages, measured from
# December 2023.
base_month <- ymd("2023-12-01")

monthly <- dkw |>
  mutate(date = floor_date(date, "month")) |>
  summarise(across(everything(), mean), .by = date)

changes <- monthly |>
  filter(date >= base_month) |>
  mutate(across(-date, \(x) x - x[date == base_month]))

monthly |>
  left_join(changes, by = "date", suffix = c("", "_change_since_december_2023")) |>
  mutate(across(-date, \(x) round(x, 3))) |>
  write_csv(file.path(chart_dir, "output", "yield-decomposition.csv"), na = "")

parts <- tribble(
  ~part, ~label, ~colour, ~definition,
  "real_rate", "Expected real short-term rates", chart_colors[["blue"]],
  "The average short-term interest rate, net of inflation, that investors expect over 10 years.",
  "real_term_premium", "Real term premium", chart_colors[["orange"]],
  "The extra return investors require for the risk that real interest rates change while they hold the bond.",
  "expected_inflation", "Expected inflation", chart_colors[["teal"]],
  "Average inflation investors expect over 10 years.",
  "inflation_risk_premium", "Inflation risk premium", chart_colors[["red"]],
  "The extra return investors require for the risk that inflation turns out different from what they expect. With the real term premium, it makes up the term premium."
)

write_chart_notes(
  notes = c(
    str_glue("**{parts$label}:** {parts$definition}"),
    "**10-year yield:** The model's estimate of the yield on a 10-year Treasury that pays no coupons."
  ),
  source = str_glue(
    "Source: Federal Reserve Board, D'Amico, Kim, and Wei model, ",
    "[\"Tips from TIPS: Update and Discussions\"]",
    "(https://www.federalreserve.gov/econres/notes/feds-notes/tips-from-tips-update-and-discussions-20190521.html), ",
    "FEDS Notes, updated through {format(max(dkw$date), '%B %-d, %Y')}."
  ),
  csv_path = file.path(chart_dir, "output", "yield-decomposition.csv"),
  path = file.path(chart_dir, "output", "yield-decomposition-notes.md")
)

bars <- changes |>
  select(date, all_of(parts$part)) |>
  pivot_longer(-date, names_to = "part", values_to = "change") |>
  mutate(part = factor(part, levels = parts$part))

term_premium_chart <- ggplot(bars, aes(date, change)) +
  geom_col(aes(fill = part), width = 23, colour = "white", linewidth = 0.2) +
  geom_hline(yintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
  geom_line(data = changes, aes(y = yield, linetype = "10-year yield"), colour = chart_greys[["title"]], linewidth = 0.8) +
  scale_fill_manual(values = setNames(parts$colour, parts$part), labels = setNames(parts$label, parts$part)) +
  scale_linetype_manual(values = "solid") +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(breaks = scales::breaks_width(0.2)) +
  guides(fill = guide_legend(order = 1, nrow = 2), linetype = guide_legend(order = 2)) +
  theme_chart()

title <- "Change in the 10-year Treasury yield and its parts since December 2023"
subtitle <- "Fed Board model, monthly average, percentage points"
source_line <- "Source: Federal Reserve Board (D'Amico, Kim, and Wei model)."

save_chart(
  term_premium_chart + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "yield-decomposition.png"),
  width = 8,
  height = 5
)

save_chart(
  term_premium_chart +
    chart_labels(title, subtitle, source_line, width = 4.2) +
    guides(fill = guide_legend(ncol = 1, order = 1)) +
    theme(legend.box = "vertical", legend.spacing.y = unit(2, "pt")),
  file.path(chart_dir, "output", "yield-decomposition-narrow.png"),
  width = 4.2,
  height = 7.2
)
