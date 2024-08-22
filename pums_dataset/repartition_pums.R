# needs: dl_path

library(arrow)
library(dplyr)

datasets <- c("person", "household")
for (dataset in datasets) {
  d <- LocalFileSystem$create()$path(file.path(dl_path, dataset))
  ds <- open_dataset(
    d,
    partitioning = c("year", "location"),
    factory_options = list(exclude_invalid_files = TRUE),
    unify_schemas = TRUE
  )

  ds |>
    group_by(year, location) |>
    # write to the same parent dir as data, but with cleaned
    write_dataset(path = file.path(dirname(dl_path), "PUMS cleaned", dataset), format = "parquet")
}
