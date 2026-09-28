# Daily Treasury yields, term premiums, and risk-neutral (expected short rate)
# yields from the Adrian, Crump, and Moench model, maturities of 1 to 10 years,
# in percent. Each fitted yield is its term premium plus its risk-neutral yield.
# https://www.newyorkfed.org/research/data_indicators/term-premia-tabs
fetch_nyfed_acm <- function() {
  download <- tempfile(fileext = ".xls")
  download.file(
    "https://www.newyorkfed.org/medialibrary/media/research/data_indicators/ACMTermPremium.xls",
    download,
    mode = "wb",
    quiet = TRUE
  )

  read_excel(download, sheet = "ACM Daily") |>
    mutate(date = dmy(DATE), .keep = "unused", .before = 1) |>
    rename_with(str_to_lower, -date)
}

# The Federal Reserve's System Open Market Account holdings of Treasury
# securities by CUSIP, on each Wednesday in `dates` (as listed by
# fetch_nyfed_soma_dates()). Par values are in millions of dollars;
# inflation-protected holdings include their inflation compensation. Past
# holdings don't change, so each week's download is kept in `cache_dir`.
# https://markets.newyorkfed.org/static/docs/markets-api.html
fetch_nyfed_soma_treasury <- function(dates, cache_dir = "cache/nyfed_soma") {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

  map(dates, \(as_of) {
    path <- file.path(cache_dir, str_glue("{as_of}.json"))
    if (!file.exists(path)) {
      response <- httr::RETRY("GET", str_glue("https://markets.newyorkfed.org/api/soma/tsy/get/asof/{as_of}.json"))
      httr::stop_for_status(response)
      writeLines(httr::content(response, as = "text", encoding = "UTF-8"), path)
    }
    jsonlite::fromJSON(path)$soma$holdings
  }) |>
    list_rbind() |>
    as_tibble() |>
    transmute(
      as_of = ymd(asOfDate),
      cusip,
      held = (as.numeric(parValue) + coalesce(suppressWarnings(as.numeric(inflationCompensation)), 0)) / 1e6
    )
}

fetch_nyfed_soma_dates <- function() {
  ymd(jsonlite::fromJSON("https://markets.newyorkfed.org/api/soma/asofdates/list.json")$soma$asOfDates)
}

# Multivariate Core Trend inflation, the New York Fed's estimate of trend PCE
# inflation from 17 sectors, monthly, in percent: the central estimate and its
# band. The download is a chart-data sheet with four header rows.
# https://www.newyorkfed.org/research/policy/mct
fetch_nyfed_mct <- function() {
  read_csv(
    "https://www.newyorkfed.org/medialibrary/Research/Interactives/Data/mct/mct-chart-data.xlsx",
    skip = 4,
    col_names = FALSE,
    col_types = cols(.default = "c")
  ) |>
    transmute(date = mdy(X2), trend_low = as.numeric(X3), trend = as.numeric(X4), trend_high = as.numeric(X5)) |>
    filter(!is.na(date))
}
