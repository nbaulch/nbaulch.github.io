# Checks the share against the numbers in Kevin Warsh's Jackson Hole remarks,
# August 28, 2026, for July 2026.

library(dplyr)
library(readr)
library(lubridate)

breadth <- read_csv("charts/inflation-breadth/output/inflation-breadth.csv", show_col_types = FALSE)
july <- filter(breadth, date == ymd("2026-07-01"))

tribble(
  ~check, ~published, ~ours,
  "Share above 3 percent, 12 months to July", 54, july$twelve_month,
  "Same, 2000 to 2019 average", 32, mean(breadth$twelve_month[between(year(breadth$date), 2000, 2019)]),
  "Same, 2022 peak", 77, max(breadth$twelve_month[year(breadth$date) == 2022]),
  "Share above 3 percent, 6 months annualized", 49, july$six_month
) |>
  mutate(ours = round(ours, 1), matches = abs(published - ours) < 1) |>
  print(width = Inf)
