# The PCE categories the Dallas Fed uses for its trimmed mean, with this month's
# 1-month annualized price change, spending weight, and whether the category
# was trimmed. The download lists 177 categories by their BEA names.
# https://www.dallasfed.org/research/pce
fetch_dallasfed_trimmed_mean_components <- function() {
  download <- tempfile(fileext = ".xlsx")
  download.file("https://www.dallasfed.org/~/media/documents/research/pce/detail", download, mode = "wb", quiet = TRUE)

  read_excel(download, skip = 1, col_names = c("category", "monthly_annualized", "weight", "cumulative_weight", "blank", "status")) |>
    filter(!is.na(category)) |>
    transmute(category, monthly_annualized = as.numeric(monthly_annualized), weight = as.numeric(weight), status)
}
