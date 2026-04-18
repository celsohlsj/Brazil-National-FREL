# ============================================================
# Brazil National FREL — GEE Export Consolidation Tool (v1)
#
# Reference:
#   Silva-Junior, C. H. L. et al. (2026). Increased deforestation
#   and forest degradation jeopardize Brazil's REDD+ results in 2022.
#   Nature Communications.
#
# Description:
#   Reads all CSV files exported by code_all_biomes_v1.js,
#   parses their filenames to extract metadata (biome, disturbance,
#   gas, year), applies human-readable labels, and writes a single
#   consolidated Excel workbook.
#
# Input  : {RESULTS_PATH}/{biome}_emission_{dist}_{gas}_{year}.csv
# Output : {RESULTS_PATH}/0_brazil_national_frel_results_v1.xlsx
#
# File naming convention (from code_all_biomes_v1.js):
#   Biome codes  : amz | cerr | pan | pam | caa | ma
#   Disturbances : def | fire | sl
#   Gases        : co2 | ch4 | n2o
# ============================================================

# ====================================================================
#  CONFIGURATION — Edit only this section
#  Must match START_YEAR / END_YEAR / EXPORT_FOLDER in
#  code_all_biomes_v1.js
# ====================================================================

# Cross-platform path to the folder containing the GEE-exported CSVs
# Use forward slashes or file.path() — works on Windows, Mac and Linux
RESULTS_PATH <- file.path("~", "Brazil-National-FREL-Results_V1")

START_YEAR <- 2017L   # First year of analysis (inclusive)
END_YEAR   <- 2023L   # Last year  of analysis (inclusive)

# ====================================================================
#  END OF CONFIGURATION
# ====================================================================

# ── Packages ──────────────────────────────────────────────────────────
if (!requireNamespace("pacman", quietly = TRUE))
  install.packages("pacman")

pacman::p_load(dplyr, readr, openxlsx, stringr)

# ── Label lookup tables (aligned with code_all_biomes_v1.js) ─────────
BIOME_LABELS <- c(
  amz  = "Amazon",
  cerr = "Cerrado",
  pan  = "Pantanal",
  pam  = "Pampa",
  caa  = "Caatinga",
  ma   = "Atlantic Forest"
)

DISTURBANCE_LABELS <- c(
  def  = "Deforestation",
  fire = "Fire",
  sl   = "Selective Logging"
)

GAS_LABELS <- c(
  co2 = "CO2",
  ch4 = "CH4",
  n2o = "N2O"
)

# Helper: look up a code in a named vector; fall back to the raw code
lookup <- function(code, table) {
  hit <- table[code]
  if (!is.na(hit)) unname(hit) else code
}

# ── Validate results path ─────────────────────────────────────────────
if (!dir.exists(RESULTS_PATH)) {
  stop(sprintf(
    "Results folder not found:\n  %s\nCheck RESULTS_PATH in the configuration block.",
    RESULTS_PATH
  ))
}

# ── Discover CSV files ────────────────────────────────────────────────
files <- list.files(path = RESULTS_PATH, pattern = "\\.csv$", full.names = TRUE)

if (length(files) == 0)
  stop(sprintf("No CSV files found in:\n  %s", RESULTS_PATH))

cat(sprintf("Found %d CSV file(s) in:\n  %s\n\n", length(files), RESULTS_PATH))

# ── Parse filenames and read data ─────────────────────────────────────
# Expected pattern: {biome}_emission_{disturbance}_{gas}_{year}.csv
FILE_REGEX <- "^([a-z]+)_emission_([a-z]+)_([a-z0-9]+)_(\\d{4})\\.csv$"

result_list <- vector("list", length(files))
n_skipped   <- 0L

for (i in seq_along(files)) {

  fname <- basename(files[i])

  # ── Match filename ─────────────────────────────────────────────
  m <- str_match(fname, FILE_REGEX)

  if (is.na(m[1, 1])) {
    warning(sprintf("Skipping '%s': does not match expected filename pattern.", fname))
    n_skipped <- n_skipped + 1L
    next
  }

  biome_code <- m[1, 2]
  dist_code  <- m[1, 3]
  gas_code   <- m[1, 4]
  year       <- as.integer(m[1, 5])

  # ── Filter by analysis period ──────────────────────────────────
  if (year < START_YEAR || year > END_YEAR) next

  # ── Read CSV (silently drop the .geo geometry column) ──────────
  data <- tryCatch(
    read_csv(files[i], col_types = cols(.geo = col_skip()), show_col_types = FALSE),
    error = function(e) {
      warning(sprintf("Could not read '%s': %s", fname, conditionMessage(e)))
      NULL
    }
  )

  if (is.null(data)) {
    n_skipped <- n_skipped + 1L
    next
  }

  # ── Validate required columns ──────────────────────────────────
  required     <- c("sum", "NM_UF", "Bioma")
  missing_cols <- setdiff(required, names(data))

  if (length(missing_cols) > 0) {
    warning(sprintf(
      "Skipping '%s': missing column(s): %s",
      fname, paste(missing_cols, collapse = ", ")
    ))
    n_skipped <- n_skipped + 1L
    next
  }

  # ── Build row with human-readable labels ───────────────────────
  result_list[[i]] <- data.frame(
    biome            = lookup(biome_code, BIOME_LABELS),
    biome_code       = biome_code,
    state            = data$NM_UF,
    disturbance      = lookup(dist_code, DISTURBANCE_LABELS),
    disturbance_code = dist_code,
    gas              = lookup(gas_code, GAS_LABELS),
    gas_code         = gas_code,
    year             = year,
    emission_tCO2e   = data$sum,
    stringsAsFactors = FALSE
  )

  cat(sprintf("  [%3d/%3d]  %-52s OK\n", i, length(files), fname))
}

# ── Combine ───────────────────────────────────────────────────────────
result_table <- bind_rows(result_list)

if (nrow(result_table) == 0)
  stop("No valid data was loaded. Check RESULTS_PATH and file format.")

result_table <- result_table %>%
  arrange(year, biome, disturbance, gas, state)

# ── Summary ───────────────────────────────────────────────────────────
cat(sprintf("\n%s\n", strrep("-", 55)))
cat(sprintf("  Files processed : %d / %d\n", length(files) - n_skipped, length(files)))
cat(sprintf("  Files skipped   : %d\n",      n_skipped))
cat(sprintf("  Total rows      : %d\n",      nrow(result_table)))
cat(sprintf("  Years covered   : %s\n",      paste(sort(unique(result_table$year)),        collapse = ", ")))
cat(sprintf("  Biomes          : %s\n",      paste(sort(unique(result_table$biome)),       collapse = ", ")))
cat(sprintf("  Disturbances    : %s\n",      paste(sort(unique(result_table$disturbance)), collapse = ", ")))
cat(sprintf("  Gases           : %s\n",      paste(sort(unique(result_table$gas)),         collapse = ", ")))
cat(sprintf("%s\n", strrep("-", 55)))

# ── Export to Excel ───────────────────────────────────────────────────
out_file <- file.path(RESULTS_PATH, "0_brazil_national_frel_results_v1.xlsx")

write.xlsx(result_table, file = out_file, rowNames = FALSE, overwrite = TRUE)

cat(sprintf("\nExcel saved:\n  %s\n", out_file))
