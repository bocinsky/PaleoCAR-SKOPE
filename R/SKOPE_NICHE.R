setwd("/Volumes/BOCINSKY_DATA/WORKING/BOCINSKY_KOHLER_2015/R/")

library(raster)

dir.create("../DATA/PaleoCAR/NICHE_demosaic",showWarnings = F, recursive = T)
all.rasts <- list.files("../DATA/PaleoCAR/GDD_may_sept_demosaic",pattern="recon")

junk <- lapply(all.rasts, function(name){
  gdd <- raster::brick(paste0("../DATA/PaleoCAR/GDD_may_sept_demosaic/",name)) >= 1800
  ppt <- raster::brick(paste0("../DATA/PaleoCAR/PPT_water_year_demosaic/",name)) >= 300
  
  out <- gdd * ppt
  
  writeRaster(out,paste0("../DATA/PaleoCAR/NICHE_demosaic/",name), datatype="INT1U", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND", "NBITS=1"),overwrite=T,setStatistics=FALSE)
  
})

all.rasts <- list.files("../DATA/PaleoCAR/NICHE_demosaic",pattern="recon",full.names=T)
system(paste0("gdal_merge.py -v -o ../DATA/PaleoCAR/NICHE_demosaic/NICHE_FINAL.tif -ot Byte -co COMPRESS=DEFLATE -co ZLEVEL=9 -co INTERLEAVE=BAND -co NBITS=1 -co TILED=YES ",paste(all.rasts,collapse=" ")))