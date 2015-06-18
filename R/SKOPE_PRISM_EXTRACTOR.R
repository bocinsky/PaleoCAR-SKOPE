setwd("~/git/PaleoCAR-SKOPE/R")
source("./calcGDD_MONTHLY.R")
source("./annualizePRISM_MONTHLY.R")
source("./demosaic.R")

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

username <- 'SKOPE'
password <- 'SKOPE'

system('mkdir /Volumes/DATA')
system(paste0("mount -t afp afp://",username,":",password,"@prospero.anth.wsu.edu/DATA /Volumes/DATA"))

# Force Raster to load large rasters into memory
rasterOptions(chunksize=2e+08,maxmemory=2e+09)

TEMP.DIR <- "/Volumes/DATA/PRISM/EXTRACTIONS/SKOPE_4CORNERS/TEMP"
dir.create(TEMP.DIR, recursive=T, showWarnings=F)
rasterOptions(tmpdir=TEMP.DIR)

PRISM800.DIR <- "/Volumes/DATA/PRISM/LT81_800M/"
EXTRACTION.DIR <- "/Volumes/DATA/PRISM/EXTRACTIONS/SKOPE_4CORNERS/"

# year.range <- 1924:1983

types <- c("tmin","tmax")

# Extract and read a test grid from PRISM
# unzip(paste0(PRISM800.DIR,"ppt/ppt_1895.zip"), exdir=paste(PRISM800.DIR,"ppt/",sep=''))
template.rast <- raster::setValues(raster::raster(paste0(PRISM800.DIR,"ppt/1895/cai_ppt_us_us_30s_189501.bil")),NA)
# unlink(paste0(PRISM800.DIR,"ppt/1895"), recursive=T, force=T)

# Read in the US states, and extract 4C states
states <- rgdal::readOGR("/Volumes/DATA/NATIONAL_ATLAS/statep010","statep010")
states <- states[states$STATE %in% c("Arizona","Colorado","New Mexico","Utah"),]
# Transform to the CRS of the template raster
states <- sp::spTransform(states, sp::CRS(raster::projection(template.rast)))
# Get the extent
extent.states <- raster::extent(states)
# Floor the minimums, ceiling the maximums
extent.states@xmin <- floor(extent.states@xmin)
extent.states@ymin <- floor(extent.states@ymin)
extent.states@xmax <- ceiling(extent.states@xmax)
extent.states@ymax <- ceiling(extent.states@ymax)
# plot(extent.states, add=T)
# plot(template.rast, add=T)
# Extract the template raster for the extent
template.rast <- raster::crop(template.rast,extent.states)

# Split the template.rast into 120 by 120 chunks
extent.states.SW.corners <- expand.grid(LON=seq(extent.states@xmin,(extent.states@xmax-1)),LAT=seq(extent.states@ymin,(extent.states@ymax-1)))
template.rast.chunks <- apply(extent.states.SW.corners,1,function(SW){raster::crop(template.rast,raster::extent(SW[1],SW[1]+1,SW[2],SW[2]+1))})

# Extract and crop all types
type.stacks <- lapply(types, function(type){
  
  if(file.exists(paste0(EXTRACTION.DIR,type,'/'))){
    monthly.files <- list.files(paste0(EXTRACTION.DIR,type), recursive=T, full.names=T)
    # Trim to only file names that are rasters
    monthly.files <- grep("*\\.grd$", monthly.files, value=TRUE)
    type.list.cropped <- raster::stack(monthly.files,native=F,quick=T)
    return(type.list.cropped)
  }
  
  # Get all file names
  monthly.files <- list.files(paste0(PRISM800.DIR,type), recursive=T, full.names=T)
  
  # Trim to only file names that are rasters
  monthly.files <- grep("*\\.bil$", monthly.files, value=TRUE)
  monthly.files <- grep("spqc", monthly.files, value=TRUE, invert=T)
  monthly.files <- grep("/cai", monthly.files, value=TRUE)
  #   monthly.files <- grep(paste0(as.character(year.range),collapse='|/'), monthly.files, value=TRUE)
  
  # Generate the raster stack
  type.list <- raster::unstack(raster::stack(monthly.files,native=F,quick=T))
  
  # Make a temporary directory
  suppressWarnings(dir.create(paste0(EXTRACTION.DIR,type)))
  
  cl <- parallel::makeCluster(8)
  system.time(type.list.cropped <- parallel::parLapply(cl,type.list,function(type,PRISM800.DIR,EXTRACTION.DIR,extent.states,rast){return(raster::crop(rast,extent.states,file=paste0(EXTRACTION.DIR,type,'/',basename(raster::filename(rast)),'.grd'),overwrite=T))},extent.states=extent.states, type=type,PRISM800.DIR=PRISM800.DIR, EXTRACTION.DIR=EXTRACTION.DIR))
  parallel::stopCluster(cl)
  
  type.list.cropped <- raster::stack(type.list.cropped, quick=T)
  names(type.list.cropped) <- basename(monthly.files)
  
  return(type.list.cropped)
})

names(type.stacks) <- types

# # Annual precipitation
# ppt.annual <- annualizePRISM_MONTHLY(prism.brick=type.stacks[['ppt']], months=c(1:12), fun='sum')
# writeRaster(ppt.annual,paste0(EXTRACTION.DIR,'ppt.annual.tif'), datatype="INT2U", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"),overwrite=T,setStatistics=FALSE)
# rm(ppt.annual); gc(); gc()
# 
# # Water-year precipitation
# ppt.water_year <- annualizePRISM_MONTHLY(prism.brick=type.stacks[['ppt']], months=c(-2:9), fun='sum')
# writeRaster(ppt.water_year,paste0(EXTRACTION.DIR,'ppt.water_year.tif'), datatype="INT2U", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"),overwrite=T,setStatistics=FALSE)
# rm(ppt.water_year); gc(); gc()
# 
# # May--Sept precipitation
# ppt.may_sept <- annualizePRISM_MONTHLY(prism.brick=type.stacks[['ppt']], months=c(5:9), fun='sum')
# writeRaster(ppt.may_sept,paste0(EXTRACTION.DIR,'ppt.may_sept.tif'), datatype="INT2U", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"),overwrite=T,setStatistics=FALSE)
# rm(ppt.may_sept); gc(); gc()
# 
# # May--Sept Mean temperature
# tmean.may_sept <- annualizePRISM_MONTHLY(prism.brick=(type.stacks[['tmin']]+type.stacks[['tmax']])/0.02, months=c(5:9), fun='mean')
# writeRaster(tmean.may_sept,paste0(EXTRACTION.DIR,'tmean.may_sept.tif'), datatype="INT2S", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"),overwrite=T,setStatistics=FALSE)
# rm(tmean.may_sept); gc(); gc()

# May--Sept GDD
message("Calculating Monthly GDDs")
gdd.monthly <- calcGDD_MONTHLY(tmin_brick=type.stacks[['tmin']], tmax_brick=type.stacks[['tmax']], t.base=10, t.cap=30, to_fahrenheit=T)
writeRaster(gdd.monthly,paste0(EXTRACTION.DIR,'gdd.monthly.tif'), datatype="INT2S", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"),overwrite=T,setStatistics=FALSE)
gdd.monthly <- brick(paste0(EXTRACTION.DIR,'gdd.monthly.tif'))
names(gdd.monthly) <- names(type.stacks[['tmin']])
rm(type.stacks);gc();gc()

message("Calculating Annual GDDs")
gdd.may_sept <- annualizePRISM_MONTHLY(prism.brick=gdd.monthly, months=c(5:9), fun='sum')
writeRaster(gdd.may_sept,paste0(EXTRACTION.DIR,'gdd.may_sept.tif'), datatype="INT2S", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"),overwrite=T,setStatistics=FALSE)
rm(gdd.may_sept); rm(gdd.monthly); gc(); gc()



## Perform the demosaicking
# Water-year precipitation
# ppt.water_year <- brick(paste0(EXTRACTION.DIR,'ppt.water_year.tif'))
# ppt.water_year_chunks <- demosaic(raster_brick=ppt.water_year, corners=extent.states.SW.corners, out_dir=paste0(EXTRACTION.DIR,"PPT_water_year/"))
# rm(ppt.water_year); rm(ppt.water_year_chunks); gc(); gc()

# May--Sept GDD
message("Demosaicking annual GDDs")
gdd.may_sept <- brick(paste0(EXTRACTION.DIR,'gdd.may_sept.tif'))
gdd.may_sept_chunks <- demosaic(raster_brick=gdd.may_sept, corners=extent.states.SW.corners, out_dir=paste0(EXTRACTION.DIR,"GDD_may_sept/"))
rm(gdd.may_sept); rm(gdd.may_sept_chunks); gc(); gc()

system("umount /Volumes/DATA")


# test <- crop(test, extent(test,1,100,1,100))
# test.grid <- as(test,'SpatialPolygons')
# 
# test.utm <- projectRaster(test,crs=CRS('+proj=utm +zone=12 +datum=NAD83'))
# test.grid.utm <- spTransform(test.grid,CRS('+proj=utm +zone=12 +datum=NAD83'))
#   
#   
# plot(test.utm)
# plot(test.grid.utm, add=T)
# 
# plot(as(test,'SpatialPolygons'), add=T)
# 
# gl <- gridlines(test, easts=unique(coordinates(test)[,1]), norths=unique(coordinates(test)[,2]))
# gl.dat <- gridat(gl)
# 
# plot(test)
# plot(gl, add = TRUE)
# plot(gl.dat, add = TRUE)



