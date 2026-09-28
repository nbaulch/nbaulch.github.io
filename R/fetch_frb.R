# Daily decomposition of 5- and 10-year nominal Treasury yields and inflation
# compensation from the D'Amico, Kim, and Wei model, updated monthly by Board
# staff. Rates in percent. The file opens with a block of notes; the data start
# at the header row that begins with "date".
# https://www.federalreserve.gov/econres/notes/feds-notes/tips-from-tips-update-and-discussions-20190521.html
fetch_frb_dkw <- function() {
  lines <- read_lines("https://www.federalreserve.gov/econres/notes/feds-notes/DKW_updates.csv")

  read_csv(I(lines[str_which(lines, '^"date"'):length(lines)]), show_col_types = FALSE) |>
    rename_with(\(name) str_replace_all(name, "\\.", "_")) |>
    mutate(date = ymd(date))
}
