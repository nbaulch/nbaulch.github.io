# Month-end yield curve in long form, from a FRED download whose columns are
# named by maturity in years. Uses the last observation in each month.
month_end_curve <- function(fred_yields) {
  fred_yields |>
    pivot_longer(-date, names_to = "maturity", values_to = "yield", names_transform = as.numeric) |>
    filter(!is.na(yield)) |>
    mutate(date = ceiling_date(date, "month") - days(1)) |>
    slice_max(order_by = row_number(), by = c(date, maturity)) |>
    arrange(date, maturity)
}

# Yield at `years` by linear interpolation along one date's curve, flat beyond
# its shortest and longest maturities.
interpolate_yield <- function(curve, years) {
  approx(curve$maturity, curve$yield, xout = years, rule = 2)$y
}

# Modified duration, in years, of a bond paying `coupon` percent semiannually
# and maturing in `years`, priced at `yield` percent compounded semiannually.
bond_duration <- function(coupon, years, yield) {
  payment_times <- rev(seq(years, 0, by = -0.5))
  payment_times <- payment_times[payment_times > 0]
  cash_flows <- rep(coupon / 2, length(payment_times))
  cash_flows[length(cash_flows)] <- cash_flows[length(cash_flows)] + 100
  present_values <- cash_flows / (1 + yield / 200)^(2 * payment_times)
  sum(payment_times * present_values) / sum(present_values) / (1 + yield / 200)
}

# Adds each security's modified duration and the duration of a new 10-year
# note on the same date, which converts holdings into 10-year equivalents.
# Bills are zero-coupon; floating rate notes reset weekly, so their duration is
# taken as zero; inflation-protected securities are priced off real yields.
add_modified_duration <- function(holdings, curves) {
  curve_on <- curves |>
    nest(points = c(maturity, yield), .by = c(date, curve))

  ten_year_duration <- curves |>
    filter(curve == "nominal", maturity == 10) |>
    mutate(ten_year_duration = map_dbl(yield, \(y) bond_duration(y, 10, y))) |>
    select(date, ten_year_duration)

  holdings |>
    mutate(curve = if_else(type == "inflation_protected", "real", "nominal")) |>
    inner_join(curve_on, by = c("date", "curve")) |>
    mutate(
      yield = map2_dbl(points, years_to_maturity, interpolate_yield),
      modified_duration = case_when(
        type == "bill" ~ years_to_maturity / (1 + yield / 200),
        type == "floating_rate" ~ 0,
        .default = pmap_dbl(list(coalesce(coupon, 0), years_to_maturity, yield), bond_duration)
      )
    ) |>
    select(-points, -curve) |>
    inner_join(ten_year_duration, by = "date")
}
