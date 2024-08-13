import geopandas
import pandas
import pygris
from shapely import wkb

state_fips = pandas.read_csv('./pums_dataset/states.csv', dtype=str)

# Use jonkeane/pygris@recurse_cb to ensure cb is passed to all downloads.
# It should be possible to also download for <2013
ALL_PUMAS = [pygris.pumas(year = yr, cb = True).assign(YEAR=yr) for yr in range(2013, 2023)]

# Concatenate together
ALL_PUMA = pandas.concat(ALL_PUMAS)

# merge together the 10 and 20 variants of columns
ALL_PUMA['STATEFIP'] = ALL_PUMA['STATEFP10'].where(ALL_PUMA['STATEFP10'].notnull(), ALL_PUMA['STATEFP20'])
ALL_PUMA['PUMA'] = ALL_PUMA['PUMACE10'].where(ALL_PUMA['PUMACE10'].notnull(), ALL_PUMA['PUMACE20'])
ALL_PUMA['GEOID'] = ALL_PUMA['GEOID10'].where(ALL_PUMA['GEOID10'].notnull(), ALL_PUMA['GEOID20'])
ALL_PUMA['NAMELSAD'] = ALL_PUMA['NAMELSAD10'].where(ALL_PUMA['NAMELSAD10'].notnull(), ALL_PUMA['NAMELSAD20'])
ALL_PUMA['MTFCC'] = ALL_PUMA['MTFCC10'].where(ALL_PUMA['MTFCC10'].notnull(), ALL_PUMA['MTFCC20'])
ALL_PUMA['FUNCSTAT'] = ALL_PUMA['FUNCSTAT10'].where(ALL_PUMA['FUNCSTAT10'].notnull(), ALL_PUMA['FUNCSTAT20'])
ALL_PUMA['ALAND'] = ALL_PUMA['ALAND10'].where(ALL_PUMA['ALAND10'].notnull(), ALL_PUMA['ALAND20'])
ALL_PUMA['AWATER'] = ALL_PUMA['AWATER10'].where(ALL_PUMA['AWATER10'].notnull(), ALL_PUMA['AWATER20'])
ALL_PUMA['INTPTLAT'] = ALL_PUMA['INTPTLAT10'].where(ALL_PUMA['INTPTLAT10'].notnull(), ALL_PUMA['INTPTLAT20'])
ALL_PUMA['INTPTLON'] = ALL_PUMA['INTPTLON10'].where(ALL_PUMA['INTPTLON10'].notnull(), ALL_PUMA['INTPTLON20'])

# merge the state names
ALL_PUMA = pandas.merge(ALL_PUMA, state_fips, on=['STATEFIP'])

# Some early years have an extra z dimension, flatten those
_drop_z = lambda geom: wkb.loads(wkb.dumps(geom, output_dimension=2))
ALL_PUMA.geometry = ALL_PUMA.geometry.transform(_drop_z)

# Only keep the columns that are common
ALL_PUMA = ALL_PUMA[['location', 'STATEFIP', 'YEAR', 'PUMA', 'GEOID', 'NAMELSAD', 'MTFCC', 'FUNCSTAT', 'ALAND', 'AWATER', 'INTPTLAT', 'INTPTLON', 'geometry']]

# Make sure that year is an int32
ALL_PUMA['YEAR'] = ALL_PUMA['YEAR'].astype('int32')

ALL_PUMA.to_parquet("./pums_dataset/PUMA2013_2022.parquet")

# Make a smol one
SMOL_PUMA = ALL_PUMA.loc[ALL_PUMA['location'].isin(['ak', 'al', 'ar', 'az', 'wa', 'wi', 'wv', 'wy'])]
SMOL_PUMA = SMOL_PUMA.loc[SMOL_PUMA['YEAR'].isin([2005, 2018, 2021])]

# Must manually: move to smol folder/branch and rename to PUMA2013_2022.parquet
SMOL_PUMA.to_parquet("./pums_dataset/SMOL_PUMA2013_2022.parquet")
