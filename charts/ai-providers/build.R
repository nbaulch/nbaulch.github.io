library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)

source("R/chart_style.R")

chart_dir <- "charts/ai-providers"

paying_for_ai <- tidyusmacro::getFRED(
  any_provider = "RAMPAIALL",
  openai = "RAMPAIOPENAI",
  anthropic = "RAMPAIANTHROPIC",
  xai = "RAMPAIXAI"
) |>
  select(date, any_provider, openai, anthropic, xai) |>
  filter(!is.na(any_provider))

# FRED doesn't date Ramp's releases in the download, so the snapshot is named
# by the last month of data.
latest_month <- max(paying_for_ai$date)
write_csv(paying_for_ai, file.path(chart_dir, "data", str_glue("fred_ramp_ai_{latest_month}.csv")))

paying_for_ai |>
  mutate(across(-date, \(x) round(x, 3))) |>
  rename_with(\(x) str_c("businesses_paying_", x), -date) |>
  write_csv(file.path(chart_dir, "output", "ai-providers.csv"))

providers <- tribble(
  ~provider, ~label, ~colour,
  "any_provider", "Any provider", chart_colors[["blue"]],
  "openai", "OpenAI", chart_colors[["teal"]],
  "anthropic", "Anthropic", chart_colors[["orange"]],
  "xai", "xAI", chart_colors[["grey"]]
)

write_chart_notes(
  notes = c(
    "**Any provider:** The business paid for an AI product or service during the month, by card, invoice, or bank transfer through Ramp.",
    "**OpenAI, Anthropic, xAI:** The business paid that company during the month."
  ),
  source = str_glue(
    "Source: Ramp, [Ramp AI Index](https://ramp.com/data/ai-index), via ",
    "[FRED](https://fred.stlouisfed.org/series/RAMPAIALL), through {format(latest_month, '%B %Y')}."
  ),
  csv_path = file.path(chart_dir, "output", "ai-providers.csv"),
  path = file.path(chart_dir, "output", "ai-providers-notes.md")
)

providers_chart <- paying_for_ai |>
  pivot_longer(-date, names_to = "provider", values_to = "share") |>
  mutate(provider = factor(provider, levels = providers$provider)) |>
  ggplot(aes(date, share, colour = provider)) +
  geom_line(linewidth = 0.9) +
  scale_colour_manual(
    values = setNames(providers$colour, providers$provider),
    labels = setNames(providers$label, providers$provider)
  ) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(
    limits = c(0, 10 * ceiling(max(paying_for_ai$any_provider) / 10)),
    breaks = scales::breaks_width(10),
    expand = expansion(mult = c(0, 0.02))
  ) +
  theme_chart()

title <- "Share of businesses paying for AI, by provider"
subtitle <- "Businesses that use Ramp for payments, monthly, percent"
source_line <- "Source: Ramp AI Index, via FRED."

save_chart(
  providers_chart + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "ai-providers.png"),
  width = 8,
  height = 5
)

save_chart(
  providers_chart +
    chart_labels(title, subtitle, source_line, width = 4.2) +
    guides(colour = guide_legend(nrow = 2, byrow = TRUE)),
  file.path(chart_dir, "output", "ai-providers-narrow.png"),
  width = 4.2,
  height = 6.4
)
