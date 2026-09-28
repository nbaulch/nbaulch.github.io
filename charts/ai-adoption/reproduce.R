# Checks the fetched data against the numbers in Jeffrey S. Allen, "Monitoring AI
# Adoption in the U.S. Economy," FEDS Notes, April 3, 2026. The note publishes
# no figure data, so the comparison is with the values quoted in its text,
# rounded as he rounds them.

library(dplyr)
library(readr)
library(lubridate)

chart_dir <- "charts/ai-adoption"

latest_snapshot <- \(pattern) max(list.files(file.path(chart_dir, "data"), pattern, full.names = TRUE))

btos_ai_use <- read_csv(latest_snapshot("^census_btos_ai_"), show_col_types = FALSE, col_types = cols(period = "c"))
genai_use <- read_csv(latest_snapshot("^rps_genai_"), show_col_types = FALSE)

firm_share <- \(wording_used, survey_period) {
  btos_ai_use |>
    filter(wording == wording_used, is.na(employment_size), period == survey_period) |>
    pull(estimate)
}

worker_share <- \(survey_month, kind_of_use, how_often = "Share Using GenAI") {
  genai_use |>
    filter(
      date == survey_month,
      sample == if (kind_of_use == "For Work") "Employed" else "All",
      use == kind_of_use,
      frequency == how_often,
      statistic == "Mean"
    ) |>
    pull(value)
}

tribble(
  ~measure, ~published, ~ours,
  "Firms, old question, rise from September 2023 to October 2025", 6,
  firm_share("old_question", "202520") - firm_share("old_question", "202319"),
  "Firms, new question, end of 2025", 18, firm_share("new_question", "202526"),
  "Workers using generative AI for work, August 2024", 33, worker_share(ymd("2024-08-01"), "For Work"),
  "Workers using generative AI for work, November 2025", 41, worker_share(ymd("2025-11-01"), "For Work"),
  "Adults using generative AI outside work, August 2024", 36, worker_share(ymd("2024-08-01"), "Non-Work"),
  "Adults using generative AI outside work, November 2025", 50, worker_share(ymd("2025-11-01"), "Non-Work"),
  "Workers using it for work in the last week, November 2025", 35.2,
  worker_share(ymd("2025-11-01"), "For Work", "Share Used GenAI Last Week"),
  "Workers using it for work every day last week, November 2025", 12,
  worker_share(ymd("2025-11-01"), "For Work", "Share Used GenAI Every Day Last Week")
) |>
  mutate(matches = round(ours, if_else(published %% 1 == 0, 0, 1)) == published) |>
  print(width = Inf)
