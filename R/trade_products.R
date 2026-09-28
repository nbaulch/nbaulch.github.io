# Product groups for charts built on the Census trade store: Census end-use
# categories, except gold. Census files gold bars under 7115 ("articles of
# precious metal") in finished metal shapes, not nonmonetary gold, so gold is
# taken from the product codes and their descriptions.
product_group <- function(commodity, description, end_use) {
  case_when(
    str_starts(commodity, "7108") | (str_starts(commodity, "7115") & str_detect(description, "GOLD")) ~ "gold",
    end_use %in% c("21300", "21301") ~ "computers",
    end_use %in% c("21320", "21400") ~ "chips_telecom",
    end_use == "40100" ~ "pharmaceuticals",
    .default = "other"
  )
}
