# Set your working directory to wherever these R files are located
setwd("~/git/PaleoCAR-SKOPE/R")

source("./calc_gdd_monthly.R")
source("./get_prism_monthly.R")
source("./annualize_prism_monthly.R")

## This script extracts data from the ~800 m monthly PRISM dataset
## for the SKOPE study area: roughly the total extent of the four-corners states.
## It first defines the extent, chops that extent into 800 m (30 arc-second) PRISM cells,
## and subdivides the extent into 14,400 (120x120) cell chunks for computation.
## (the chunks are 1x1 degree).
## These chunks are saved for later computation.
# devtools::install_github("bocinsky/FedData"); library(FedData)
library(FedData)
pkg_test("sp")
pkg_test("raster")
pkg_test("Hmisc")

username <- 'SKOPE'
password <- 'SKOPE'

system("umount /Volumes/DATA")
system('mkdir /Volumes/DATA')
system(paste0("mount -t afp afp://",username,":",password,"@prospero.anth.wsu.edu/DATA /Volumes/DATA"))

# Force Raster to load large rasters into memory
rasterOptions(chunksize=2e+07,maxmemory=2e+08)

PRISM800.DIR <- "/Volumes/DATA/PRISM/LT81_800M/"
EXTRACTION.DIR <- "/Volumes/DATA/PRISM/EXTRACTIONS/"

## Define the extent to each study region
Zuni.Cibola.Poly <- polygon_from_extent(extent(-109.7625,-107.8542,33.87917,35.42917), proj4string="+proj=longlat +ellps=GRS80")
Salinas.Poly <- polygon_from_extent(extent(-106.8458,-105.0292,33.1375,35.0125), proj4string="+proj=longlat +ellps=GRS80")
Hohokam.Poly <- polygon_from_extent(extent(-112.4625,-111.5125,32.82917,33.7875), proj4string="+proj=longlat +ellps=GRS80")
Mimbres.Poly <- polygon_from_extent(extent(-109.3042,-106.8208,32.12917,33.60417), proj4string="+proj=longlat +ellps=GRS80")
Hohokam.EXT.Poly <- polygon_from_extent(extent(-112.7322,-111.2496,32.70106,34.17916), proj4string="+proj=longlat +ellps=GRS80")

## Extract PRISM monthly data for each study area
Zuni.Cibola.PRISM <- get_prism_monthly(template=Zuni.Cibola.Poly, label="LTVTP_Zuni_Cibola", prism.800.dir=PRISM800.DIR, extraction.dir=EXTRACTION.DIR)
Salinas.PRISM <- get_prism_monthly(template=Salinas.Poly, label="LTVTP_Salinas", prism.800.dir=PRISM800.DIR, extraction.dir=EXTRACTION.DIR)
Hohokam.PRISM <- get_prism_monthly(template=Hohokam.Poly, label="LTVTP_Hohokam", prism.800.dir=PRISM800.DIR, extraction.dir=EXTRACTION.DIR)
Mimbres.PRISM <- get_prism_monthly(template=Mimbres.Poly, label="LTVTP_Mimbres", prism.800.dir=PRISM800.DIR, extraction.dir=EXTRACTION.DIR)
Hohokam.EXT.PRISM <- get_prism_monthly(template=Hohokam.EXT.Poly, label="LTVTP_Hohokam.EXT", prism.800.dir=PRISM800.DIR, extraction.dir=EXTRACTION.DIR)

## Annualization example
## Zuni/Cibola DJFM precipitation
Zuni.Cibola.ppt.DJFM <- annualize_prism_monthly(prism.brick=Zuni.Cibola.PRISM[['ppt']], months=c(0:3), fun='sum', out_dir=paste0(EXTRACTION.DIR,"LTVTP_Zuni_Cibola/PPT_DJFM/"))
writeRaster(Zuni.Cibola.ppt.DJFM,file=paste0(extraction.dir,label,"/Zuni.Cibola.ppt.DJFM.",head(names(Zuni.Cibola.ppt.DJFM),1),"-",tail(names(Zuni.Cibola.ppt.DJFM),1),".tif"), datatype="INT2U", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"), overwrite=T, setStatistics=FALSE)


## If you want to calculate GDD, there is an additional step:
# May--Sept GDD
Zuni.Cibola.gdd.monthly <- calc_gdd_monthly(tmin_brick=Zuni.Cibola.PRISM[['tmin']], tmax_brick=Zuni.Cibola.PRISM[['tmax']], t.base=10, t.cap=30, multiplier=10, to_fahrenheit=T, output.dir=paste0(EXTRACTION.DIR,"LTVTP_Zuni_Cibola/gdd/"))
Zuni.Cibola.gdd.may_sept <- annualize_prism_monthly(prism.brick=Zuni.Cibola.gdd.monthly, months=c(5:9), fun='sum', out_dir=paste0(EXTRACTION.DIR,"LTVTP_Zuni_Cibola/GDD_may_sept/"))
writeRaster(Zuni.Cibola.gdd.may_sept,file=paste0(extraction.dir,label,"/Zuni.Cibola.gdd.may_sept.",head(names(Zuni.Cibola.gdd.may_sept),1),"-",tail(names(Zuni.Cibola.gdd.may_sept),1),".tif"), datatype="INT2U", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"), overwrite=T, setStatistics=FALSE)

system("umount /Volumes/DATA")