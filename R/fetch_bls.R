# BLS asks scripted downloads to identify themselves with a contact email.
bls_contact <- "nicholas.baulch@gmail.com"

# CPI-U indexes from the BLS flat files, by series ID, one column each, named by
# the names of `series`.
fetch_bls_cpi <- function(series) {
  tidyusmacro::getBLSFiles("cpi", bls_contact) |>
    filter(series_id %in% series, period != "M13") |>
    transmute(date, name = names(series)[match(series_id, series)], value) |>
    pivot_wider(names_from = name, values_from = value) |>
    arrange(date)
}

# CPI-U relative importance each December, in percent of all items: one row per
# year and item, for the items named in `items`. Names are regular expressions,
# since BLS renames some items. 2009 to 2019 come from BLS's zipped text
# archives, later years from one spreadsheet each.
# https://www.bls.gov/cpi/tables/relative-importance/home.htm
fetch_bls_cpi_relative_importance <- function(items, from = 2009) {
  url <- "https://www.bls.gov/cpi/tables/relative-importance"
  cache_dir <- "cache/bls_relative_importance"
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  # Returns NULL for a year BLS hasn't published.
  download <- function(file) {
    path <- file.path(cache_dir, file)
    if (file.exists(path)) return(path)
    tryCatch(
      {
        download.file(file.path(url, file), path, mode = "wb", quiet = TRUE, headers = c(`User-Agent` = bls_contact))
        path
      },
      error = \(e) {
        unlink(path)
        NULL
      }
    )
  }

  # Text tables pad each item name with dots before the CPI-U weight. Long names
  # wrap onto a second line, which is joined back first.
  read_text_table <- function(path) {
    lines <- read_file(path) |>
      str_replace_all("([a-z,])[ ]*\r?\n[ ]+([a-z])", "\\1 \\2") |>
      str_split_1("\r?\n")
    purrr::map_dbl(items, \(item) {
      line <- lines[str_detect(lines, str_glue("^ +({item})[.]{{2}}"))][1]
      as.numeric(str_extract(str_remove(line, "^[^.]*[a-z)][.]+"), "[0-9]*[.][0-9]+"))
    })
  }
  read_spreadsheet <- function(path) {
    table <- readxl::read_excel(path, col_names = FALSE, .name_repair = "minimal")
    purrr::map_dbl(items, \(item) as.numeric(table[[3]][which(str_detect(trimws(table[[2]]), str_glue("^({item})$")))[1]]))
  }

  archives <- c("ri-archive-2000-2009.zip", "ri-archive-2010-2019.zip") |>
    purrr::map(\(file) unzip(download(file), exdir = cache_dir)) |>
    unlist()
  text_years <- tibble(year = from:2019) |>
    mutate(path = purrr::map_chr(year, \(y) str_subset(archives, str_glue("/{y}[.]txt$"))))
  spreadsheet_years <- 2020:(year(Sys.Date()) - 1)

  bind_rows(
    purrr::map2(text_years$year, text_years$path, \(y, path) tibble(year = y, item = names(items), weight = read_text_table(path))),
    purrr::map(spreadsheet_years, \(y) {
      path <- download(str_glue("{y}.xlsx"))
      if (!is.null(path)) tibble(year = y, item = names(items), weight = read_spreadsheet(path))
    })
  )
}
