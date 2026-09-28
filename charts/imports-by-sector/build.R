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

chart_dir <- "charts/imports-by-sector"
base_year <- 2024

# The deficit chart's groups come first, so each product sits in one row.
# Other sectors follow the product codes that tariffs are set on. Gold is left
# out: it faces no tariff, and it is on the deficit chart.
sectors <- c(
  computers = "Computers and parts",
  chips_telecom = "Semiconductors and telecom equipment",
  pharmaceuticals = "Pharmaceuticals",
  cell_phones = "Cell phones",
  passenger_vehicles = "Passenger vehicles",
  trucks = "Trucks and vans",
  vehicle_parts = "Vehicle parts",
  steel = "Steel",
  aluminum = "Aluminum",
  copper = "Copper",
  machinery = "Machinery",
  electrical_equipment = "Electrical equipment",
  furniture = "Furniture",
  apparel = "Apparel and footwear",
  food_farm = "Food and farm goods",
  energy = "Energy"
)

sector_of <- function(commodity, description, end_use) {
  group <- product_group(commodity, description, end_use)
  chapter <- as.integer(str_sub(commodity, 1, 2))
  heading <- str_sub(commodity, 1, 4)
  case_when(
    group == "gold" ~ NA_character_,
    group != "other" ~ group,
    str_starts(commodity, "851713") ~ "cell_phones",
    heading == "8703" ~ "passenger_vehicles",
    heading == "8704" ~ "trucks",
    heading == "8708" ~ "vehicle_parts",
    chapter %in% c(72, 73) ~ "steel",
    chapter == 76 ~ "aluminum",
    chapter == 74 ~ "copper",
    chapter == 84 ~ "machinery",
    chapter == 85 ~ "electrical_equipment",
    heading %in% c("9401", "9403", "9404") ~ "furniture",
    chapter %in% c(61, 62, 64) ~ "apparel",
    chapter <= 24 ~ "food_farm",
    chapter == 27 ~ "energy",
    .default = NA_character_
  )
}

latest_month <- read_census_trade_manifest() |>
  filter(flow == "imports") |>
  pull(date) |>
  max()
recent_start <- latest_month - months(11)
periods <- tibble(
  date = c(seq(make_date(base_year), make_date(base_year, 12), by = "month"), seq(recent_start, latest_month, by = "month")),
  period = rep(c("base", "recent"), each = 12)
)

product_sectors <- read_census_trade_codes("imports", year(periods$date)) |>
  transmute(year, commodity, sector = sector_of(commodity, description, end_use)) |>
  filter(!is.na(sector))

# General imports for the value, as in the deficit chart; imports for
# consumption for the tariff rate, since duty is assessed on them.
imports_by_sector <- read_census_trade("imports", make_date(base_year), latest_month) |>
  filter(date %in% periods$date) |>
  select(date, commodity, gen_val, con_val, cal_dut) |>
  summarise(across(everything(), sum), .by = c(date, commodity)) |>
  collect() |>
  mutate(year = year(date)) |>
  inner_join(product_sectors, by = c("year", "commodity")) |>
  inner_join(periods, by = "date") |>
  summarise(across(c(gen_val, con_val, cal_dut), sum), .by = c(sector, period)) |>
  arrange(sector, period)

write_csv(imports_by_sector, file.path(chart_dir, "data", str_glue("census_imports_by_sector_{latest_month}.csv")))

sector_imports <- imports_by_sector |>
  transmute(sector, period, imports = gen_val / 1e9, tariff_rate = 100 * cal_dut / con_val) |>
  pivot_wider(names_from = period, values_from = c(imports, tariff_rate)) |>
  mutate(label = sectors[sector], imports_change = 100 * (imports_recent / imports_base - 1)) |>
  arrange(imports_recent)

sector_imports |>
  select(sector = label, imports_base, imports_recent, imports_change, tariff_rate_base, tariff_rate_recent) |>
  mutate(across(where(is.numeric), \(x) round(x, 3))) |>
  write_csv(file.path(chart_dir, "output", "imports-by-sector.csv"))

recent_label <- str_glue("{format(recent_start, '%B %Y')} to {format(latest_month, '%B %Y')}")
period_labels <- c(base = as.character(base_year), recent = "Latest 12 months")

write_chart_notes(
  notes = c(
    str_glue("**{base_year}:** Imports in calendar {base_year}."),
    str_glue("**Latest 12 months:** Imports from {recent_label}."),
    "**Tariff rate:** Duties calculated on the sector's imports as a percent of their value, in the same two periods."
  ),
  source = str_glue(
    "Source: Census Bureau, U.S. imports of merchandise by product, through {format(latest_month, '%B %Y')}. ",
    "Sectors are defined by product code."
  ),
  csv_path = file.path(chart_dir, "output", "imports-by-sector.csv"),
  path = file.path(chart_dir, "output", "imports-by-sector-notes.md")
)

rate_label <- \(x) if_else(x < 10, sprintf("%.1f", x), sprintf("%.0f", x))
change_label <- \(x) if_else(round(x) == 0, "0", sprintf("%+.0f", x))

chart_data <- sector_imports |>
  mutate(label = factor(label, levels = label))

# The change and tariff columns sit to the right of the plotted range. On a
# log scale, they are placed by multiplying rather than adding.
import_range <- range(chart_data$imports_base, chart_data$imports_recent)
import_breaks <- c(10, 20, 50, 100, 200, 500, 1000)
import_breaks <- import_breaks[between(import_breaks, import_range[1] * 0.8, import_range[2] * 1.5)]
column_x <- max(import_breaks) * c(3, 4.9)
table_columns <- chart_data |>
  transmute(label, base = rate_label(tariff_rate_base), recent = rate_label(tariff_rate_recent)) |>
  pivot_longer(-label, values_to = "text") |>
  mutate(x = column_x[match(name, c("base", "recent"))])
column_header <- function(x, y, label, fontface = "plain") {
  annotate(
    "text",
    x = x, y = y, label = label, hjust = 1, size = 3.1, fontface = fontface,
    colour = chart_greys[["text"]], family = "Roboto Chart"
  )
}
top <- nrow(chart_data)

sector_chart <- chart_data |>
  pivot_longer(c(imports_base, imports_recent), names_to = "period", values_to = "imports") |>
  mutate(period = factor(period_labels[str_remove(period, "imports_")], levels = period_labels)) |>
  ggplot(aes(imports, label)) +
  geom_vline(xintercept = import_breaks, colour = chart_greys[["grid"]], linewidth = 0.35) +
  geom_line(aes(group = label), colour = chart_greys[["grid"]], linewidth = 1.2) +
  geom_point(aes(colour = period), size = 2.6) +
  geom_text(
    data = table_columns,
    aes(x = x, label = text),
    hjust = 1, size = 3.1, colour = chart_greys[["text"]], family = "Roboto Chart"
  ) +
  # The change sits just past the latest dot, on the side away from the 2024 one.
  geom_text(
    aes(
      x = imports_recent * if_else(imports_change >= 0, 1.1, 1 / 1.1),
      label = str_c(change_label(imports_change), "%"),
      hjust = if_else(imports_change >= 0, 0, 1)
    ),
    data = chart_data,
    size = 2.9, colour = chart_colors[["blue"]], family = "Roboto Chart"
  ) +
  column_header(column_x[2], top + 1.6, "Tariff rate, %", "bold") +
  column_header(column_x[1], top + 0.8, as.character(base_year)) +
  column_header(column_x[2], top + 0.8, "Latest") +
  scale_colour_manual(values = c(chart_colors[["grey"]], chart_colors[["blue"]])) +
  scale_x_log10(breaks = import_breaks, labels = \(x) str_c("$", x)) +
  scale_y_discrete(expand = expansion(add = c(0.6, 2))) +
  coord_cartesian(xlim = c(import_range[1] * 0.65, column_x[2]), clip = "off") +
  theme_chart() +
  theme(panel.grid.major.y = element_blank())

title <- "U.S. imports by sector"
subtitle <- "Billions of dollars a year, log scale; labels give the percent change"
source_line <- "Source: Census Bureau."

save_chart(
  sector_chart + chart_labels(title, subtitle, source_line, width = 8),
  file.path(chart_dir, "output", "imports-by-sector.png"),
  width = 8,
  height = 6.5
)
