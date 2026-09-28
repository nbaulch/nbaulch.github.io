library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(stringr)
library(lubridate)
library(ggplot2)
library(slider)

source("R/fetch_census.R")
source("R/fetch_rps.R")
source("R/chart_style.R")

chart_dir <- "charts/ai-adoption"

# Question 7 asks whether the business used AI in the last two weeks. Census
# widened it in November 2025 and publishes the old wording in a separate file.
# The chart uses the new wording by firm size; the national series in both
# wordings are kept in the snapshot for `reproduce.R`.
btos_periods <- fetch_census_btos_periods()

btos_ai_use <- bind_rows(
  old_question = fetch_census_btos("AI Core Questions.xlsx", "National Estimates"),
  new_question = fetch_census_btos("National.xlsx", "Response Estimates"),
  new_question = fetch_census_btos("Employment Size Class.xlsx", "Response Estimates"),
  .id = "wording"
) |>
  filter(question_id == "7", answer == "Yes", !is.na(estimate)) |>
  select(wording, employment_size = empsize, period, estimate)

btos_release <- btos_periods |>
  filter(period == max(btos_ai_use$period)) |>
  pull(published)

write_csv(btos_ai_use, file.path(chart_dir, "data", str_glue("census_btos_ai_{btos_release}.csv")))

genai_use <- fetch_rps_genai()

# Only `reproduce.R` uses the worker survey. The tracker doesn't date its
# releases, so the snapshot is named by the fetch date.
write_csv(genai_use, file.path(chart_dir, "data", str_glue("rps_genai_{today()}.csv")))

# Firm counts by size class weight the Census size classes into three groups.
# SUSB's 200 to 299 class straddles the survey's 250 cutoff, so it is split
# evenly.
susb_year <- 2022
firms_by_size <- fetch_census_susb(susb_year)

firm_count <- \(codes) sum(firms_by_size$firms[firms_by_size$size_code %in% codes])

size_classes <- tribble(
  ~employment_size, ~group, ~firms,
  "A", "small", firm_count("02"),
  "B", "small", firm_count("03"),
  "C", "small", firm_count(c("04", "05")),
  "D", "small", firm_count(c("06", "07", "08", "09", "10")),
  "E", "mid", firm_count(c("11", "12")),
  "F", "mid", firm_count(c("13", "14")) + firm_count("15") / 2,
  "G", "large", firm_count("01") - firm_count(c("02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14")) -
    firm_count("15") / 2
)

write_csv(size_classes, file.path(chart_dir, "data", str_glue("census_susb_firms_{susb_year}.csv")))

# Single size classes swing from survey to survey, so each point averages the
# latest three surveys, six weeks of data. Each survey is dated by the end of
# the two weeks it asks about.
adoption_by_size <- btos_ai_use |>
  filter(!is.na(employment_size)) |>
  inner_join(size_classes, by = "employment_size") |>
  summarise(estimate = weighted.mean(estimate, firms), .by = c(period, group)) |>
  inner_join(btos_periods, by = "period") |>
  arrange(reference_end) |>
  mutate(estimate = slide_dbl(estimate, mean, .before = 2, .complete = TRUE), .by = group) |>
  filter(!is.na(estimate)) |>
  select(date = reference_end, group, estimate)

adoption_by_size |>
  pivot_wider(names_from = group, values_from = estimate) |>
  transmute(
    date,
    firms_fewer_than_50_employees = small,
    firms_50_to_249_employees = mid,
    firms_250_or_more_employees = large
  ) |>
  mutate(across(-date, \(x) round(x, 1))) |>
  write_csv(file.path(chart_dir, "output", "ai-adoption.csv"))

groups <- tribble(
  ~group, ~label, ~colour,
  "large", "250 or more employees", chart_colors[["blue"]],
  "mid", "50 to 249", chart_colors[["teal"]],
  "small", "Fewer than 50", chart_colors[["grey"]]
)

write_chart_notes(
  notes = c(
    "**Using AI:** The business used AI in any of its functions in the past two weeks.",
    "**Size groups:** Averages of the Census Bureau's size classes, weighted by the number of firms in each."
  ),
  source = str_glue(
    "Sources: Census Bureau, [Business Trends and Outlook Survey](https://www.census.gov/hfp/btos/), through ",
    "{format(max(adoption_by_size$date), '%B %-d, %Y')}, and Statistics of U.S. Businesses, {susb_year}. ",
    "Builds on Allen, [\"Monitoring AI Adoption in the U.S. Economy\"]",
    "(https://www.federalreserve.gov/econres/notes/feds-notes/monitoring-ai-adoption-in-the-u-s-economy-20260403.html), ",
    "FEDS Notes, April 2026."
  ),
  csv_path = file.path(chart_dir, "output", "ai-adoption.csv"),
  path = file.path(chart_dir, "output", "ai-adoption-notes.md")
)

adoption_chart <- adoption_by_size |>
  mutate(group = factor(group, levels = groups$group)) |>
  ggplot(aes(date, estimate, colour = group)) +
  geom_line(linewidth = 0.9) +
  scale_colour_manual(values = setNames(groups$colour, groups$group), labels = setNames(groups$label, groups$group)) +
  scale_x_date(date_breaks = "3 months", date_labels = "%b %Y") +
  scale_y_continuous(limits = c(0, 50), breaks = seq(0, 50, 10), expand = expansion(mult = c(0, 0.02))) +
  theme_chart()

title <- "Share of firms using AI, by firm size"
subtitle <- "By number of employees, average of the latest three surveys, percent"
source_line <- "Source: Census Bureau. Builds on Allen, FEDS Notes, April 2026."

save_chart(
  adoption_chart + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "ai-adoption.png"),
  width = 8,
  height = 5
)

save_chart(
  adoption_chart +
    chart_labels(title, subtitle, source_line, width = 4.2) +
    guides(colour = guide_legend(ncol = 1)) +
    theme(axis.text.x = element_text(size = rel(0.85))),
  file.path(chart_dir, "output", "ai-adoption-narrow.png"),
  width = 4.2,
  height = 6.4
)
