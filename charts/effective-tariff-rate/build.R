library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)
library(ggplot2)
library(purrr)

source("R/fetch_census.R")
source("R/chart_style.R")

chart_dir <- "charts/effective-tariff-rate"
base_year <- 2024

imports <- read_census_trade("imports", from = ymd("2017-01-01"))

# Rate provisions split a product's imports from one country by tariff
# treatment; the rate here covers them together. Products are 6-digit codes,
# which change only every five years, where 10-digit codes change each January
# and would drop a tenth of 2024 imports out of the mix by 2026.
imports_by_source <- imports |>
  mutate(product = substr(commodity, 1, 6)) |>
  summarise(across(c(con_val, cal_dut), sum), .by = c(date, product, country_code))

base_mix <- imports_by_source |>
  filter(year(date) == base_year) |>
  summarise(base_value = sum(con_val), .by = c(product, country_code)) |>
  compute()

# Holding each product and country at its share of base-year imports. A
# product and country with no imports in a month drops out that month, and the
# rest are reweighted; the coverage column records how much of the base-year
# value is left.
at_base_mix <- imports_by_source |>
  filter(date >= make_date(base_year), con_val > 0) |>
  inner_join(base_mix, by = c("product", "country_code")) |>
  mutate(base_duty = base_value * cal_dut / con_val) |>
  summarise(base_duty = sum(base_duty), base_value = sum(base_value), .by = date) |>
  collect() |>
  transmute(
    date,
    at_base_mix = 100 * base_duty / base_value,
    base_mix_coverage = base_value / sum(collect(base_mix)$base_value)
  )

totals_by_country <- imports |>
  summarise(across(c(con_val, gen_val, cal_dut), sum), .by = c(date, country_code)) |>
  collect() |>
  arrange(date, country_code)

latest_month <- max(totals_by_country$date)
write_csv(totals_by_country, file.path(chart_dir, "data", str_glue("census_imports_by_country_{latest_month}.csv")))

# Duty is assessed on imports for consumption. General imports, which the
# Federal Reserve Board note uses, count goods entering bonded warehouses before
# they pay duty, so for one product and country in a month they can be near
# zero while duty on earlier arrivals is large.
tariff_rates <- totals_by_country |>
  summarise(across(c(con_val, cal_dut), sum), .by = date) |>
  transmute(date, collected = 100 * cal_dut / con_val) |>
  left_join(at_base_mix, by = "date") |>
  arrange(date)

tariff_rates |>
  mutate(across(-date, \(x) round(x, 3))) |>
  write_csv(file.path(chart_dir, "output", "effective-tariff-rate.csv"))

series_labels <- c(
  collected = "Actual imports",
  at_base_mix = str_glue("{base_year} mix of imports")
)
month_label <- format(latest_month, "%B %Y")

write_chart_notes(
  notes = c(
    str_glue(
      "**{series_labels[['collected']]}:** Duties calculated on goods entering the United States for consumption, ",
      "as a percent of their customs value."
    ),
    str_glue(
      "**{series_labels[['at_base_mix']]}:** The same rate with each product and source country weighted by its ",
      "share of imports in {base_year}, at the rate its imports paid that month."
    )
  ),
  source = str_glue(
    "Source: Census Bureau, U.S. imports of merchandise by product and country, through {month_label}. The ",
    "collected rate follows Sydney Eck, Trang Hoang, Carter Mix, and Madeleine Ray, [\"Mind the Gap: Announced ",
    "versus Implied Tariff Rates in Recent Trade Policy Episodes\"](https://www.federalreserve.gov/econres/notes/",
    "feds-notes/mind-the-gap-announced-versus-implied-tariff-rates-in-recent-trade-policy-episodes-20260408.html), ",
    "FEDS Notes, April 2026."
  ),
  csv_path = file.path(chart_dir, "output", "effective-tariff-rate.csv"),
  path = file.path(chart_dir, "output", "effective-tariff-rate-notes.md")
)

tariff_chart <- tariff_rates |>
  select(date, all_of(names(series_labels))) |>
  pivot_longer(-date, names_to = "series", values_to = "rate", values_drop_na = TRUE) |>
  mutate(series = factor(series_labels[series], levels = series_labels)) |>
  ggplot(aes(date, rate, colour = series)) +
  geom_line(linewidth = 0.9) +
  scale_colour_manual(values = unname(chart_colors[c("blue", "orange")])) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  scale_y_continuous(
    limits = c(0, 5 * ceiling(max(tariff_rates$at_base_mix, tariff_rates$collected, na.rm = TRUE) / 5)),
    breaks = scales::breaks_width(5),
    expand = expansion(mult = c(0, 0.02))
  ) +
  theme_chart()

title <- "Effective tariff rate on U.S. imports"
subtitle <- "Duties as a percent of the value of imports, monthly"
source_line <- "Source: Census Bureau. Collected rate follows Eck, Hoang, Mix, and Ray, Federal Reserve Board."

save_chart(
  tariff_chart + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "effective-tariff-rate.png"),
  width = 8,
  height = 5
)

save_chart(
  tariff_chart +
    chart_labels(title, subtitle, source_line, width = 4.2) +
    guides(colour = guide_legend(ncol = 1)),
  file.path(chart_dir, "output", "effective-tariff-rate-narrow.png"),
  width = 4.2,
  height = 5.5
)
