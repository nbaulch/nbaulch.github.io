# Price index for an aggregate with one component taken out, found by solving
# BEA's monthly Fisher formula for the remainder's price change. It reproduces
# BEA's published market-based core from market-based PCE to within 0.02 point.
index_excluding <- function(price, spending, part_price, part_spending) {
  aggregate_change <- price / lag(price)
  part_change <- part_price / lag(part_price)
  share_before <- lag(part_spending / spending)
  share_after <- part_spending / spending
  a <- 1 - share_before
  b <- share_before * part_change - aggregate_change^2 * share_after / part_change
  c <- -aggregate_change^2 * (1 - share_after)
  cumprod(coalesce((-b + sqrt(b^2 - 4 * a * c)) / (2 * a), 1))
}
