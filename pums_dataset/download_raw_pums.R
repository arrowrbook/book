# grabbing PUMS data from https://www2.census.gov/programs-surveys/acs/data/pums/
# 2000-2006 are one year, no folder
# 2007-2019, 2021-2022 are in folder named 1-Year
# 2020 is only released in the 5-year chunk, so we will need to skip that
# The naming convention is csv_h{state id, pr, dc}.zip and csv_p{state id, pr, dc}.zip
# PR is unavailable until 2004
# PUMS variable data dictionaries are only available from 2005 on
# needs: dl_path

library(dplyr)
library(tidyr)
library(stringr)

urls <- expand.grid(
  base = "https://www2.census.gov/programs-surveys/acs/data/pums/",
  years = as.character(c(2005:2019, 2022)),
  folder = "",
  files = c("csv_h", "csv_p"),
  states = c(tolower(state.abb), "pr", "dc"),
  extension = ".zip"
) |>
  # add directory silliness on the server
  mutate(folder = case_when(
    years %in% as.character(2005:2006) ~ "/",
    TRUE ~ "/1-Year/"
  )) |>
  unite("url", everything(), sep = "", remove = FALSE) |>
  unite("path_folder", years, folder, sep = "", remove = FALSE) |>
  unite("path_file", files, states, extension, sep = "", remove = FALSE) |>
  mutate(downloaded = FALSE) |>
  select(url, path_folder, path_file, downloaded)

# check if these are already downloaded
urls <- mutate(urls, downloaded = file.exists(paste0(file.path(dl_path, path_folder), path_file)))

# two hours timeout
options(timeout = 7200)

# now download
for (row_index in seq_len(nrow(urls))) {
  row <- urls[row_index, ]
  dir.create(file.path(dl_path, row$path_folder), recursive = TRUE, showWarnings = FALSE)
  if (row$downloaded) {
    message("Skipping row ", row_index, ": ", row$url, " — already marked as downloaded!")
    next
  }
  if (file.exists(file.path(dl_path, row$path_folder, row$path_file))) {
    message("Skipping row ", row_index, ": ", row$url, " — found a file that was downloaded already!")
    urls[row_index, "downloaded"] <- TRUE
    next
  }


  try({
    message("Downloading row ", row_index, ": ", row$url)
    download.file(row$url, paste0(file.path(dl_path, row$path_folder), row$path_file))
    urls[row_index, "downloaded"] <- TRUE
  })
}

# check that all have been downloaded
stopifnot(
  "Not all files have downloaded" = all(urls$downloaded)
)
