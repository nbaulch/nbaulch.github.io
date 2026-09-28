# The SEC asks every request to name the requester. SEC_USER_AGENT holds a
# name and contact email, set in the environment and never committed.
sec_get <- function(url, path) {
  if (!file.exists(path)) {
    response <- httr::RETRY("GET", url, httr::user_agent(Sys.getenv("SEC_USER_AGENT")))
    httr::stop_for_status(response)
    writeBin(httr::content(response, as = "raw"), path)
    # The SEC allows at most 10 requests a second.
    Sys.sleep(0.15)
  }
  path
}

# Every filing by a company, from EDGAR's submissions index. `cik` is the
# company's central index key.
fetch_sec_filings <- function(cik, cache_dir = "cache/sec") {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  index_url <- \(file) str_glue("https://data.sec.gov/submissions/{file}")
  as_filings <- \(block) as_tibble(block[c("form", "filingDate", "accessionNumber")])

  # The index is refetched each run, since new filings arrive.
  index_path <- file.path(cache_dir, str_glue("CIK{str_pad(cik, 10, pad = '0')}.json"))
  unlink(index_path)
  submissions <- jsonlite::fromJSON(sec_get(index_url(basename(index_path)), index_path))

  older <- map(submissions$filings$files$name, \(file) {
    jsonlite::fromJSON(sec_get(index_url(file), file.path(cache_dir, file))) |> as_filings()
  })

  bind_rows(as_filings(submissions$filings$recent), older) |>
    transmute(cik, form, filed = ymd(filingDate), accession = accessionNumber)
}

# The notes offered in one prospectus, read from its cover, which lists each
# tranche with its currency, face amount, coupon, and maturity:
# "$1,500,000,000 4.450% Notes due 2032". Works for prospectus supplements and
# for exchange offers that register notes first sold privately. Preliminary
# supplements leave the amounts blank and return no rows. Filings are never
# changed, so each is cached.
fetch_sec_prospectus_tranches <- function(cik, accession, cache_dir = "cache/sec") {
  folder <- str_glue("https://www.sec.gov/Archives/edgar/data/{cik}/{str_remove_all(accession, '-')}")
  files <- jsonlite::fromJSON(sec_get(str_glue("{folder}/index.json"), file.path(cache_dir, str_glue("{accession}.json"))))
  prospectus <- str_subset(files$directory$item$name, "424b[235]\\.htm$")

  if (length(prospectus) == 0) {
    return(NULL)
  }

  text <- sec_get(str_glue("{folder}/{prospectus[1]}"), file.path(cache_dir, str_glue("{accession}.htm"))) |>
    xml2::read_html() |>
    xml2::xml_text() |>
    str_squish()

  # Some filings open with a fee table that lists the notes in another order,
  # so the cover is found by its "(To prospectus dated ...)" line.
  cover_start <- str_locate(text, "(?i)prospectus supplement\\s*\\(?\\s*to (the )?prospectus dated|offers? to exchange")[1]

  if (is.na(cover_start)) {
    return(NULL)
  }

  # "C$" and "A$" come before "$" so Canadian and Australian dollars aren't
  # read as U.S. dollars. Up to 30 characters may sit between the amount and
  # the coupon, such as the company name or "of our new registered".
  tranches <- str_sub(text, cover_start, cover_start + 4000) |>
    str_match_all(str_c(
      "(?i)(US\\$|C\\$|A\\$|\\$|\u20ac|\u00a3|\u00a5)\\s?(\\d{1,3}(?:,\\d{3}){2,})\\s+[^$\u20ac\u00a3\u00a5%]{0,30}?",
      "((?:floating(?: rate)?|[\\d.]+\\s?%)[^$\u20ac\u00a3\u00a5]{0,40}?(?:notes|debentures) due ",
      "(?:[a-z]+ \\d{1,2}, )?\\d{4})"
    ))
  tranches <- tranches[[1]]

  tibble(
    cik,
    accession,
    currency = case_when(
      str_detect(tranches[, 2], "(?i)^c") ~ "CAD",
      str_detect(tranches[, 2], "(?i)^a") ~ "AUD",
      str_detect(tranches[, 2], "\\$") ~ "USD",
      str_detect(tranches[, 2], "\u20ac") ~ "EUR",
      str_detect(tranches[, 2], "\u00a3") ~ "GBP",
      str_detect(tranches[, 2], "\u00a5") ~ "JPY"
    ),
    amount = parse_number(tranches[, 3]),
    title = str_squish(tranches[, 4])
  ) |>
    # Covers can name a tranche twice, with different spacing or a full
    # maturity date, so tranches are matched on amount, coupon, and year.
    distinct(
      currency,
      amount,
      coupon = str_extract(str_to_lower(title), "floating|[\\d.]+(?=\\s?%)"),
      year = str_extract(title, "\\d{4}$"),
      .keep_all = TRUE
    ) |>
    select(-coupon, -year)
}
