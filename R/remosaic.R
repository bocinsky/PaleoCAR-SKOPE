library(raster)

all.files <- list.files("/Volumes/DATA/SKOPE/PaleoCAR/OUTPUT/GDD_may_sept_demosaic",full.names=T)
all.files <- list.files("/Volumes/DATA/SKOPE/PaleoCAR/OUTPUT/PPT_may_sept_demosaic",full.names=T)
all.files <- list.files("/Volumes/DATA/SKOPE/PaleoCAR/OUTPUT/PPT_water_year_demosaic",full.names=T)
all.files <- list.files("/Volumes/DATA/SKOPE/PaleoCAR/OUTPUT/PPT_annual_demosaic",full.names=T)
all.files <- all.files[grepl("recon",all.files)]
all.files <- all.files[!grepl("tif.recon",all.files)]

all.rasts <- lapply(all.files,raster,band=1257)

all.rasts.merge <- do.call(raster::merge, all.rasts)
plot(all.rasts.merge)
plot(all.rasts.merge>=300)


test <- brick("/Volumes/DATA/PRISM/EXTRACTIONS/SKOPE_4CORNERS/GDD_may_sept_demosaic/103W31N.tif")

all.files <- list.files("/Volumes/DATA/PRISM/EXTRACTIONS/SKOPE_4CORNERS/GDD_may_sept_demosaic",full.names=T)

all.rasts <- lapply(all.files,raster,band=100)

all.rasts.merge <- do.call(raster::merge, all.rasts)
plot(all.rasts.merge)
plot(all.rasts.merge>=2000)
