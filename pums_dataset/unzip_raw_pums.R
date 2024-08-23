# unzip PUMS data
# needs: dl_path

library(stringr)
library(parallel)

# move all the 1-year files to the root directory for each year
files <- list.files(dl_path, recursive = TRUE, full.names = TRUE)
for (file in files) {
  if (grepl("-Year", file)) {
    new_file <- gsub("1-Year/", "", file)
    if (!dir.exists(dirname(new_file)))  dir.create(dirname(new_file), recursive = TRUE)
    file.rename(file, new_file)
  }
}

# now unzip all the zip files
files <- list.files(dl_path, recursive = TRUE, full.names = TRUE)
zip_files <- Filter(function(f) tools::file_ext(f) == "zip"  , files)

# to not do this in parallel, change mclapply to lapply
mclapply(
  zip_files,
  function(file) {
    # extract to the directories created
    dir <- file.path(tools::file_path_sans_ext(file))
    dir <- gsub("csv_", "", dir, fixed = TRUE)

    # one folder per year
    year <- str_extract(dir, "/(....)/(.)(..)$", group = 1)
    # make folder names, we want to separate out the h = household versions
    # from the p = person
    letter <- str_extract(dir, "/(....)/(.)(..)$", group = 2)
    letter <- list(h = "household", p = "person")[[letter]]
    # one folder per state
    state <- str_extract(dir, "/(....)/(.)(..)$", group = 3)

    dir <- file.path(dl_path, letter, year, state)
    unzip(file, exdir = dir)
    unlink(file)
  },
  mc.cores = detectCores()
)
