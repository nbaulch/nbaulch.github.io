library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)
library(ggplot2)

source("R/chart_style.R")

chart_dir <- "charts/inflation-1970s"

# The shift used by the version of this chart in circulation. It sets June 2022
# on November 1974.
shift_months <- 571
plot_start <- ymd("2015-01-01")
plot_end <- ymd("2030-12-01")

cpi <- tidyusmacro::getFRED(cpi = "CPIAUCSL")

# FRED's download carries no release date, so the snapshot is named by the last
# month it covers.
latest_month <- max(cpi$date)
write_csv(cpi, file.path(chart_dir, "data", str_glue("fred_cpi_{latest_month}.csv")))

inflation <- cpi |>
  arrange(date) |>
  transmute(date, inflation = 100 * (cpi / lag(cpi, 12) - 1)) |>
  filter(!is.na(inflation))

# Each date carries inflation then and inflation shift_months earlier, so the
# 1970s line runs past today into the chart's future dates.
comparison <- tibble(date = seq(min(inflation$date), plot_end, by = "month")) |>
  left_join(inflation, by = "date") |>
  left_join(
    transmute(inflation, date = date %m+% months(shift_months), shifted = inflation),
    by = "date"
  )

comparison |>
  filter(!is.na(inflation) | !is.na(shifted)) |>
  mutate(across(-date, \(x) round(x, 3))) |>
  rename(inflation_571_months_earlier = shifted) |>
  write_csv(file.path(chart_dir, "output", "inflation-1970s.csv"), na = "")

month_label <- format(latest_month, "%B %Y")
seventies_start <- plot_start %m-% months(shift_months)
seventies_end <- plot_end %m-% months(shift_months)

write_chart_notes(
  notes = c(
    str_glue("**Today:** The 12-month change in the consumer price index, from {format(plot_start, '%B %Y')}."),
    str_glue(
      "**1970s:** The same, from {format(seventies_start, '%B %Y')} to {format(seventies_end, '%B %Y')}, ",
      "shifted forward {shift_months} months, or 47 years and 7 months. The top axis gives its years."
    )
  ),
  source = str_glue(
    "Source: Bureau of Labor Statistics, consumer price index for all urban consumers, seasonally adjusted, from ",
    "FRED, through {month_label}."
  ),
  csv_path = file.path(chart_dir, "output", "inflation-1970s.csv"),
  path = file.path(chart_dir, "output", "inflation-1970s-notes.md")
)

plotted <- comparison |>
  filter(between(date, plot_start, plot_end)) |>
  pivot_longer(c(inflation, shifted), names_to = "period", values_to = "rate") |>
  filter(!is.na(rate))

# The top axis labels the 1970s line with its own years, at the dates where
# they fall once shifted.
inflation_chart <- function(break_years) {
  today_breaks <- seq(plot_start, plot_end, by = str_glue("{break_years} years"))
  seventies_breaks <- seq(ceiling_date(seventies_start, "year"), seventies_end, by = str_glue("{break_years} years"))

  ggplot(plotted, aes(date, rate, colour = period)) +
    geom_hline(yintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
    geom_line(linewidth = 0.9) +
    scale_colour_manual(
      values = c(inflation = chart_colors[["blue"]], shifted = chart_colors[["orange"]]),
      labels = c(inflation = "Today", shifted = "1970s"),
      breaks = c("inflation", "shifted")
    ) +
    scale_x_date(
      breaks = today_breaks,
      date_labels = "%Y",
      expand = expansion(mult = 0.01),
      sec.axis = dup_axis(
        breaks = seventies_breaks %m+% months(shift_months),
        labels = year(seventies_breaks)
      )
    ) +
    scale_y_continuous(breaks = scales::breaks_width(2)) +
    theme_chart() +
    theme(
      axis.text.x.bottom = element_text(colour = chart_colors[["blue"]]),
      axis.text.x.top = element_text(colour = chart_colors[["orange"]], margin = margin(b = 4))
    )
}

title <- "Consumer price inflation today and in the 1970s"
subtitle <- str_glue("12-month change, percent; 1970s shifted forward {shift_months} months")
source_line <- "Source: Bureau of Labor Statistics."

save_chart(
  inflation_chart(break_years = 2) + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "inflation-1970s.png"),
  width = 8,
  height = 5
)

save_chart(
  inflation_chart(break_years = 4) + chart_labels(title, subtitle, source_line, width = 4.2),
  file.path(chart_dir, "output", "inflation-1970s-narrow.png"),
  width = 4.2,
  height = 5.5
)
