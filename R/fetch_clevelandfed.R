# Median PCE inflation from the Cleveland Fed: the monthly percent change and
# the change over 12 months, in percent.
# https://www.clevelandfed.org/indicators-and-data/median-pce-inflation
fetch_clevelandfed_median_pce <- function() {
  read_csv(
    "https://www.clevelandfed.org/-/media/files/webcharts/medianpce/median-pce-full-history.csv",
    na = "NaN",
    show_col_types = FALSE
  ) |>
    transmute(
      date = mdy(Date),
      monthly = `Median PCE Inflation, monthly percent change`,
      twelve_month = `Median PCE Inflation, year-over-year percent change`
    )
}
