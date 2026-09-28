# Splits business sector labor productivity growth into the parts identified in
# Fernald's data. Deepening, TFP, and utilization sum to dLP each quarter.
# Deepening is also split by asset: information processing equipment and
# software, where AI investment shows up, and everything else. The first
# includes all computers and software, not only AI.
labor_productivity_contributions <- function(tfp, capital) {
  tfp |>
    left_join(capital, by = "date", suffix = c("", "_capital")) |>
    mutate(
      it_weight = wgt_info_processing_equip + wgt_software,
      it_capital_growth = wgt_info_processing_equip * dk_info_processing_equip +
        wgt_software * dk_software,
      it_capital_deepening = alpha * (it_capital_growth - it_weight * dhours)
    ) |>
    transmute(
      date,
      labor_productivity = dLP,
      deepening = alpha * (dk - dhours) + (1 - alpha) * dLQ,
      other_deepening = alpha * (dk - dhours) - it_capital_deepening + (1 - alpha) * dLQ,
      it_capital_deepening,
      tfp_util_adjusted = dtfp_util,
      utilization = dutil
    ) |>
    pivot_longer(-date, names_to = "series", values_to = "growth") |>
    arrange(series, date) |>
    mutate(
      four_quarter_mean = slide_dbl(growth, mean, .before = 3, .complete = TRUE),
      .by = series
    ) |>
    select(-growth)
}
