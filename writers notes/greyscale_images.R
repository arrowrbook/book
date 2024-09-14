library(magick)
library(magrittr)
library(purrr)

all_pngs <- list.files("./images/excalidraw/", pattern = "\\.png$", full.names = TRUE)
all_pngs <- all_pngs[!grepl("_bw\\.png$", all_pngs)]


convert_bw <- function(image_path){
  
  new_path <- gsub(".png", "_bw.png", image_path)
  if(!file.exists(new_path)){
    image_read(image_path) %>%
      image_convert(colorspace = "Gray") %>%
      image_write(path = new_path)
  }
  
  # See https://github.com/ropensci/magick/issues/366
  gc()
  
}

walk(all_pngs, convert_bw)

