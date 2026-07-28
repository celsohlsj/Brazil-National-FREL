# ============================================================
# Brazil National FREL — README Table Updater
#
# Reads:  data/fig1_data.csv
# Writes: README.md (replaces the table between the
#         <!-- FREL_TABLE_START --> / <!-- FREL_TABLE_END --> markers)
#
# Run from repository root:
#   Rscript codes/update_readme_table.R
#
# The table is also regenerated automatically by GitHub Actions
# whenever data/fig1_data.csv is pushed (.github/workflows/update_fig1.yml).
# ============================================================

if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(dplyr, readr)

data <- read_csv("data/fig1_data.csv", show_col_types = FALSE)

frel_mt <- data$frel_Mt[1]

post_baseline <- data %>%
  filter(type == "Estimated") %>%
  arrange(year)

fmt_signed <- function(x, digits = 1) {
  sign <- ifelse(x >= 0, "+", "−")
  paste0(sign, formatC(abs(x), format = "f", digits = digits))
}

delta <- frel_mt - post_baseline$emission_Mt
pct   <- delta / frel_mt * 100

rows <- sprintf(
  "| %d | %s | **%s** | **%s %%** |",
  post_baseline$year,
  formatC(post_baseline$emission_Mt, format = "f", digits = 1),
  fmt_signed(delta),
  fmt_signed(pct)
)

table_lines <- c(
  "<!-- FREL_TABLE_START -->",
  "| Year | Emissions (Mt CO₂eq) | FREL − Emissions (Mt CO₂eq) | FREL − Emissions (%) |",
  "|:----:|---------------------:|----------------------------:|---------------------:|",
  rows,
  "<!-- FREL_TABLE_END -->"
)

readme <- readLines("README.md", warn = FALSE, encoding = "UTF-8")
start_idx <- grep("<!-- FREL_TABLE_START -->", readme, fixed = TRUE)
end_idx   <- grep("<!-- FREL_TABLE_END -->", readme, fixed = TRUE)

if (length(start_idx) != 1 || length(end_idx) != 1) {
  stop("README.md must contain exactly one FREL_TABLE_START/END marker pair.")
}

new_readme <- c(
  readme[seq_len(start_idx - 1)],
  table_lines,
  readme[seq(end_idx + 1, length(readme))]
)

con <- file("README.md", "w", encoding = "UTF-8")
writeLines(new_readme, con, useBytes = TRUE)
close(con)

cat("README.md table updated.\n")
