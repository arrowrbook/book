# Scaling Up with R and Arrow

Dev site: https://comfy-gaufre-b4acb3.netlify.app/

Published for feedback: https://scalingupwithrandarrowpreview.netlify.app/

## How to render

All of the code in this book assumes that the data is at `data/` within the repo. 
For convenience of writing, all examples can run with either the full data or the subset data. 
Which is used depends on which is in (or linked to) the `data/` directory.
Doing this allows us to have quick iteration cycles knowing that we can compile with examples and write examples without needing to run against the full dataset every single time.

### Subset data

There is a small set of data that should be used for general writing and iteration.
This dataset is also used in CI when we force a rerender of the book to ensure we aren't relying on some other data.

This dataset is intended to be close in shape to the PUMS dataset, but be small enough we can ship it around easily.
The dataset is: only person (no household), only the years 2005, 2018, and 2021 and only the states ("locations") ak, al, ar, az, wa, wi, wv, and wy.
This way, so long as you don't specifically filter to states that aren't here or years that aren't here, the examples will run just fine using this subset, but when we do a full render for the book we can reference the entire dataset.

To get this, in your repo you can:

```
git fetch origin CI_data:CI_data
git checkout --no-overlay CI_data -- PUMS_smol
git restore --staged PUMS_smol
```

Which will place the `PUMS_smol` directory in your repo. 
You can then link it to the data directory to be used (e.g. `ln -s PUMS_smol data`)

### Full data

The full data is currently just over 75GB for Parquet + raw CSVs.
If you would like to store this elsewhere, you can symlink to this folder and everything will just work (e.g. `ln -s {some path where you can hold this data} data`)

Get the PUMS dataset from S3: `aws s3 sync s3://scaling-arrow-pums {some path where you can hold this data}`
_hand waved for now_: get the raw PUMS CSVs and extract them to `{some path where you can hold this data}/raw_csvs` (you can copy this from the [Subset data above for now](https://github.com/thisisnic/scaling_up_with_r_and_arrow/tree/CI_data/PUMS_smol/raw_csvs/person))

### Rendering with full data for publishing

In CI, we use the subset data to render (and we set `freeze: false` so we never use the frozen output). 

To render and publish with the full dataset (all of this is done locally): 

* checkout the `published` branch and remove both `_book` and `_freeze` to start fresh
* then switch to the branch you want to render (typically up-to-date `main`)
* link or placed the full dataset in the `data/` directory
* remove the `_freeze/` directory and run `quarto render` 
* switch to the `published` branch and then commit the `_book` and `_freeze/` files

The `published` branch doesn't have the source files, just those needed to render and publish the book to [scalingupwithrandarrowpreview.netlify.app](https://scalingupwithrandarrowpreview.netlify.app).

## Conventions that seem to be working

* merge shitty-first-draft versions of chapters into main, then open subsequent PRs to make changes or additions
* open issues for more general changes
* use HTML comments (i.e. `<!-- #34 comment goes here -->`) to note changes in the text; open a corresponding issue and include number in the comment
* make all changes (except this README, CI, inline comments etc) via PRs so it's easy to get a quick overview of what's been happening in the repo
