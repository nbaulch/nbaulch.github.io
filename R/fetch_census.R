# Monthly U.S. goods trade by HS code and country from the Census
# international trade API, not seasonally adjusted, in dollars. `flow` is
# "imports" (general imports) or "exports" (total exports). The API needs a free
# key, read from the CENSUS_API_KEY environment variable. Returns countries
# only, without the all-country total the API adds.
# https://www.census.gov/data/developers/data-sets/international-trade.html
fetch_census_trade <- function(flow, hs_codes, from) {
  map(hs_codes, \(hs_code) fetch_census_trade_hs(flow, hs_code, from)) |>
    list_rbind()
}

fetch_census_trade_hs <- function(flow, hs_code, from) {
  commodity <- if (flow == "imports") "I_COMMODITY" else "E_COMMODITY"
  value <- if (flow == "imports") "GEN_VAL_MO" else "ALL_VAL_MO"

  query <- list(
    get = str_glue("{value},CTY_CODE,CTY_NAME"),
    COMM_LVL = str_glue("HS{nchar(hs_code)}"),
    SUMMARY_LVL = "DET",
    time = str_glue("from {format(from, '%Y-%m')}"),
    key = Sys.getenv("CENSUS_API_KEY")
  )
  query[[commodity]] <- hs_code

  response <- httr::GET(
    str_glue("https://api.census.gov/data/timeseries/intltrade/{flow}/hs"),
    query = query
  )
  httr::stop_for_status(response)

  # No content means no trade under that code in the period, as for codes
  # retired in an HS revision.
  if (httr::status_code(response) == 204) {
    return(NULL)
  }

  rows <- jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8"))

  rows[-1, ] |>
    as_tibble(.name_repair = \(x) make.unique(rows[1, ])) |>
    filter(CTY_CODE != "-") |>
    transmute(
      date = ym(time),
      flow,
      hs_code,
      country_code = CTY_CODE,
      country = str_to_title(CTY_NAME),
      value = as.numeric(.data[[value]])
    )
}

# One month of U.S. goods trade from the Census bulk files: every 10-digit
# product and country, summed over customs districts, not seasonally adjusted,
# in dollars. Imports keep the rate provision, which records whether goods
# entered duty-free (for example under USMCA) or dutiable. Exports keep whether
# goods were made in the U.S. or are re-exports. The files come with their own
# product and country codes, returned alongside. Field names are Census's, as
# documented in the file layouts.
# https://www.census.gov/foreign-trade/data/IMDB.html
# https://www.census.gov/foreign-trade/data/EXDB.html
fetch_census_trade_month <- function(flow, month) {
  dir <- tempfile()
  on.exit(unlink(dir, recursive = TRUE))
  zip <- file.path(dir, "download.zip")
  dir.create(dir)
  # Import files run to 200 MB, past R's default one-minute download timeout.
  op <- options(timeout = 900)
  on.exit(options(op), add = TRUE)
  download.file(census_trade_url(flow, month), zip, mode = "wb", quiet = TRUE)
  # File names inside are upper case in recent years and lower case in older ones.
  contents <- unzip(zip, list = TRUE)$Name
  needed <- c(detail = if (flow == "imports") "IMP_DETL.TXT" else "EXP_DETL.TXT", codes = "CONCORD.TXT", countries = "COUNTRY.TXT")
  files <- set_names(contents[match(needed, toupper(contents))], names(needed))
  unzip(zip, files = files, exdir = dir)
  paths <- set_names(file.path(dir, files), names(files))

  list(
    trade = read_census_trade_detail(paths[["detail"]], flow),
    commodities = read_fwf(
      paths[["codes"]],
      fwf_positions(
        c(1, 11, 211, 214, 217, 222, 227, 234),
        c(10, 160, 213, 216, 221, 226, 232, 235),
        c("commodity", "description", "unit_qy1", "unit_qy2", "sitc", "end_use", "naics", "hitech")
      ),
      col_types = cols(.default = "c"),
      progress = FALSE
    ),
    countries = read_fwf(
      paths[["countries"]],
      fwf_positions(c(1, 12), c(4, 61), c("country_code", "country")),
      col_types = cols(.default = "c"),
      progress = FALSE
    )
  )
}

census_trade_url <- function(flow, month) {
  file <- if (flow == "imports") "im_m/IMDB" else "ex_m/EXDB"
  str_glue("https://www.census.gov/trade/downloads/{year(month)}/Merch/{file}{format(month, '%y%m')}.ZIP")
}

# Keeps the monthly fields and drops the year-to-date ones, which repeat them.
# Arrow does the sum over districts, which takes dplyr much longer on a few
# million rows.
read_census_trade_detail <- function(path, flow) {
  if (flow == "imports") {
    keys <- c("commodity", "country_code", "rate_provision")
    values <- c(
      "con_qy1", "con_qy2", "con_val", "dut_val", "cal_dut", "con_cha", "con_cif",
      "gen_qy1", "gen_qy2", "gen_val", "gen_cha", "gen_cif",
      "air_val", "air_wgt", "air_cha", "ves_val", "ves_wgt", "ves_cha", "cnt_val", "cnt_wgt", "cnt_cha"
    )
    columns <- fwf_positions(
      c(1, 11, 21, 23, 27, seq(44, 344, by = 15)),
      c(10, 14, 22, 26, 28, seq(58, 358, by = 15)),
      c(keys, "year", "month", values)
    )
  } else {
    keys <- c("domestic_foreign", "commodity", "country_code")
    values <- c("qty_1", "qty_2", "all_val", "air_val", "air_wgt", "ves_val", "ves_wgt", "cnt_val", "cnt_wgt")
    columns <- fwf_positions(
      c(1, 2, 12, 18, 22, seq(39, 159, by = 15)),
      c(1, 11, 15, 21, 23, seq(53, 173, by = 15)),
      c(keys, "year", "month", values)
    )
  }

  read_fwf(
    path,
    columns,
    col_types = cols(.default = "d", !!!set_names(rep(list("c"), length(keys)), keys), year = "i", month = "i"),
    progress = FALSE
  ) |>
    arrow::arrow_table() |>
    summarise(across(all_of(values), sum), .by = c(year, month, all_of(keys))) |>
    collect() |>
    filter(if_any(all_of(values), \(x) x != 0)) |>
    mutate(date = make_date(year, month), .before = 1, .keep = "unused") |>
    arrange(commodity, country_code)
}

# Months of the Census trade store, the copy of the bulk files above kept as
# release assets on this repo by scripts/update_census_trade.R. Downloads
# months not yet in cache/, and again any that Census has since revised, then
# returns an Arrow dataset to query with dplyr and collect().
read_census_trade <- function(flow, from, to = today()) {
  dir <- "cache/census_trade"
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  local_manifest_path <- file.path(dir, "manifest.csv")

  manifest <- read_census_trade_manifest() |>
    filter(flow == .env$flow, date >= floor_date(from, "month"), date <= to)
  local_manifest <- if (file.exists(local_manifest_path)) {
    read_csv(local_manifest_path, col_types = "ccDcic")
  } else {
    manifest[0, ]
  }

  current <- manifest |>
    semi_join(local_manifest, by = c("file", "source_modified")) |>
    filter(file.exists(file.path(dir, file)))
  to_download <- anti_join(manifest, current, by = "file")
  walk(to_download$file, \(file) {
    download.file(file.path(census_trade_store, file), file.path(dir, file), mode = "wb", quiet = TRUE)
  })

  local_manifest |>
    anti_join(manifest, by = "file") |>
    bind_rows(manifest) |>
    write_csv(local_manifest_path)

  arrow::open_dataset(file.path(dir, manifest$file))
}

census_trade_store <- "https://github.com/nbaulch/nbaulch.github.io/releases/download/census-trade-data"

# One row per stored file: flow, month, and the Census release it came from.
read_census_trade_manifest <- function() {
  read_csv(file.path(census_trade_store, "manifest.csv"), col_types = "ccDcic")
}

# The store's list of country codes and names, from the latest month stored.
read_census_trade_countries <- function() {
  read_csv(file.path(census_trade_store, "countries.csv"), col_types = cols(.default = "c"))
}

# The store's product code lists, with descriptions and end-use categories.
# Codes change each January, so each year has its own list.
read_census_trade_codes <- function(flows, years) {
  expand_grid(flow = flows, year = unique(years)) |>
    pmap(\(flow, year) {
      read_csv(file.path(census_trade_store, str_glue("{flow}-codes-{year}.csv")), col_types = cols(.default = "c")) |>
        mutate(flow, year, .before = 1)
    }) |>
    list_rbind()
}

# Release dates of the monthly trade report (FT-900), one row per month of
# data, including months not yet released. The page's first table is the
# FT-900; the others are for other Census releases. Dates not yet set read
# "TBD" and come back as NA.
# https://www.census.gov/foreign-trade/reference/release_schedule.html
fetch_census_trade_schedule <- function() {
  rows <- xml2::read_html("https://www.census.gov/foreign-trade/reference/release_schedule.html") |>
    xml2::xml_find_first("//table") |>
    xml2::xml_find_all(".//tr[td]")
  cell <- \(i) str_squish(xml2::xml_text(xml2::xml_find_first(rows, str_glue("td[{i}]"))))

  tibble(month = cell(1), released = mdy(cell(2), quiet = TRUE)) |>
    filter(str_detect(month, "^[A-Z][a-z]+ \\d{4}$")) |>
    mutate(month = my(month))
}

# Census posts only the latest monthly trade report (FT-900), so a refresh saves
# what it reads.
# https://www.census.gov/foreign-trade/Press-Release/current_press_release/index.html
download_census_ft900_exhibit <- function(number) {
  path <- tempfile(fileext = ".xlsx")
  download.file(
    str_glue("https://www.census.gov/foreign-trade/Press-Release/current_press_release/exh{number}.xlsx"),
    path,
    mode = "wb",
    quiet = TRUE
  )
  path
}

# One exhibit of the FT-900 by month, in long form: one row per block, month,
# and series, in millions of dollars. The sheets spread each header over several
# rows, so `series` names the value columns left to right. Exhibits in blocks,
# such as exports above imports, name each block in the row above it. Months
# revised in this release are marked "(R)". Some exhibits repeat the previous
# month as published a month earlier, in the row below its label.
fetch_census_ft900_exhibit <- function(number, series) {
  readxl::read_excel(download_census_ft900_exhibit(number), col_names = c("label", series), col_types = "text") |>
    mutate(
      label = coalesce(label, if_else(str_detect(lag(label), "published last month"), lag(label), NA)),
      block = if_else(is.na(label) & .data[[series[1]]] %in% c("Exports", "Imports"), .data[[series[1]]], NA),
      year = as.integer(str_extract(label, "^\\d{4}$"))
    ) |>
    fill(block, year) |>
    filter(str_detect(label, str_c("^(", str_c(month.name, collapse = "|"), ")"))) |>
    transmute(
      block = str_to_lower(block),
      date = make_date(year, match(word(label), month.name)),
      revised = str_detect(label, fixed("(R)")),
      published_last_month = str_detect(label, "published last month"),
      across(all_of(series), \(x) suppressWarnings(as.numeric(x)))
    ) |>
    pivot_longer(all_of(series), names_to = "series") |>
    filter(!is.na(value))
}

# FT-900 exhibit 19: seasonally adjusted goods trade by country and area, Census
# basis, in millions of dollars, for the latest two months. Each block (balance,
# exports, imports) lists countries under its name. The month headers sit in the
# fourth row; the previous month's header is merged over a column of revision
# marks and the column of values.
fetch_census_ft900_countries <- function() {
  sheet <- readxl::read_excel(
    download_census_ft900_exhibit(19),
    col_names = FALSE,
    col_types = "text",
    .name_repair = "unique_quiet"
  )
  months <- my(str_squish(unlist(sheet[4, c(2, 3)])))

  sheet |>
    select(country = 1, latest = 2, previous = 4) |>
    mutate(block = if_else(country %in% c("Balance", "Exports", "Imports") & is.na(latest), str_to_lower(country), NA)) |>
    fill(block) |>
    filter(!is.na(block), !is.na(latest)) |>
    pivot_longer(c(latest, previous), names_to = "month") |>
    transmute(block, country, date = months[match(month, c("latest", "previous"))], value = as.numeric(value))
}

# Monthly U.S. goods trade by Census end-use category from the international
# trade API, not seasonally adjusted, in dollars: the six principal categories
# (level EU1) and about 140 detailed ones (EU5), with their names.
fetch_census_trade_end_use <- function(flow, from) {
  prefix <- if (flow == "imports") "I" else "E"
  value <- if (flow == "imports") "GEN_VAL_MO" else "ALL_VAL_MO"
  response <- httr::GET(
    str_glue("https://api.census.gov/data/timeseries/intltrade/{flow}/enduse"),
    query = list(
      get = str_glue("{value},{prefix}_ENDUSE,{prefix}_ENDUSE_LDESC,COMM_LVL"),
      CTY_CODE = "-",
      time = str_glue("from {format(from, '%Y-%m')}"),
      key = Sys.getenv("CENSUS_API_KEY")
    )
  )
  httr::stop_for_status(response)
  rows <- jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8"))

  rows[-1, ] |>
    as_tibble(.name_repair = \(x) make.unique(rows[1, ])) |>
    filter(COMM_LVL %in% c("EU1", "EU5")) |>
    transmute(
      date = ym(time),
      flow,
      level = COMM_LVL,
      code = .data[[str_glue("{prefix}_ENDUSE")]],
      description = str_to_sentence(.data[[str_glue("{prefix}_ENDUSE_LDESC")]]) |>
        str_replace_all(c("\\bcanada\\b" = "Canada", "\\bmexico\\b" = "Mexico", "\\bu\\.s\\." = "U.S.")),
      value = as.numeric(.data[[value]])
    )
}

# One sheet of a Business Trends and Outlook Survey download, such as
# "National.xlsx", in long form: one row per question, answer, and survey
# period, with estimates in percent. Suppressed estimates, shown as ".", are NA.
# https://www.census.gov/hfp/btos/data_downloads
fetch_census_btos <- function(file, sheet) {
  download <- tempfile(fileext = ".xlsx")
  download.file(
    str_glue("https://www.census.gov/hfp/btos/downloads/{URLencode(file)}"),
    download,
    mode = "wb",
    quiet = TRUE
  )

  read_excel(download, sheet = sheet, col_types = "text") |>
    rename_with(\(name) str_to_lower(str_replace_all(name, " ", "_"))) |>
    filter(str_detect(question_id, "^\\d+$")) |>
    pivot_longer(matches("^\\d{6}$"), names_to = "period", values_to = "estimate") |>
    mutate(estimate = suppressWarnings(parse_number(estimate)))
}

# Survey periods of the Business Trends and Outlook Survey, with the two-week
# reference period each asks about and its publication date.
fetch_census_btos_periods <- function() {
  download <- tempfile(fileext = ".xlsx")
  download.file(
    "https://www.census.gov/hfp/btos/downloads/National.xlsx",
    download,
    mode = "wb",
    quiet = TRUE
  )

  read_excel(download, sheet = "Collection and Reference Dates", .name_repair = "unique_quiet") |>
    filter(!is.na(Smpdt)) |>
    transmute(
      period = as.character(Smpdt),
      reference_start = as_date(`Reference Period Start`),
      reference_end = as_date(`Ref End`),
      published = as_date(`Publication Date`)
    )
}

# Firms and employment by enterprise size for the whole U.S. economy, from the
# Statistics of U.S. Businesses detailed-size table for one year. Size codes
# and labels are as published, such as "02" and "02: <5".
# https://www.census.gov/programs-surveys/susb.html
fetch_census_susb <- function(year, cache_dir = "cache/census_susb") {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(cache_dir, str_glue("us_state_naics_detailedsizes_{year}.txt"))
  if (!file.exists(path)) {
    download.file(
      str_glue("https://www2.census.gov/programs-surveys/susb/tables/{year}/us_state_naics_detailedsizes_{year}.txt"),
      path,
      mode = "wb",
      quiet = TRUE
    )
  }

  read_csv(path, col_types = cols(.default = "c")) |>
    filter(STATE == "00", NAICS == "--") |>
    transmute(size_code = ENTRSIZE, size_label = ENTRSIZEDSCR, firms = as.numeric(FIRM), employment = as.numeric(EMPL))
}
