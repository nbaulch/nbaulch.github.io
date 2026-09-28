library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)
library(ggplot2)
library(purrr)

source("R/fetch_census.R")
source("R/trade_products.R")
source("R/chart_style.R")

chart_dir <- "charts/trade-release"

# The seasonally adjusted figures come from the latest FT-900; the rest are not
# seasonally adjusted, from the Census API and the trade store. Seasonal factors
# have been harder to estimate since 2020, so each section shows both views
# where the data allow.
headline <- fetch_census_ft900_exhibit(1, c(
  "balance_total", "balance_goods", "balance_services",
  "exports_total", "exports_goods", "exports_services",
  "imports_total", "imports_goods", "imports_services"
))
end_use_adjusted <- fetch_census_ft900_exhibit(6, c(
  "total_bop", "net_adjustments", "total_census",
  "0", "1", "2", "3", "4", "5"
))
real_goods <- fetch_census_ft900_exhibit(10, c("total", "0", "1", "2", "3", "4", "5", "residual"))
partners_adjusted <- fetch_census_ft900_countries()
countries <- read_census_trade_countries()

latest_month <- max(headline$date)
previous_month <- latest_month - months(1)
year_earlier <- latest_month - years(1)
schedule <- fetch_census_trade_schedule()
released <- schedule$released[schedule$month == latest_month]
next_release <- slice_min(filter(schedule, month > latest_month), month)

store_latest <- max(filter(read_census_trade_manifest(), flow == "imports")$date)
# The store adds a month a day or so after the release. Until then the page is
# left as it is, so it never mixes releases.
if (store_latest < latest_month) {
  message("The trade store runs through ", store_latest, " but the FT-900 covers ", latest_month, "; leaving the page as it is.")
  quit(save = "no")
}

end_use <- c("imports", "exports") |>
  map(\(flow) fetch_census_trade_end_use(flow, latest_month - months(25))) |>
  list_rbind()

list(
  census_ft900 = bind_rows(
    exhibit_1 = headline,
    exhibit_6 = end_use_adjusted,
    exhibit_10 = real_goods,
    exhibit_19 = partners_adjusted,
    .id = "exhibit"
  ),
  census_end_use = end_use
) |>
  iwalk(\(data, name) write_csv(data, file.path(chart_dir, "data", str_glue("{name}_{released}.csv"))))

billions <- \(x) sprintf("%.1f", x / 1e3)
change <- \(x) if_else(round(x, 1) == 0, "0", sprintf("%+.1f", x))
month_short <- \(date) format(date, "%b %Y")
snakecase_label <- \(x) str_remove(str_to_lower(str_replace_all(x, "[^A-Za-z]+", "_")), "_$")
country_name <- \(country) str_replace(str_to_title(country), "^Korea, South$", "South Korea")
dollars <- \(x) if_else(x < 0, str_c("-$", abs(x)), str_c("$", x))

markdown_table <- function(table, path) {
  header <- str_c("| ", str_c(c("", names(table)[-1]), collapse = " | "), " |")
  alignment <- str_c("|", str_c(c(":--", rep("--:", ncol(table) - 1)), collapse = "|"), "|")
  rows <- pmap_chr(table, \(...) str_c("| ", str_c(c(...), collapse = " | "), " |"))
  write_lines(c(header, alignment, rows), path)
}

write_lines(
  str_glue(
    "Data for {format(latest_month, '%B %Y')}, released {format(released, '%B %-d, %Y')}. ",
    "Next release: {format(next_release$month, '%B %Y')} data, ",
    "{if (is.na(next_release$released)) 'date not yet set' else format(next_release$released, '%B %-d, %Y')}."
  ),
  file.path(chart_dir, "output", "release.md")
)

# Headline --------------------------------------------------------------------

headline_rows <- c(
  balance_total = "Goods and services balance",
  balance_goods = "Goods balance",
  balance_services = "Services balance",
  exports_total = "Exports",
  imports_total = "Imports"
)

headline |>
  filter(series %in% names(headline_rows), date %in% c(latest_month, previous_month)) |>
  mutate(column = case_when(published_last_month ~ "first", date == latest_month ~ "latest", .default = "previous")) |>
  select(series, column, value) |>
  pivot_wider(names_from = column, values_from = value) |>
  transmute(
    series = headline_rows[series],
    "{month_short(latest_month)}" := billions(latest),
    "{month_short(previous_month)}" := billions(previous),
    Change = change((latest - previous) / 1e3),
    "Revision to {month_short(previous_month)}" := change((previous - first) / 1e3)
  ) |>
  arrange(match(series, headline_rows)) |>
  markdown_table(file.path(chart_dir, "output", "headline.md"))

# Product groups as on the goods balance chart, for gold here and for
# computers, chips, and telecom equipment by country below.
balance_start <- min(end_use_adjusted$date)
product_groups <- read_census_trade_codes(c("imports", "exports"), year(balance_start):year(latest_month)) |>
  transmute(flow, year, commodity, group = product_group(commodity, description, end_use))

store_values <- c(imports = "gen_val", exports = "all_val")
gold_balance <- store_values |>
  imap(\(value, flow) {
    gold_codes <- unique(filter(product_groups, flow == .env$flow, group == "gold")$commodity)
    read_census_trade(flow, balance_start, latest_month) |>
      filter(commodity %in% gold_codes) |>
      select(date, commodity, value = all_of(value)) |>
      summarise(value = sum(value), .by = c(date, commodity)) |>
      collect()
  }) |>
  list_rbind(names_to = "flow") |>
  mutate(year = year(date)) |>
  semi_join(filter(product_groups, group == "gold"), by = c("flow", "year", "commodity")) |>
  summarise(value = sum(value), .by = c(date, flow)) |>
  pivot_wider(names_from = flow, values_fill = 0) |>
  transmute(date, gold = (exports - imports) / 1e9)

goods_balance_unadjusted <- end_use |>
  filter(level == "EU1") |>
  summarise(value = sum(value), .by = c(date, flow)) |>
  pivot_wider(names_from = flow) |>
  transmute(date, balance = (exports - imports) / 1e9)

adjustment_labels <- c("Seasonally adjusted", "Not seasonally adjusted", "Not adjusted, excluding gold")

goods_balance <- bind_rows(
  "Seasonally adjusted" = end_use_adjusted |>
    filter(series == "total_census") |>
    summarise(balance = value[block == "exports"] - value[block == "imports"], .by = date) |>
    mutate(balance = balance / 1e3),
  "Not seasonally adjusted" = goods_balance_unadjusted,
  "Not adjusted, excluding gold" = goods_balance_unadjusted |>
    inner_join(gold_balance, by = "date") |>
    transmute(date, balance = balance - gold),
  .id = "adjustment"
) |>
  filter(date >= balance_start) |>
  arrange(match(adjustment, adjustment_labels), date)

goods_balance |>
  mutate(balance = round(balance, 3)) |>
  mutate(adjustment = snakecase_label(adjustment)) |>
  pivot_wider(names_from = adjustment, values_from = balance) |>
  write_csv(file.path(chart_dir, "output", "goods-balance.csv"))

goods_balance_chart <- goods_balance |>
  mutate(adjustment = factor(adjustment, levels = adjustment_labels)) |>
  ggplot(aes(date, balance, colour = adjustment)) +
  geom_line(linewidth = 0.9) +
  geom_point(data = \(data) filter(data, date == latest_month), size = 2.2) +
  scale_colour_manual(values = unname(chart_colors[c("blue", "orange", "teal")])) +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
  theme_chart()

# Goods in chained dollars -----------------------------------------------------------

# Averages over the quarter so far and the previous full quarter, the comparison
# that feeds quarterly GDP. The balance of chained-dollar series is the
# difference of the two, as BEA reports it.
quarter_start <- floor_date(latest_month, "quarter")
quarter_name <- \(date) str_glue("{year(date)} Q{quarter(date)}")
months_to_date <- if (latest_month == quarter_start) {
  format(latest_month, "%B")
} else {
  str_glue("{format(quarter_start, '%B')} to {format(latest_month, '%B')}")
}
annual_rate <- \(current, previous) sprintf("%+.1f", 100 * ((current / previous)^4 - 1))

real_goods |>
  filter(series == "total", !published_last_month, date >= quarter_start - months(3)) |>
  mutate(period = if_else(date >= quarter_start, "current", "previous")) |>
  summarise(value = mean(value), .by = c(block, period)) |>
  pivot_wider(names_from = block) |>
  mutate(balance = exports - imports) |>
  pivot_longer(-period, names_to = "series") |>
  pivot_wider(names_from = period) |>
  transmute(
    series = c(exports = "Exports", imports = "Imports", balance = "Balance")[series],
    "{quarter_name(quarter_start - months(3))}" := billions(previous),
    "{quarter_name(quarter_start)}, {months_to_date}" := billions(current),
    "Change" := change((current - previous) / 1e3),
    "Percent change, annual rate" := if_else(series == "Balance", "", annual_rate(current, previous))
  ) |>
  markdown_table(file.path(chart_dir, "output", "real-goods.md"))

# What moved -------------------------------------------------------------------

end_use_labels <- c(
  "0" = "Foods, feeds, and beverages",
  "1" = "Industrial supplies",
  "2" = "Capital goods",
  "3" = "Autos and parts",
  "4" = "Consumer goods",
  "5" = "Other goods"
)
view_labels <- c(
  adjusted = str_glue("From {format(previous_month, '%B')}, seasonally adjusted"),
  unadjusted = str_glue("From {format(year_earlier, '%B %Y')}, not seasonally adjusted")
)

end_use_changes <- bind_rows(
  adjusted = end_use_adjusted |>
    filter(series %in% names(end_use_labels), date %in% c(latest_month, previous_month)) |>
    summarise(change = (value[date == latest_month] - value[date == previous_month]) / 1e3, .by = c(block, series)),
  # Exports n.e.c. and reexports (code 6) are part of other goods in the FT-900.
  unadjusted = end_use |>
    filter(level == "EU1", date %in% c(latest_month, year_earlier)) |>
    mutate(code = if_else(code == "6", "5", code)) |>
    summarise(change = (sum(value[date == latest_month]) - sum(value[date == year_earlier])) / 1e9, .by = c(flow, code)) |>
    rename(block = flow, series = code),
  .id = "view"
)

end_use_changes |>
  transmute(view = view_labels[view], flow = block, category = end_use_labels[series], change = round(change, 3)) |>
  write_csv(file.path(chart_dir, "output", "end-use-changes.csv"))

end_use_chart <- end_use_changes |>
  mutate(
    view = factor(view_labels[view], levels = view_labels),
    flow = factor(str_to_sentence(block), levels = c("Imports", "Exports")),
    category = factor(end_use_labels[series], levels = rev(end_use_labels))
  ) |>
  ggplot(aes(change, category, fill = flow)) +
  geom_vline(xintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
  geom_col(position = position_dodge(width = 0.75, reverse = TRUE), width = 0.7) +
  facet_wrap(vars(view), scales = "free_x") +
  scale_fill_manual(values = unname(chart_colors[c("blue", "orange")])) +
  scale_x_continuous(labels = dollars) +
  theme_chart() +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(colour = chart_greys[["grid"]], linewidth = 0.35),
    strip.text = element_text(hjust = 0, size = rel(0.9), colour = chart_greys[["text"]]),
    panel.spacing.x = unit(1.5, "lines")
  )

# Largest changes by product ------------------------------------------------------

# The ten detailed end-use categories with the largest change in dollars from a
# year earlier, for imports and for exports.
product_changes <- end_use |>
  filter(level == "EU5", date %in% c(latest_month, year_earlier)) |>
  summarise(change = (sum(value[date == latest_month]) - sum(value[date == year_earlier])) / 1e9, .by = c(flow, code, description)) |>
  slice_max(abs(change), n = 10, by = flow, with_ties = FALSE) |>
  arrange(flow, change)

product_changes |>
  mutate(change = round(change, 3)) |>
  write_csv(file.path(chart_dir, "output", "product-changes.csv"))

product_label <- \(row) product_changes$description[match(row, str_c(str_to_sentence(product_changes$flow), product_changes$code))]

product_chart <- product_changes |>
  mutate(
    flow = factor(str_to_sentence(flow), levels = c("Imports", "Exports")),
    row = factor(str_c(flow, code), levels = str_c(flow, code))
  ) |>
  ggplot(aes(change, row, fill = change > 0)) +
  geom_vline(xintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
  geom_col(width = 0.7) +
  facet_wrap(vars(flow), scales = "free_y", ncol = 1) +
  scale_y_discrete(labels = product_label) +
  scale_fill_manual(values = c(`TRUE` = chart_colors[["blue"]], `FALSE` = chart_colors[["grey"]]), guide = "none") +
  scale_x_continuous(labels = dollars) +
  theme_chart() +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(colour = chart_greys[["grid"]], linewidth = 0.35),
    strip.text = element_text(hjust = 0, face = "bold", size = rel(0.95), colour = chart_greys[["text"]])
  )

# Computers, chips, and telecom equipment by country ------------------------------------

hardware_groups <- c(computers = "Computers and parts", chips_telecom = "Semiconductors and telecom equipment")

hardware_by_country <- read_census_trade("imports", year_earlier, latest_month) |>
  filter(date %in% c(latest_month, year_earlier)) |>
  select(date, commodity, country_code, gen_val) |>
  summarise(imports = sum(gen_val), .by = c(date, commodity, country_code)) |>
  collect() |>
  mutate(flow = "imports", year = year(date)) |>
  inner_join(filter(product_groups, group %in% names(hardware_groups)), by = c("flow", "year", "commodity")) |>
  summarise(imports = sum(imports) / 1e9, .by = c(date, group, country_code)) |>
  left_join(countries, by = "country_code")

# The eight countries with the most imports of the two groups combined in the
# latest month; the rest are summed.
top_hardware_countries <- hardware_by_country |>
  filter(date == latest_month) |>
  summarise(imports = sum(imports), .by = country) |>
  slice_max(imports, n = 8) |>
  pull(country)

hardware_imports <- hardware_by_country |>
  mutate(country = if_else(country %in% top_hardware_countries, country_name(country), "All other countries")) |>
  summarise(imports = sum(imports), .by = c(date, group, country)) |>
  complete(date, group, country, fill = list(imports = 0))

hardware_imports |>
  arrange(match(group, names(hardware_groups)), date) |>
  mutate(
    group = snakecase_label(hardware_groups[group]),
    date = if_else(date == latest_month, "latest", "year_earlier"),
    imports = round(imports, 3)
  ) |>
  pivot_wider(names_from = c(group, date), values_from = imports) |>
  write_csv(file.path(chart_dir, "output", "hardware-by-country.csv"))

hardware_period_labels <- c(month_short(year_earlier), month_short(latest_month))
# Largest at the top, with all other countries at the bottom.
hardware_country_order <- hardware_imports |>
  filter(date == latest_month) |>
  summarise(imports = sum(imports), .by = country) |>
  arrange(country != "All other countries", imports) |>
  pull(country)

hardware_chart <- hardware_imports |>
  mutate(
    group = factor(hardware_groups[group], levels = hardware_groups),
    period = factor(month_short(date), levels = hardware_period_labels),
    country = factor(country, levels = hardware_country_order)
  ) |>
  ggplot(aes(imports, country)) +
  geom_line(aes(group = country), colour = chart_greys[["grid"]], linewidth = 1.2) +
  geom_point(aes(colour = period), size = 2.4) +
  facet_wrap(vars(group)) +
  scale_colour_manual(values = unname(chart_colors[c("grey", "blue")])) +
  scale_x_continuous(labels = dollars, limits = c(0, NA)) +
  theme_chart() +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(colour = chart_greys[["grid"]], linewidth = 0.35),
    strip.text = element_text(hjust = 0, size = rel(0.9), colour = chart_greys[["text"]]),
    panel.spacing.x = unit(1.5, "lines")
  )

# Partners ------------------------------------------------------------------------

# The change from a year earlier is not seasonally adjusted, from the trade
# store, which names countries as the FT-900 does, in capitals.
partner_balance_unadjusted <- c(imports = "gen_val", exports = "all_val") |>
  imap(\(value, flow) {
    read_census_trade(flow, year_earlier, latest_month) |>
      filter(date %in% c(latest_month, year_earlier)) |>
      select(date, country_code, value = all_of(value)) |>
      summarise(value = sum(value), .by = c(date, country_code)) |>
      collect()
  }) |>
  list_rbind(names_to = "flow") |>
  pivot_wider(names_from = flow, values_from = value, values_fill = 0) |>
  left_join(countries, by = "country_code") |>
  transmute(country, date, balance = (exports - imports) / 1e6)

# The twelve countries with the largest balances either way. The exhibit's
# areas, such as the European Union, overlap with them and are left out.
partners <- partners_adjusted |>
  filter(block == "balance", str_to_upper(country) %in% countries$country) |>
  mutate(date = if_else(date == latest_month, "latest", "previous")) |>
  pivot_wider(names_from = date) |>
  slice_max(abs(latest), n = 12) |>
  mutate(key = str_to_upper(country)) |>
  left_join(
    partner_balance_unadjusted |>
      mutate(date = if_else(date == latest_month, "latest_unadjusted", "year_earlier_unadjusted")) |>
      pivot_wider(names_from = date, values_from = balance),
    by = join_by(key == country)
  ) |>
  arrange(latest)

partners |>
  transmute(
    country,
    balance_adjusted = latest,
    balance_previous_month_adjusted = previous,
    balance_unadjusted = latest_unadjusted,
    balance_year_earlier_unadjusted = year_earlier_unadjusted
  ) |>
  mutate(across(where(is.numeric), \(x) round(x / 1e3, 3))) |>
  write_csv(file.path(chart_dir, "output", "partners.csv"))

partners |>
  transmute(
    country = country_name(country),
    "Balance, {month_short(latest_month)}" := billions(latest),
    "From {month_short(previous_month)}" := change((latest - previous) / 1e3),
    "From {month_short(year_earlier)}, not adjusted" := change((latest_unadjusted - year_earlier_unadjusted) / 1e3)
  ) |>
  markdown_table(file.path(chart_dir, "output", "partners.md"))

# Tariffs -----------------------------------------------------------------------

duties <- read_census_trade("imports", latest_month - months(24), latest_month) |>
  select(date, country_code, con_val, cal_dut) |>
  summarise(across(everything(), sum), .by = c(date, country_code)) |>
  collect()

duties_by_month <- duties |>
  summarise(duties = sum(cal_dut) / 1e9, rate = 100 * sum(cal_dut) / sum(con_val), .by = date) |>
  arrange(date)

duties_by_month |>
  mutate(across(-date, \(x) round(x, 3))) |>
  write_csv(file.path(chart_dir, "output", "duties.csv"))

duties_chart <- duties_by_month |>
  ggplot(aes(date, duties)) +
  geom_col(aes(fill = date == latest_month), width = 25) +
  geom_hline(yintercept = 0, colour = chart_greys[["baseline"]], linewidth = 0.4) +
  scale_fill_manual(values = c(`TRUE` = chart_colors[["blue"]], `FALSE` = chart_colors[["grey"]]), guide = "none") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
  scale_y_continuous(labels = dollars) +
  theme_chart()

duties |>
  filter(date %in% c(latest_month, year_earlier)) |>
  summarise(
    duties = sum(cal_dut[date == latest_month]) / 1e9,
    duties_year_earlier = sum(cal_dut[date == year_earlier]) / 1e9,
    rate = 100 * sum(cal_dut[date == latest_month]) / sum(con_val[date == latest_month]),
    .by = country_code
  ) |>
  slice_max(duties, n = 10) |>
  left_join(countries, by = "country_code") |>
  transmute(
    country = country_name(country),
    "Duties, {month_short(latest_month)}" := sprintf("%.2f", duties),
    "{month_short(year_earlier)}" := sprintf("%.2f", duties_year_earlier),
    "Tariff rate, %" := sprintf("%.1f", rate)
  ) |>
  markdown_table(file.path(chart_dir, "output", "duties-by-country.md"))

# Charts --------------------------------------------------------------------------

# Each chart is saved wide and narrow. The narrow version stacks panels, wraps
# long category names, and spaces dates further apart.
narrow_dates <- scale_x_date(date_breaks = "6 months", date_labels = "%b\n%Y")
source_line <- "Source: Census Bureau."
charts <- tribble(
  ~name, ~chart, ~narrow, ~title, ~subtitle, ~height, ~narrow_height,
  "goods-balance", goods_balance_chart, list(narrow_dates, guides(colour = guide_legend(ncol = 1))),
  "U.S. goods trade balance", "Census basis, billions of dollars a month", 5, 5.5,
  "end-use-changes", end_use_chart, list(facet_wrap(vars(view), ncol = 1, scales = "free_x"), scale_y_discrete(labels = \(x) str_wrap(x, 18))),
  "Change in U.S. goods trade by category", "Billions of dollars", 4.5, 7.5,
  "product-changes", product_chart, list(scale_y_discrete(labels = \(x) str_wrap(product_label(x), 24)), theme(axis.text.y = element_text(lineheight = 0.85))),
  "Largest changes in U.S. goods trade by product",
  str_glue("Change from {format(year_earlier, '%B %Y')}, billions of dollars, not seasonally adjusted"), 6.5, 11,
  "hardware-by-country", hardware_chart, list(facet_wrap(vars(group), ncol = 1, labeller = label_wrap_gen(30))),
  "U.S. imports of computers, chips, and telecom equipment by country",
  "Billions of dollars a month, not seasonally adjusted", 5, 8,
  "duties", duties_chart, list(narrow_dates),
  "Duties on U.S. imports", "Calculated duties, billions of dollars a month, not seasonally adjusted", 4.5, 4.5
)

pwalk(charts, \(name, chart, narrow, title, subtitle, height, narrow_height) {
  save_chart(
    chart + chart_labels(title, subtitle, source_line, width = 8),
    file.path(chart_dir, "output", str_glue("{name}.png")),
    width = 8,
    height = height
  )
  save_chart(
    # A right margin keeps the last axis label from being cut off.
    chart + narrow + theme(plot.margin = margin(18, 12, 12, 0)) + chart_labels(title, subtitle, source_line, width = 4.2),
    file.path(chart_dir, "output", str_glue("{name}-narrow.png")),
    width = 4.2,
    height = narrow_height
  )
})
