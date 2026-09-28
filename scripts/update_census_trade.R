# Keeps the Census trade store current: one Parquet file per flow and month,
# from January 2010, attached to the census-trade-data release of this repo.
# Run by .github/workflows/census-trade-data.yml, which has the token to upload.
#
# Census reposts past months when it revises them, as it does each June, so a
# month is pulled again whenever its file's Last-Modified date changes. The
# manifest records the date each stored file came from, and is uploaded after
# every file so a run that stops early resumes where it left off.

library(dplyr)
library(purrr)
library(readr)
library(stringr)
library(tidyr)
library(lubridate)

source("R/fetch_census.R")

release <- "census-trade-data"
store_dir <- "cache/census_trade"
stop_after <- now() + hours(5)  # GitHub stops a job at six hours

gh <- function(...) {
  status <- system2("gh", c(...))
  if (status != 0) stop("gh ", paste(...), " failed")
}

upload <- function(path) gh("release", "upload", release, path, "--clobber")

source_modified <- function(flow, month) {
  # Months not yet released answer 404, which needs no retry.
  response <- httr::RETRY("HEAD", census_trade_url(flow, month), terminate_on = 404, quiet = TRUE)
  if (httr::status_code(response) != 200) {
    return(NA_character_)
  }
  httr::headers(response)[["last-modified"]]
}

dir.create(store_dir, recursive = TRUE, showWarnings = FALSE)
manifest_path <- file.path(store_dir, "manifest.csv")

if (system2("gh", c("release", "view", release), stdout = FALSE, stderr = FALSE) != 0) {
  gh(
    "release", "create", release, "--latest=false",
    "--title", shQuote("Census trade data"),
    "--notes", shQuote("Monthly U.S. imports and exports by 10-digit product and country from the Census bulk files. Maintained by scripts/update_census_trade.R.")
  )
}
system2("gh", c("release", "download", release, "--pattern", "manifest.csv", "--dir", store_dir, "--clobber"))

manifest <- if (file.exists(manifest_path)) {
  read_csv(manifest_path, col_types = "ccDcic")
} else {
  tibble(file = character(), flow = character(), date = as_date(character()), source_modified = character(), rows = integer(), stored = character())
}

sources <- expand_grid(
  flow = c("imports", "exports"),
  date = seq(ymd("2010-01-01"), floor_date(today(), "month"), by = "month")
) |>
  mutate(source_modified = map2_chr(flow, date, source_modified)) |>
  filter(!is.na(source_modified))

to_update <- sources |>
  anti_join(manifest, by = c("flow", "date", "source_modified")) |>
  arrange(date, flow)

message(nrow(to_update), " of ", nrow(sources), " monthly files are new or revised")

# Census's server now and then answers with a brief error, such as a 502. A
# month that still fails after a few tries is left for the next run.
fetch_month_patiently <- possibly(
  insistently(fetch_census_trade_month, rate_backoff(pause_base = 10, max_times = 4), quiet = FALSE),
  otherwise = NULL
)
skipped <- character()

for (i in seq_len(nrow(to_update))) {
  if (now() > stop_after) {
    message("Stopping for time; the next run continues from here")
    break
  }
  source_file <- to_update[i, ]
  month <- fetch_month_patiently(source_file$flow, source_file$date)
  if (is.null(month)) {
    skipped <- c(skipped, str_glue("{source_file$flow} {format(source_file$date, '%Y-%m')}"))
    next
  }
  file <- str_glue("{source_file$flow}-{format(source_file$date, '%Y-%m')}.parquet")
  arrow::write_parquet(month$trade, file.path(store_dir, file), compression = "zstd")
  upload(file.path(store_dir, file))

  # Codes change each January, so each year keeps its own list.
  codes <- str_glue("{source_file$flow}-codes-{year(source_file$date)}.csv")
  write_csv(month$commodities, file.path(store_dir, codes))
  upload(file.path(store_dir, codes))
  if (source_file$date == max(sources$date)) {
    write_csv(month$countries, file.path(store_dir, "countries.csv"))
    upload(file.path(store_dir, "countries.csv"))
  }

  manifest <- manifest |>
    filter(!(flow == source_file$flow & date == source_file$date)) |>
    bind_rows(tibble(
      file,
      flow = source_file$flow,
      date = source_file$date,
      source_modified = source_file$source_modified,
      rows = nrow(month$trade),
      stored = format(now("UTC"))
    )) |>
    arrange(flow, date)
  write_csv(manifest, manifest_path)
  upload(manifest_path)
  message("Stored ", file)
}

# Fails the run so a skipped month shows in the Actions history.
if (length(skipped) > 0) {
  stop("Skipped after repeated errors, left for the next run: ", str_flatten_comma(skipped))
}
