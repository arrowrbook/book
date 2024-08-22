library(ggplot2)
library(arrow)
library(geoarrow)
library(dplyr)
library(sf)
library(tidyr)

# Read in the puma geoparquet, mark it as such with SF
PUMA <- arrow::read_parquet("data/PUMA2013_2022.parquet", as_data_frame = FALSE)
PUMA_df <- collect(PUMA)

# set the geometry column, but we also need to manually extract the CRS from the
# geoparquet metadata
PUMA_df <- sf::st_sf(
  PUMA_df,
  sf_column_name = "geometry",
  crs = jsonlite::fromJSON(schema(PUMA)$metadata$geo)$columns$geometry$crs$name
)

# Move the bounding box + center of the projection so that Alaska is plotted together
proj <- "+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
PUMA_df$geometry <- st_transform(PUMA_df$geometry, crs = proj)


pums_person <- open_dataset("./data/person")

non_english_speakers <- pums_person |>
  filter(year == 2018) |>
  mutate(
    language = tolower(LANP),
    language = case_when(
      is.na(language) ~ "english",
      TRUE ~ language
    )
  ) |>
  group_by(location, ST, PUMA, year, language) |>
  summarise(
    n_people = sum(PWGTP)
  ) |>
  # This is no longer needed in arrow > 16.1
  collect() |>
  group_by(location, ST, PUMA, year) |>
  mutate(
    prop_speaker = n_people / sum(n_people),
  ) |>
  filter(language %in% c("english", "spanish", "french", "german"))

# fill in PUMAs that are empty
to_plot <- non_english_speakers |>
  ungroup() |>
  collect() |>
  complete(language, nesting(location, ST, PUMA, year), fill = list(n_people = 0, prop_speaker = 0)) |>
  group_by(language) |>
  mutate(prop_speaker = prop_speaker / max(prop_speaker)) |>
  left_join(PUMA_df, by = c("year" = "YEAR", "location" = "location", "PUMA" = "PUMA"), keep = TRUE)

# All of the US
to_plot |>
  ggplot() +
  geom_sf(aes(geometry = geometry, fill = prop_speaker), lwd = 0) +
  coord_sf(crs = "+proj=laea +lon_0=-98 +lat_0=39.5") +
  facet_wrap(vars(language), ncol = 2) +
  scale_fill_distiller(type = "seq", direction = 1, palette = "Greys", name = "proportion of speakers") +
  theme_minimal() +
  theme(legend.position = "bottom") +
  labs(
    title = "Proportion of speakers by language",
    subtitle = "across the US by PUMA"
  )

# chicago
to_plot |>
  ggplot() +
  geom_sf(aes(geometry = geometry, fill = prop_speaker), lwd = 0) +
  coord_sf(
    xlim = c(0650000, 0715000),
    ylim = c(2090000, 2200000),
    crs = "+proj=laea +lon_0=-88.5 +lat_0=41.5",
    expand = FALSE
  ) +
  facet_wrap(vars(language), ncol = 2) +
  scale_fill_distiller(type = "seq", direction = 1, palette = "Greys", name = "proportion of speakers") +
  theme_minimal() +
  theme(legend.position = "bottom") +
  labs(
    title = "Proportion of speakers by language",
    subtitle = "in the Chicago area by PUMA"
  )

# north east
to_plot |>
  ggplot() +
  geom_sf(aes(geometry = geometry, fill = prop_speaker), lwd = 0) +
  coord_sf(
    xlim = c(1750000, 2275000),
    ylim = c(2100000, 3050000),
    crs = "+proj=laea +lon_0=-88.5 +lat_0=41.5",
    expand = FALSE
  ) +
  facet_wrap(vars(language), ncol = 2) +
  scale_fill_distiller(type = "seq", direction = 1, palette = "Greys", name = "proportion of speakers") +
  theme_minimal() +
  theme(legend.position = "bottom") +
  labs(
    title = "Proportion of speakers by language",
    subtitle = "in the Northeast"
  )
