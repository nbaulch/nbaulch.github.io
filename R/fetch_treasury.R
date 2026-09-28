# Marketable Treasury securities outstanding at each month end, one row per
# security, from the Monthly Statement of the Public Debt: bills (at maturity
# value), notes, bonds, inflation-protected securities (including the inflation
# adjustment), and floating rate notes. Amounts are in millions of dollars and
# are net of buybacks. `from` is the first month end.
# https://fiscaldata.treasury.gov/datasets/monthly-statement-public-debt/
fetch_treasury_mspd_marketable <- function(from) {
  url <- "https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v1/debt/mspd/mspd_table_3_market"
  query <- \(page) list(
    filter = str_glue("record_date:gte:{from}"),
    fields = "record_date,security_class1_desc,security_class2_desc,interest_rate_pct,maturity_date,outstanding_amt",
    `page[size]` = 10000,
    `page[number]` = page
  )

  first_page <- httr::GET(url, query = query(1)) |> httr::content(as = "parsed", simplifyVector = TRUE)

  map(seq_len(first_page$meta$`total-pages`), \(page) {
    httr::GET(url, query = query(page)) |>
      httr::content(as = "parsed", simplifyVector = TRUE) |>
      pluck("data")
  }) |>
    list_rbind() |>
    as_tibble() |>
    # Reopenings of a security share its CUSIP; only the first row of each
    # carries the amount outstanding. Subtotal rows have no CUSIP.
    filter(str_detect(security_class2_desc, "^912"), outstanding_amt != "null") |>
    transmute(
      date = ymd(record_date),
      cusip = security_class2_desc,
      type = recode_values(
        security_class1_desc,
        "Bills Maturity Value" ~ "bill",
        "Notes" ~ "note",
        "Bonds" ~ "bond",
        "Inflation-Protected Securities" ~ "inflation_protected",
        "Floating Rate Notes" ~ "floating_rate"
      ),
      coupon = suppressWarnings(as.numeric(interest_rate_pct)),
      maturity = ymd(maturity_date),
      outstanding = as.numeric(outstanding_amt)
    ) |>
    filter(!is.na(type))
}
