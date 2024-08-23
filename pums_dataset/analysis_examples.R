library(arrow)
library(dplyr)

# after the initial recoding, read in and then write pack out
ds <- open_dataset(
  file.path(dl_path, "household"),
  partitioning = c("year", "location"),
  factory_options = list(exclude_invalid_files = TRUE),
  unify_schemas = TRUE
)

ds |>
  group_by(year, location) |>
  write_dataset("~/PUMS cleaned/household/", format = "parquet")


ds <- open_dataset(
  file.path(dl_path, "person"),
  partitioning = c("year", "location"),
  factory_options = list(exclude_invalid_files = TRUE),
  unify_schemas = TRUE
)

ds |>
  group_by(year, location) |>
  write_dataset("~/PUMS cleaned/person/", format = "parquet")


# Using the cleaned / repartitioned dataset
ds <- open_dataset("~/PUMS cleaned/person/")

# Count the number of people in each state, in each year who make more than
# USD30,000 in wages
ds |>
  filter(WAGP > 30000) |>
  group_by(ST, year) |>
  count(SEX, wt = PWGTP) |>
  collect()

ds |>
  group_by(location, year) |>
  count(wt = PWGTP) |>
  filter(year == 2010) |>
  collect() |>
  View()


# from tidycensus book
# https://walker-data.com/census-r/analyzing-census-microdata.html#pums-data-and-the-tidyverse
# looking at one year, one stat
# library(tidycensus)
# library(tidyverse)
#
# ms_pums <- get_pums(
#   variables = c("SEX", "AGEP"),
#   state = "MS",
#   survey = "acs5",
#   year = 2020,
#   recode = TRUE
# )
# ...
# ms_pums |>
# count(SEX_label, AGEP, wt = PWGTP)
#
# but we can do all years, all states:
ds |>
  count(year, ST, SEX, AGEP, wt = PWGTP) |>
  arrange(year, ST, AGEP) |>
  collect() |>
  View()
