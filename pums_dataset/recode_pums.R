# needs: dl_path

library(arrow)
library(dplyr)
library(tidyr)
library(stringr)
library(parallel)

# default to root of book dir
pums_metadata_path <- file.path("pums_dataset")

# get all files, split into years
years <- unique(c(list.files(file.path(dl_path, "person")), list.files(file.path(dl_path, "household"))))
files_by_year <- lapply(years, function(year) {
  csv_person <- list.files(file.path(dl_path, "person", year), recursive = TRUE, full.names = TRUE, pattern = ".*\\.csv")
  csv_household <- list.files(file.path(dl_path, "household", year), recursive = TRUE, full.names = TRUE, pattern = ".*\\.csv")

  # Filter(function(x) grepl("/a./", x), c(csv_person, csv_household))
  c(csv_person, csv_household)
})
names(files_by_year) <- years


# get each year of PUMS variables since they are the same
# These are all downloaded and saved in `download_pums_metadata.R`
all_pums_vars <- read_parquet(file.path(pums_metadata_path, "all_pums_variables.parquet"))

# take all of the pums vars and identify which types each is based on the values
# not just in one year, but all of them together.
identifier <- function(df, key) {
  # TODO: WKW in 2005 is literally count of weeks worked, but after that is a factor.

  # how many levels before we switch to strings?
  max_levels_for_factors <- 10

  # edit AGEP in 2005 so that it has a 0 value and not just NA
  if (key$name == "AGEP") {
    df[df$year == "2005", "values_code"] <- "00"
    df[df$year == "2005", "values_label"] <- "Under 1 year"
  }

  # edit RACNUM so that it's actually a number (instead of a string like it is now)
  if (key$name == "RACNUM") {
    df <- df |>
      filter(year != 2005)

    # take 2006 is as a model, change that one row's year to 2005 and row bind
    df <- df |>
      filter(year == 2006) |>
      mutate(year = 2005) |>
      bind_rows(df)
  }

  yeses <- c(
    "yes",
    "yes,.*",
    "allocated",
    "Served.*",
    "With a disability",
    "Meals included in rent",
    "Worked",
    "HU does contain grandchildren",
    "Household with grandparent living with grandchildren",
    "With health insurance coverage",
    "With private health insurance coverage",
    "With public health coverage"
  )

  nos <- c(
    "no",
    "no,.*",
    "not allocated",
    "Did not serve.*",
    "Without a disability",
    "No disability",
    "No meals included in rent",
    "Did not work",
    "HU does not contain grandchildren",
    "Household without grandparent living with grandchildren",
    "No health insurance coverage",
    "Without private health insurance coverage",
    "Without public health coverage"
  )

  NAs <- c(
    "N/A",
    "Suppressed",
    "Not reported",
    "Did not report",
    "Case is from the United States, PLMPRP not applicable",
    "Case is from Puerto Rico, RWAT not applicable",
    "Case is from the United States, HOTWAT not applicable"
  )

  df <- df |>
    mutate(
      numeric_code = suppressWarnings(as.numeric(values_code)),
      # for finding these numeric-like values, we don't want the flag values to also be caught
      zero_like = !is.na(numeric_code) & numeric_code == 0 & !str_detect(label, fixed("flag", ignore_case = TRUE)),
      one_like = !is.na(numeric_code) & numeric_code == 1 & !str_detect(label, fixed("flag", ignore_case = TRUE)),

      # yes + no like will also have some bespoke strings (e.g. for disability or military service) that reduce to ~yes/no. Some are only present in early years)
      yes_like = !is.na(numeric_code) & str_detect(values_label, regex(paste0("^(", paste0(yeses, collapse = "|"),")$"), ignore_case = TRUE)),
      no_like = !is.na(numeric_code) & str_detect(values_label, regex(paste0("^(", paste0(nos, collapse = "|"), ")$"), ignore_case = TRUE)),

      # NA like has a few special cases (like PLMPRP which is only asked of PR, so has a special "not asked" missing value for US)
      NA_like = str_detect(values_label, paste0("^(", paste0(NAs, collapse = "|"), ")")) | ( str_detect(values_label, "^Not in universe") | is.na(values_code) ),

      or_more = str_detect(values_label, fixed("or more", ignore_case = TRUE)) & !str_detect(label, fixed("flag", ignore_case = TRUE))
    )

  modified <- df |>
    group_by(year) |>
    summarise(
      n_categories_per_year = n(),
      all_NA_like = all(NA_like),
      # need to split this as: all numeric no missing; numeric and missing.
      all_numeric = all(zero_like | one_like | or_more) & !any(NA_like),
      all_numeric_or_NA_like = all(NA_like | zero_like | one_like | or_more),
      # Is all yes/no/NA, but at least one yes or no
      all_boolean = all(NA_like | yes_like | no_like) & ( sum(yes_like) > 0 | sum(no_like) > 0 ),
      all_value_NA = all(is.na(values_code)),
      is_weight = all(is_weight)
    )

  # The case statement for assigning these
  if (all(modified$is_weight)) {
    # Identify all weights early, these will be ignored later
    df$result_type <- "weight"
  } else if (str_detect(key$name, "^ADJ")) {
    # These are adjustment variables
    df$result_type <- "adjustment"
  } else if (key == "PUMA") {
    # Special case PUMA to treat it like a character. This ignores that there is
    # one special all 7s PUMA in one year that is a combination of PUMAs.
    df$result_type <- "character"
  } else if (all(modified$all_value_NA)) {
    # All values are NA, so we will ignore these
    df$result_type <- "all_NA_ignore"
  } else if (all(modified$all_boolean)) {
    df$result_type <- "boolean"
  } else if (all(modified$all_numeric)) {
    df$result_type <- "numeric"
  } else if (all(modified$all_numeric_or_NA_like | modified$all_NA_like)) {
    # All the values have a single NA-like column (or are missing for that year)
    df$result_type <- "numeric_or_NA_like"
  } else if (max(modified$n_categories_per_year) > max_levels_for_factors) {
    # If there are more than max_levels_for_factors categories in any one year, make this a character
    df$result_type <- "character"
  } else if (max(modified$n_categories_per_year) > 1) {
    # So long as there is more than one category (but less than max_levels_for_factors), make this a factor
    df$result_type <- "factor"
  }

  if (is.null(df$result_type)) {
    stop("There is an unclassified variable in the pums metadata")
  }

  # overrides for some detected types that should actually be factors:
  factor_override <- c(
    # These look like bools or numerics, but really should be factors
    "MILY", "SRNT", "SSPA", "SVAL"
  )
  if (key$name %in% factor_override) {
    df$result_type <- "factor"
  }

  # These variables have pairs of flag-value for later years. Technically one must
  # look at the flag to tell if the value is usable (or otherwise a code) but we
  # don't do that (yet), so for these, just make the values be numerics
  #   ELEFP, ELEP
  #   FULFP, FULP
  #   WATP, WATFP
  #   GASP, GASFP
  numeric_override <- c("ELEP", "FULP", "WATP", "GASP")
  if (key$name %in% numeric_override) {
    df$result_type <- "numeric_or_NA_like"
    df$NA_like <- TRUE
  }

  df
}

all_pums_vars <- all_pums_vars |>
  group_by(name) |>
  group_modify(
    identifier
  )

# Confirm which are factors with:
# all_pums_vars |> filter(result_type == "factor") |> group_by(name, result_type) |> summarise() |> View()

# now for each CSV, read in recode and write as a parquet
lapply(
  years,
  function(year) {
    # to not do this in parallel, change mclapply to lapply
    mclapply(
      files_by_year[[year]],
      function(file) {
        # effectively message("Working on ", file), but for parallel
        system(sprintf('echo "%s"', paste0("Working on ", file, collapse="")))

        # munge the schema so these columns are read as strings
        # open a dataset so we don't read the whole file, but guess the schema
        new_schema <- schema(open_dataset(file, format = "csv"))

        # grab all the overlapping variables for this year
        pums_vars <- all_pums_vars |>
          filter(
            # only this year
            year == .env$year,
            # not weights
            !is_weight,
            # not ones we ignore
            result_type != "all_NA_ignore"
          )

        common_variables <- names(new_schema)[names(new_schema) %in% unique(pull(pums_vars, "name"))]
        common_pums <- pums_vars |>
          filter(name %in% common_variables)

        # figure out what kind of recode should happen for each kind of variable
        # These pums vars have one level defined in the metadata, which actually
        # are NA values
        pums_vars_numeric_or_NA <- common_pums |>
          filter(result_type == "numeric_or_NA_like") |>
          pull(name) |>
          unique()

        # These pums vars are booleans
        pums_vars_bool <- common_pums |>
          filter(result_type == "boolean") |>
          pull(name) |>
          unique()

        # These pums vars have one special variant that is effectively zero
        pums_vars_numeric <- common_pums |>
          filter(result_type == "numeric") |>
          pull(name) |>
          unique()

        # These pums vars have fewer than max_levels_for_factors levels, so we treat them as factors
        pums_vars_factors <- common_pums |>
          filter(result_type == "factor") |>
          pull(name) |>
          unique()

        # These pums vars have more than max_levels_for_factors levels, so we treat them as characters
        pums_vars_characters <- common_pums |>
          filter(result_type == "character") |>
          pull(name) |>
          unique()

        pums_vars_adjustments <- common_pums |>
          filter(result_type == "adjustment") |>
          pull(name) |>
          unique()

        # These are the vars that get fully recorded (the one_NA variant will be overwritten in situ)
        vars_to_recode <- c(pums_vars_factors, pums_vars_characters)

        # ensure that all of the common vars are accounted for
        stopifnot(
          "Something is wrong with the pums variable grouping." = setequal(
            unique(common_pums$name),
            c(
              pums_vars_factors,
              pums_vars_characters,
              pums_vars_adjustments,
              pums_vars_numeric,
              pums_vars_numeric_or_NA,
              pums_vars_bool
            )
          )
        )

        # When we recode, these will need to be utf8
        for (var in vars_to_recode) {
          new_schema[[var]] <- utf8()
        }

        # When we use the one NA, then we want ints
        for (var in c(pums_vars_numeric, pums_vars_numeric_or_NA)) {
          new_schema[[var]] <- int32()
        }

        # SERIALNO must be an utf8()
        if ("SERIALNO" %in% names(new_schema)) {
          new_schema[["SERIALNO"]] <- utf8()
        }

        # capitalize all variables (most important for sporder and the weights which
        # are lowercase earlier on)
        names(new_schema) <- toupper(names(new_schema))

        # INSP is sometimes 01E4, which only numeric can parse
        # cf https://github.com/apache/arrow/issues/32526
        if ("INSP" %in% names(new_schema)) {
          new_schema[["INSP"]] <- double()
        }

        # Read the data in
        # at least 2014 has some " " as NAs
        df <- read_csv_arrow(file, schema = new_schema, skip = 1, na = c("", "NA", " "))

        is_person <- all(df$RT == "P")
        if (is_person) {
          join_cols <- c("SERIALNO", "SPORDER")
        } else {
          join_cols <- "SERIALNO"
        }

        # pivot then unpivot method (alternative: many joins each with different join by)
        # inspired by tidycensus
        var_lookup <- pums_vars |>
          filter(name %in% vars_to_recode)|>
          select("name", "values_code", "values_label")

        # Sometimes codes are 0 padded, other times they are not, so we need to check each
        # for example JWTR, REL, SCHL
        repad <- lapply(vars_to_recode, function(var) {
          in_data <- df |>
            pull(var) |>
            unique()
          in_data <- sort(in_data[!is.na(in_data)])

          in_metadata <- var_lookup |>
            filter(name == var) |>
            pull(values_code) |>
            unique()
          in_metadata <- sort(in_metadata[!is.na(in_metadata)])

          # only attempt a recode improvement via padding if the data has all one length
          if (length(unique(nchar(in_data))) == 1) {
            pad_width <- unique(nchar(in_data))
            in_metadata_padded <- str_pad(in_metadata, width = pad_width, pad = "0")
            matched_meta <- setdiff(in_data, in_metadata)
            matched_meta_padded <- setdiff(in_data, in_metadata_padded)

            if (length(matched_meta_padded) < length(matched_meta)) {
              # this is good, we're aligning more
              setNames(list(pad_width), var)
            } else {
              NULL
            }
          }
        })
        to_repad <- unlist(repad)
        if (!is.null(to_repad)) {
          var_lookup <- var_lookup |>
            mutate(
              values_code = case_when(
                name %in% names(to_repad) ~ str_pad(values_code, width = to_repad[name], pad = "0"),
                .default = values_code
              )
            )
        }

        # Pivot to long format and join variable codes to lookup table with labels
        # for pums_vars_factors, pums_vars_characters only,
        # we will deal with the NAs later
        recoded_long <- df |>
          select(
            any_of(join_cols),
            any_of(vars_to_recode)
          ) |>
          pivot_longer(
            cols = -any_of(join_cols),
            names_to = "name",
            values_to = "values_code"
          ) |>
          left_join(var_lookup, by = c("name", "values_code")) |>
          select(-"values_code")


        # Create a pivot spec with nicer names for the labeled columns
        spec <- recoded_long |>
          build_wider_spec(
            names_from = "name",
            values_from = "values_label"
          )

        recoded_wide <- recoded_long |>
          pivot_wider_spec(spec)

        # Make factors but only if there are fewer than max_levels_for_factors
        # levels but more than 1 (PUMA has one level which is an odd combo of PUMAs)
        # TODO: mark factors that have not in universe missing as NA?
        for (var in pums_vars_factors){
          # We need to look at _all_ pums vars to make sure that we have all of
          # the levels for each factor
          all_levels <- all_pums_vars |>
            filter(name==var) |>
            pull(values_label) |>
            unique()

          recoded_wide[[var]] <- factor(recoded_wide[[var]], levels=all_levels)
        }

        # Rejoin
        dat <- df |>
          left_join(recoded_wide, by = join_cols, suffix = c("_codes", "")) |>
          # Coalesce the codes with the the labels for our characters to fix
          # cases where the code was correct, but had an exception (e.g. PUMA
          # where 77777 means "combination of 01801, 01802, and 01905 in Louisiana")
          mutate(
            across(
              any_of(pums_vars_characters),
              ~coalesce(.,
                        get(paste0(cur_column(), "_codes"))),
              .names = "{.col}"
            ),
            .keep = "unused"
          ) |>
          select(-ends_with("_code")) |>
          # Only after we join can we deal with the pums_vars_one_NA since we want
          # them to be true NAs
          mutate(
            across(
              any_of(c(pums_vars_numeric_or_NA)),
              ~case_when(
                . %in% unique(pull(filter(pums_vars, name == quote(.) & (NA_like)), "values_code")) ~ NA,
                TRUE ~ .
              )
            )
          ) |>
          # Now change booleans
          mutate(
            across(
              any_of(c(pums_vars_bool)),
              ~case_when(
                . %in% unique(pull(filter(pums_vars, name == quote(.) & (yes_like)), "values_code")) ~ TRUE,
                . %in% unique(pull(filter(pums_vars, name == quote(.) & (no_like)), "values_code")) ~ FALSE,
                # We do all the rest as NA because some variables don't have an NA, and errors due to recycling if we are explicit
                TRUE ~ NA
              )
            )
          ) |>
          # Now change adjustments
          mutate(
            across(
              any_of(pums_vars_adjustments),
              ~ as.numeric(.)/1000000
            )
          ) |>
          # reorder the vars so they are in the same order as df
          select(all_of(names(df)))

        # compare row numbers before and after
        stopifnot(
          "There are different numbers of rows before and after recode"= nrow(df) == nrow(dat),
          "There are different numbers of cols before and after recode"= ncol(df) == ncol(dat)
        )

        write_parquet(dat, gsub(".csv", ".parquet", file, fixed = TRUE))

        # This seems excessive, but memory does reliably leak without it
        rm(dat, df)
      }
    )
  }
)
