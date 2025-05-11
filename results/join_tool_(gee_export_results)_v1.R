# Load necessary packages
if (!requireNamespace("pacman", quietly = TRUE))
  install.packages("pacman")

pacman::p_load(dplyr, openxlsx, readr)

library(dplyr)
library(openxlsx)
library(readr)

# Define the file path
file_path <- "C:\\Brazil-National-FREL-Results_V1"

if (!dir.exists(file_path)) {
  dir.create(file_path, recursive = TRUE)
}

# List all CSV files in the directory
files <- list.files(path = file_path, pattern = "*.csv", full.names = TRUE)
total_files <- length(files)

# Initialize a list to store results
result_list <- vector("list", length = total_files)

# Loop to process each file
for (i in seq_along(files)) {
  # Extract and parse the filename
  file_name <- basename(files[i])
  file_name <- gsub(".csv", "", file_name)
  info <- strsplit(file_name, "_")[[1]]
  
  # Check if the filename has the expected format
  if (length(info) < 5) {
    warning(sprintf("Filename %s does not have the expected format. Skipping.", file_name))
    next
  }
  
  # Extract information from the filename
  disturbio <- info[3]
  gas <- info[4]
  ano <- info[5]
  
  # Read the CSV file, skipping the '.geo' column
  data <- read_csv(files[i], col_types = cols(.geo = col_skip()))
  
  # Check for required columns
  required_columns <- c("sum", "NM_UF", "Bioma")
  if (!all(required_columns %in% names(data))) {
    warning(sprintf("File %s is missing required columns. Skipping.", file_name))
    next
  }
  
  # Create a data frame with extracted information
  result <- data.frame(
    biome = data$Bioma, # Brazil's Biome
    state = data$NM_UF, # Brazil's States
    disturbance = rep(disturbio, nrow(data)), # Disturbance: Forest Fire, Selective Logging and Deforestation
    gas = rep(gas, nrow(data)), # GEE: CO2, CH4 and N2O
    year = rep(ano, nrow(data)), # Year
    emission_tco2eq = data$sum # Emission value (t CO2eq)
  )
  
  # Store the result in the list
  result_list[[i]] <- result
  
  # Print progress
  cat(sprintf("Processed %d of %d files (%.2f%%)\n", i, total_files, (i / total_files) * 100))
}

# Combine all results into one data frame
result_table <- bind_rows(result_list)

# Save the consolidated data to an Excel file
write.xlsx(result_table, file.path(file_path, "0_brazil_national_frel_results_v1.xlsx"), rowNames = FALSE)
