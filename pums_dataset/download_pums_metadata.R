# grab all of the census metadata 2005-2021 and save them to Parquet files
# to use the census API, you will need to set Sys.setenv(CENSUS_KEY="...") after
# getting a key from https://api.census.gov/data/key_signup.html
library(censusapi)
library(dplyr)
library(arrow)

years <- c(2005:2019, 2021:2022)

all_acs_vars <- lapply(years, function(year) {
  acs_vars <- censusapi::listCensusMetadata("acs/acs1/pums", vintage = year, include_values = TRUE)

  # add state FIPS codes in the style of the 2021 metadata
  states <- tidycensus::fips_codes |>
    select(state, state_code, state_name) |>
    unique() |>
    mutate(
      name = "ST",
      label = "State of current residence",
      concept = NA,
      predicateType = NA,
      group = "N/A",
      limit = "0",
      predicateOnly = NA,
      suggested_weight = NA,
      is_weight = FALSE,
      values_code = state_code,
      values_label = paste(state_name, state, sep = "/"),
      year = .env$year,
      .keep = "none"
    )
  # For years 2021 and 2022 the PUMA variables have each code but the label is
  # just "Public use microdata area codes"
  if (year %in% c(2021, 2022)) {
    acs_vars <- acs_vars |>
      mutate(
        values_code = case_when(
          name %in% c("PUMA", "MIGPUMA", "POWPUMA") ~ NA,
          TRUE ~ values_code
        ),
        values_label = case_when(
          name %in% c("PUMA", "MIGPUMA", "POWPUMA") ~ NA,
          TRUE ~ values_label
        )
      ) |>
      unique()
  }

  acs_vars |>
    filter(
      name != "ST",
    ) |>
    mutate(
      # turn weight from character to a logical
      is_weight = !is.na(is_weight) & is_weight == "TRUE",
      year = year
    ) |>
    bind_rows(states)
})

write_parquet(bind_rows(all_acs_vars), file.path("pums_dataset", "all_pums_variables.parquet"))
