# Generative AI use from the Real-Time Population Survey of Alexander Bick,
# Adam Blandin, and David Deming, as published on their Generative AI Adoption
# Tracker. The file has four header rows (sample, kind of use, frequency, and
# statistic), so it comes back in long form: one row per survey month and
# series. Shares are in percent.
# https://www.genaiadoptiontracker.com/
fetch_rps_genai <- function(file = "GenAI_All.csv") {
  raw <- read_csv(
    str_glue("https://www.genaiadoptiontracker.com/{file}"),
    col_names = FALSE,
    col_types = cols(.default = "c")
  )

  headers <- raw |>
    slice(1:4) |>
    select(-1) |>
    t() |>
    as_tibble(.name_repair = \(x) c("sample", "use", "frequency", "statistic")) |>
    fill(sample, use, frequency) |>
    mutate(column = names(raw)[-1])

  raw |>
    slice(-(1:5)) |>
    rename(survey_month = X1) |>
    pivot_longer(-survey_month, names_to = "column", values_to = "value") |>
    inner_join(headers, by = "column") |>
    transmute(
      date = my(survey_month),
      sample,
      use,
      frequency,
      statistic,
      value = as.numeric(value)
    ) |>
    arrange(date)
}
