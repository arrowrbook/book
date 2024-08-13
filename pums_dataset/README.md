# To download and then process the PUMS data from scratch

You can set `options(mc.cores = N)` to use parallelism when appropriate.
Then run the scripts. Each one relies on the `dl_path` being specified already.

If you need to (re)generate the metadata run this first chunk.
This is only necessary if the `pums_metadata/all_pums_variables.parquet` file is
wrong, or you've added an additional year to the data.

```{r}
Sys.setenv(CENSUS_KEY="...")
source("pums_dataset/download_pums_metadata.R")
```

```{r}
dl_path <- "~/PUMS"
options(mc.cores = ...)
source("pums_dataset/download_raw_pums.R")
source("pums_dataset/unzip_raw_pums.R")
source("pums_dataset/recode_pums.R")
source("pums_dataset/repartition_pums.R")
```

# Upload to AWS S3 bucket

From the root of the cleaned / repartitioned dataset

```{bash}
aws s3 sync --dryrun --delete --exclude "*.DS_Store" . s3://scaling-arrow-pums
```

# Make the PUMS smol subset

This is a subset of all of the data. This is typically kept locally, but also on the `CI_data` branch under the `PUMS_smol` directory (note: this is gitignored, so it won't accidentally be added to other branches, but adding it back to `CI_data` might take some `force`).

```{bash}
source("pums_dataset/make_smol_pums.R")
```
