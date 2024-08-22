# needs: dl_path

smol_years <- c(2005, 2018, 2021)
smol_states <- c("ak", "al", "ar", "az", "wa", "wi", "wv", "wy")

# make the PUMS smol and other paths
pums_smol <- file.path(dirname(dl_path), "PUMS smol")
dir.create(pums_smol, recursive = TRUE)

pums_cleaned <- file.path(dirname(dl_path), "PUMS cleaned")

# person, parquet
cleaned_pattern <- paste0(
  "person/",
  "year=(",
  paste(smol_years, collapse = "|"),
  ")/",
  "location=(",
  paste(smol_states, collapse = "|"),
  ")"
)
files <- list.files(pums_cleaned, pattern = "parquet$", recursive = TRUE)
person_files <- grep(cleaned_pattern, files, value = TRUE)

for (file in person_files) {
  new_file <- file.path(pums_smol, file)
  dir.create(dirname(new_file), recursive = TRUE)
  file.copy(file.path(pums_cleaned, file), new_file)
}

# person, raw_csv
raw_pattern <- paste0(
  "person/",
  "(",
  paste(smol_years, collapse = "|"),
  ")/",
  "(",
  paste(smol_states, collapse = "|"),
  ")"
)
files <- list.files(dl_path, pattern = "csv$", recursive = TRUE)
raw_files <- grep(raw_pattern, files, value = TRUE)

for (file in raw_files) {
  new_file <- file.path(pums_smol, "raw_csvs", file)
  dir.create(dirname(new_file), recursive = TRUE)
  file.copy(file.path(dl_path, file), new_file)
}
