library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(stringr)
library(lubridate)
library(slider)
library(ggplot2)

source("R/fetch_sffed.R")
source("R/chart_style.R")
source("charts/productivity-decomposition/contributions.R")

chart_dir <- "charts/productivity-decomposition"

tfp_path <- fetch_sffed_tfp(file.path(chart_dir, "data"))
release_date <- read_sffed_release_date(tfp_path)

contributions <- labor_productivity_contributions(
  read_sffed_tfp(tfp_path),
  read_sffed_capital(tfp_path)
) |>
  filter(!is.na(four_quarter_mean))

# In stacking order, top to bottom, so the legend and notes read like the bars.
components <- tribble(
  ~series, ~label, ~colour, ~definition,
  "other_deepening", "Other capital and labor", chart_colors[["grey"]],
  "Other capital per hour worked, and workforce skills.",
  "it_capital_deepening", "Computers and software", chart_colors[["teal"]],
  "Computer and software capital per hour worked.",
  "tfp_util_adjusted", "Total factor productivity", chart_colors[["blue"]],
  "Output growth not explained by capital, labor, or utilization.",
  "utilization", "Utilization", chart_colors[["orange"]],
  "How intensively businesses use their existing workers and equipment."
)

# The public download: the plotted series, one row per quarter, full history.
download_columns <- c(
  labor_productivity_growth = "labor_productivity",
  other_capital_and_labor = "other_deepening",
  computers_and_software = "it_capital_deepening",
  total_factor_productivity = "tfp_util_adjusted",
  utilization = "utilization"
)

contributions |>
  pivot_wider(names_from = series, values_from = four_quarter_mean) |>
  select(date, all_of(download_columns)) |>
  mutate(across(-date, \(x) round(x, 3))) |>
  write_csv(file.path(chart_dir, "output", "productivity-decomposition.csv"))

write_chart_notes(
  notes = str_glue("**{components$label}:** {components$definition}"),
  source = str_glue(
    "Source: John Fernald, Federal Reserve Bank of San Francisco, [utilization-adjusted total factor ",
    "productivity](https://www.frbsf.org/research-and-insights/data-and-indicators/total-factor-productivity-tfp/), ",
    "{format(release_date, '%B %-d, %Y')}. Adapted from Tedeschi, ",
    "[\"AI and Productivity\"](https://www.stripeeconomics.com/p/ai-and-productivity), Stripe Economics, July 2026."
  ),
  csv_path = file.path(chart_dir, "output", "productivity-decomposition.csv"),
  path = file.path(chart_dir, "output", "productivity-decomposition-notes.md")
)

source_line <- "Source: Federal Reserve Bank of San Francisco (Fernald). Adapted from Ernie Tedeschi, Stripe Economics, July 2026."

recent <- filter(contributions, date >= ymd("2022-01-01"))

bars <- recent |>
  filter(series %in% components$series) |>
  mutate(series = factor(series, levels = components$series))

productivity_chart <- ggplot(bars, aes(date, four_quarter_mean)) +
  geom_col(aes(fill = series), width = 68, colour = "white", linewidth = 0.4) +
  geom_hline(yintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
  geom_point(
    data = filter(recent, series == "labor_productivity"),
    aes(shape = "Labor productivity growth"),
    colour = chart_greys[["title"]],
    size = 2.3
  ) +
  scale_fill_manual(
    values = setNames(components$colour, components$series),
    labels = setNames(components$label, components$series)
  ) +
  scale_shape_manual(values = 16) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(breaks = scales::breaks_width(1)) +
  guides(shape = guide_legend(order = 2)) +
  theme_chart()

title <- "Contributions to U.S. labor productivity growth"
subtitle <- "Business sector, average over four quarters, percentage points"

# A wide version for desktops and a narrow one for phones, with text wrapped to fit each.
save_chart(
  productivity_chart +
    chart_labels(title, subtitle, source_line, width = 8) +
    guides(fill = guide_legend(nrow = 1, order = 1)) +
    theme(legend.box = "vertical", legend.spacing.y = unit(2, "pt")),
  file.path(chart_dir, "output", "productivity-decomposition.png"),
  width = 8,
  height = 5
)

save_chart(
  productivity_chart +
    chart_labels(title, subtitle, source_line, width = 4.2) +
    guides(fill = guide_legend(ncol = 1, order = 1)) +
    theme(legend.box = "vertical", legend.spacing.y = unit(2, "pt")),
  file.path(chart_dir, "output", "productivity-decomposition-narrow.png"),
  width = 4.2,
  height = 7.2
)
