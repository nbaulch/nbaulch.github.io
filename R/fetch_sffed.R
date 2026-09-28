# Fernald's quarterly utilization-adjusted TFP for the U.S. business sector.
# https://www.frbsf.org/research-and-insights/data-and-indicators/total-factor-productivity-tfp/
#
# Past releases are not published, so each one is saved under its release date.
# Returns the path to the saved file.
fetch_sffed_tfp <- function(dir) {
  download <- tempfile(fileext = ".xlsx")
  download.file(
    "https://www.frbsf.org/wp-content/uploads/quarterly_tfp.xlsx",
    download,
    mode = "wb",
    quiet = TRUE
  )

  release_date <- read_sffed_release_date(download)
  path <- file.path(dir, str_glue("sffed_tfp_{release_date}.xlsx"))
  file.copy(download, path, overwrite = TRUE)
  path
}

read_sffed_release_date <- function(path) {
  read_excel(path, sheet = "quarterly", range = "A1", col_names = "note") |>
    pull(note) |>
    str_extract("(?<=Produced on )\\w+ \\d+, \\d{4}") |>
    mdy()
}

read_sffed_tfp <- function(path) {
  read_excel(path, sheet = "quarterly", skip = 1) |>
    filter(str_detect(date, "^\\d{4}:Q\\d$")) |>
    mutate(date = yq(date))
}

read_sffed_capital <- function(path) {
  read_excel(path, sheet = "Capital-input-details", skip = 1) |>
    filter(str_detect(date, "^\\d{4}:Q\\d$")) |>
    mutate(date = yq(date))
}
