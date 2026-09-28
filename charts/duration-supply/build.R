library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(readxl)
library(stringr)
library(lubridate)
library(ggplot2)

source("R/fetch_treasury.R")
source("R/fetch_nyfed.R")
source("R/fetch_sec.R")
source("R/chart_style.R")
source("charts/duration-supply/duration.R")

chart_dir <- "charts/duration-supply"

# Treasury securities and the Fed's holdings -----------------------------------

# A year before the first plotted 12-month change.
first_month_end <- ymd("2009-12-31")

outstanding <- fetch_treasury_mspd_marketable(first_month_end)
month_ends <- sort(unique(outstanding$date))
latest_month_end <- max(month_ends)

# The Fed reports holdings each Wednesday; each month end uses the last
# Wednesday on or before it.
soma_dates <- fetch_nyfed_soma_dates()
soma_date_for <- tibble(date = month_ends) |>
  mutate(as_of = map_vec(date, \(d) max(soma_dates[soma_dates <= d])))

fed_holdings <- fetch_nyfed_soma_treasury(unique(soma_date_for$as_of)) |>
  inner_join(soma_date_for, by = "as_of", relationship = "many-to-many") |>
  select(date, cusip, held)

treasury_held_privately <- outstanding |>
  left_join(fed_holdings, by = c("date", "cusip")) |>
  transmute(
    date,
    type,
    coupon,
    years_to_maturity = time_length(interval(date, maturity), "years"),
    amount = outstanding - coalesce(held, 0)
  ) |>
  filter(years_to_maturity > 0)

# Hyperscaler bonds ------------------------------------------------------------

# Dollar bonds registered with the SEC, read from prospectus covers back to the
# companies' first bonds. Google Inc. issued Alphabet's bonds before 2016.
hyperscalers <- c(
  Alphabet = "1652044", Alphabet = "1288776", Amazon = "1018724", Meta = "1326801", Microsoft = "789019",
  Oracle = "1341439"
)

# Deals first sold privately appear only in the exchange offers that later
# registered them, so they are dated by the issue date those filings give.
privately_placed <- tribble(
  ~company, ~cik, ~accession, ~issued,
  "Amazon", "1018724", "0001193125-18-154502", ymd("2017-08-22"),
  "Meta", "1326801", "0000950103-22-020353", ymd("2022-08-09")
)

offerings <- map(hyperscalers, fetch_sec_filings) |>
  list_rbind(names_to = "company") |>
  filter(form %in% c("424B2", "424B5")) |>
  select(company, cik, accession, issued = filed) |>
  bind_rows(privately_placed)

hyperscaler_bonds <- pmap(list(offerings$cik, offerings$accession), fetch_sec_prospectus_tranches) |>
  list_rbind() |>
  inner_join(select(offerings, company, accession, issued), by = "accession") |>
  filter(currency == "USD") |>
  mutate(
    coupon = as.numeric(str_extract(title, "[\\d.]+(?=\\s?%)")),
    type = if_else(str_detect(title, "(?i)floating"), "floating_rate", "note"),
    # Titles give the maturity year and sometimes the date; without a date, the
    # day is taken as the issue's month and day.
    maturity = coalesce(
      mdy(str_extract(title, "(?<=due )[A-Za-z]+ \\d{1,2}, \\d{4}"), quiet = TRUE),
      make_date(as.integer(str_extract(title, "\\d{4}$")), month(issued), day(issued))
    )
  )

write_csv(
  select(hyperscaler_bonds, company, issued, accession, title, amount, coupon, maturity),
  file.path(chart_dir, "data", str_glue("sec_hyperscaler_bonds_{today()}.csv"))
)

hyperscalers_outstanding <- tibble(date = month_ends) |>
  cross_join(hyperscaler_bonds) |>
  filter(issued <= date, maturity > date) |>
  transmute(
    date,
    type,
    coupon,
    years_to_maturity = time_length(interval(date, maturity), "years"),
    amount = amount / 1e6
  )

# Duration on one yield curve ---------------------------------------------------

# Every month is priced on the latest month-end curve, so the series shows
# changes in the securities held, not swings in yields. Hyperscaler bonds are
# priced on the Treasury curve, ignoring their credit spread.
latest_curves <- bind_rows(
  tidyusmacro::getFRED(
    `0.083` = "DGS1MO", `0.25` = "DGS3MO", `0.5` = "DGS6MO", `1` = "DGS1", `2` = "DGS2", `3` = "DGS3",
    `5` = "DGS5", `7` = "DGS7", `10` = "DGS10", `20` = "DGS20", `30` = "DGS30"
  ) |>
    month_end_curve() |>
    mutate(curve = "nominal"),
  tidyusmacro::getFRED(`5` = "DFII5", `7` = "DFII7", `10` = "DFII10", `20` = "DFII20", `30` = "DFII30") |>
    month_end_curve() |>
    mutate(curve = "real")
) |>
  filter(date == latest_month_end)

fixed_curves <- cross_join(tibble(date = month_ends), select(latest_curves, -date))

duration_supply <- bind_rows(
  treasury = treasury_held_privately,
  hyperscalers = hyperscalers_outstanding,
  .id = "issuer"
) |>
  add_modified_duration(fixed_curves) |>
  summarise(ten_year_equivalents = sum(amount * modified_duration / ten_year_duration) / 1e3, .by = c(issuer, date)) |>
  arrange(issuer, date) |>
  mutate(change_12_months = ten_year_equivalents - lag(ten_year_equivalents, 12), .by = issuer) |>
  filter(!is.na(change_12_months))

write_csv(
  treasury_held_privately |>
    summarise(amount = sum(amount), .by = c(date, type)),
  file.path(chart_dir, "data", str_glue("treasury_held_privately_{latest_month_end}.csv"))
)

duration_supply |>
  select(date, issuer, change_12_months) |>
  pivot_wider(names_from = issuer, values_from = change_12_months, names_glue = "{issuer}_12_month_change") |>
  arrange(date) |>
  mutate(across(-date, \(x) round(x, 3))) |>
  write_csv(file.path(chart_dir, "output", "duration-supply.csv"), na = "")

# Chart ----------------------------------------------------------------------------

issuers <- tribble(
  ~issuer, ~label, ~colour,
  "hyperscalers", "Big tech bonds", chart_colors[["orange"]],
  "treasury", "Treasury securities", chart_colors[["blue"]]
)

latest_label <- format(latest_month_end, "%B %Y")

write_chart_notes(
  notes = c(
    "**10-year equivalents:** The amount of 10-year notes with the same sensitivity to interest rates.",
    "**Treasury securities:** Marketable Treasury debt not held by the Federal Reserve.",
    "**Big tech bonds:** Dollar bonds registered by Alphabet (and Google before it), Amazon, Meta, Microsoft, and Oracle. Private placements and loans are not included."
  ),
  source = str_glue(
    "Sources: Treasury; Federal Reserve Bank of New York; Securities and Exchange Commission. Through ",
    "{latest_label}. Related work: Etra, Exante Data, September 2026; De Vere, Ramaswamy, and Searls, ",
    "[\"How AI debt financing impacts duration supply and interest rates\"]",
    "(https://www.dallasfed.org/research/economics/2026/0210-searls-aifinancing), Federal Reserve Bank of Dallas, ",
    "February 2026."
  ),
  csv_path = file.path(chart_dir, "output", "duration-supply.csv"),
  path = file.path(chart_dir, "output", "duration-supply-notes.md")
)

areas <- duration_supply |>
  filter(date >= ymd("2011-01-01")) |>
  mutate(issuer = factor(issuer, levels = issuers$issuer))

duration_chart <- ggplot(areas, aes(date, change_12_months, fill = issuer)) +
  geom_area(position = "stack", colour = "white", linewidth = 0.2) +
  geom_hline(yintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
  scale_fill_manual(values = setNames(issuers$colour, issuers$issuer), labels = setNames(issuers$label, issuers$issuer)) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y", expand = expansion(mult = c(0, 0.02))) +
  scale_y_continuous(labels = scales::label_comma(), breaks = scales::breaks_width(500)) +
  theme_chart()

title <- "Long-term debt added by the Treasury and big tech"
subtitle <- "Change over 12 months in debt held by private investors, billions of dollars in 10-year equivalents"
source_line <- str_glue(
  "Sources: Treasury; Federal Reserve Bank of New York; Securities and Exchange Commission. Data through {latest_label}."
)

save_chart(
  duration_chart + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "duration-supply.png"),
  width = 8,
  height = 5
)

save_chart(
  duration_chart +
    chart_labels(title, subtitle, source_line, width = 4.2) +
    guides(fill = guide_legend(ncol = 1)),
  file.path(chart_dir, "output", "duration-supply-narrow.png"),
  width = 4.2,
  height = 6.4
)
