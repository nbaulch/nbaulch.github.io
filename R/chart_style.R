# House chart style. STYLE.md explains the choices.

chart_colors <- c(
  blue = "#1f6fb2",
  orange = "#d9731f",
  teal = "#1a9a8a",
  red = "#c8453c",
  purple = "#7b5ea7",
  gold = "#d4a62a",
  grey = "#b8b6b0"
)

chart_greys <- c(
  title = "#222220",
  text = "#4a4a47",
  muted = "#75746f",
  baseline = "#3a3a38",
  grid = "#e6e5e1"
)

# Bundled so charts render the same on any machine without installing fonts.
# Registered under its own name so it can't clash with an installed Roboto.
systemfonts::register_font(
  "Roboto Chart",
  plain = "fonts/Roboto-Regular.ttf",
  bold = "fonts/Roboto-Bold.ttf"
)

theme_chart <- function(base_size = 12) {
  theme_minimal(base_size = base_size, base_family = "Roboto Chart") +
    theme(
      text = element_text(colour = chart_greys[["text"]]),
      plot.title = element_text(
        face = "bold",
        size = rel(1.45),
        colour = chart_greys[["title"]],
        margin = margin(b = 6)
      ),
      plot.subtitle = element_text(size = rel(1.05), margin = margin(b = 14)),
      plot.caption = element_text(
        size = rel(0.85),
        colour = chart_greys[["muted"]],
        hjust = 0,
        lineheight = 1.3,
        margin = margin(t = 16)
      ),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      axis.title = element_blank(),
      axis.text = element_text(size = rel(0.9), colour = chart_greys[["muted"]]),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(colour = chart_greys[["grid"]], linewidth = 0.35),
      legend.position = "top",
      legend.location = "plot",
      legend.justification = "left",
      legend.box.just = "left",
      legend.title = element_blank(),
      legend.text = element_text(size = rel(0.9)),
      legend.key.size = unit(0.9, "lines"),
      legend.margin = margin(b = 4),
      # No side margins, so the title and source line up with the page text around the image.
      plot.margin = margin(18, 4, 12, 0),
      plot.background = element_rect(fill = "white", colour = NA)
    )
}

# Wraps the title, subtitle, and short source line to fit a chart `width`
# inches wide. The characters per inch match the text sizes in theme_chart().
# Definitions and the full source go on the page instead; see write_chart_notes().
chart_labels <- function(title, subtitle, source, width) {
  text_width <- width - 0.4
  labs(
    title = wrap_without_orphan(title, floor(text_width * 8.5)),
    subtitle = wrap_without_orphan(subtitle, floor(text_width * 12)),
    caption = wrap_without_orphan(source, floor(text_width * 15.5))
  )
}

# Wraps text to `width` characters, narrowing the wrap until the last line has
# at least two words, so no word sits alone on a line.
wrap_without_orphan <- function(text, width) {
  wrapped <- stringr::str_wrap(text, width)
  last_line <- stringr::str_extract(wrapped, "[^\n]*$")
  if (stringr::str_detect(wrapped, "\n") && !stringr::str_detect(last_line, " ")) {
    wrap_without_orphan(text, width - 1)
  } else {
    wrapped
  }
}

# Notes for each chart's entry on the sources page, written as a Markdown file
# the page includes, so dates in it update when the chart is rebuilt:
# definitions, then a lighter source line with the data download. readr writes
# UTF-8 whatever the locale, so dashes survive in the cloud container.
write_chart_notes <- function(notes, source, csv_path, path) {
  readr::write_lines(
    c(
      "::: {.chart-notes}",
      "",
      stringr::str_c(stringr::str_replace(notes, "^\\*\\*(.+?):\\*\\* ", "\\1\n:   "), collapse = "\n\n"),
      "",
      "::: {.chart-source}",
      stringr::str_glue("{source} [Download the data (CSV)]({csv_path})"),
      ":::",
      "",
      ":::"
    ),
    path
  )
}

save_chart <- function(plot, path, width, height) {
  ggsave(path, plot, device = ragg::agg_png, width = width, height = height, dpi = 200)
}
