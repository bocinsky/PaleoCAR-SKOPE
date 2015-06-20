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
pkg_test("Hmisc")

username <- 'SKOPE'
password <- 'SKOPE'

system("umount /Volumes/DATA")
system('mkdir /Volumes/DATA')
system(paste0("mount -t afp afp://",username,":",password,"@prospero.anth.wsu.edu/DATA /Volumes/DATA"))

# Force Raster to load large rasters into memory
rasterOptions(chunksize=2e+07,maxmemory=2e+08)

TEMP.DIR <- "/Volumes/DATA/PRISM/EXTRACTIONS/SKOPE_4CORNERS/TEMP"
dir.create(TEMP.DIR, recursive=T)
rasterOptions(tmpdir=TEMP.DIR)
tmpDir()

PRISM800.DIR <- "/Volumes/DATA/PRISM/LT81_800M/"
EXTRACTION.DIR <- "/Volumes/DATA/PRISM/EXTRACTIONS/SKOPE_4CORNERS/"

# year.range <- 1924:1983

types <- c("ppt","tmin","tmax")

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

# Extract the template raster for the extent
template.rast <- raster::crop(template.rast,extent.states)

# Split the template.rast into 120 by 120 chunks
extent.states.SW.corners <- expand.grid(LON=seq(extent.states@xmin,(extent.states@xmax-1)),LAT=seq(extent.states@ymin,(extent.states@ymax-1)))
template.rast.chunks <- apply(extent.states.SW.corners,1,function(SW){raster::crop(template.rast,raster::extent(SW[1],SW[1]+1,SW[2],SW[2]+1))})

# Extract and crop all types
type.stacks <- lapply(types, function(type){
  
  if(file.exists(paste0(EXTRACTION.DIR,type,'/'))){
    monthly.files <- list.files(paste0(EXTRACTION.DIR,type), recursive=T, full.names=T)
    if(length(monthly.files)!=0){
      # Trim to only file names that are rasters
      monthly.files <- grep("*\\.tif$", monthly.files, value=TRUE)
      type.list.cropped <- raster::stack(monthly.files,native=F,quick=T)
      return(type.list.cropped)
    }
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
  system.time(type.list.cropped <- parallel::parLapply(cl,type.list,function(type,PRISM800.DIR,EXTRACTION.DIR,template.rast,rast){
    layer.name <- basename(raster::filename(rast))
    yearmonth <- gsub(".*_","",layer.name)
    yearmonth <- gsub(".bil","",yearmonth)
    year <- as.numeric(substr(yearmonth,1,4))
    month <- as.numeric(substr(yearmonth,5,6))
    out.rast <- round(raster::crop(rast,template.rast)*ifelse(type=='ppt',1,10))
    return(raster::writeRaster(out.rast,file=paste0(EXTRACTION.DIR,type,'/','Y',sprintf("%04d", year),'M',sprintf("%02d", month),'.tif'), datatype=ifelse(type=='ppt',"INT2U","INT2S"), options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"), overwrite=T, setStatistics=FALSE))
    },template.rast=template.rast, type=type,PRISM800.DIR=PRISM800.DIR, EXTRACTION.DIR=EXTRACTION.DIR))
  parallel::stopCluster(cl)
  
  type.list.cropped <- raster::stack(type.list.cropped, quick=T)
  
  return(type.list.cropped)
})

names(type.stacks) <- types

# Annual precipitation
ppt.annual <- annualizePRISM_MONTHLY(prism.brick=type.stacks[['ppt']], months=c(1:12), fun='sum', out_dir=paste0(EXTRACTION.DIR,"PPT_annual/"))
ppt.annual.chunks <- demosaic(raster_brick=ppt.annual, corners=extent.states.SW.corners, out_dir=paste0(EXTRACTION.DIR,"PPT_annual_demosaic/"))
rm(ppt.annual); rm(ppt.annual.chunks); gc(); gc()

# Water-year precipitation
ppt.water_year <- annualizePRISM_MONTHLY(prism.brick=type.stacks[['ppt']], months=c(-2:9), fun='sum', out_dir=paste0(EXTRACTION.DIR,"PPT_water_year/"))
ppt.water_year.chunks <- demosaic(raster_brick=ppt.water_year, corners=extent.states.SW.corners, out_dir=paste0(EXTRACTION.DIR,"PPT_water_year_demosaic/"))
rm(ppt.water_year); rm(ppt.water_year.chunks); gc(); gc()

# May--Sept precipitation
ppt.may_sept <- annualizePRISM_MONTHLY(prism.brick=type.stacks[['ppt']], months=c(5:9), fun='sum', out_dir=paste0(EXTRACTION.DIR,"PPT_may_sept/"))
ppt.may_sept.chunks <- demosaic(raster_brick=ppt.may_sept, corners=extent.states.SW.corners, out_dir=paste0(EXTRACTION.DIR,"PPT_may_sept_demosaic/"))
rm(ppt.may_sept); rm(ppt.may_sept.chunks); gc(); gc()

# May--Sept GDD
dir.create(paste0(EXTRACTION.DIR,"gdd/"), recursive=T, showWarnings=F)
gdd.monthly <- calcGDD_MONTHLY(tmin_brick=type.stacks[['tmin']], tmax_brick=type.stacks[['tmax']], t.base=10, t.cap=30, multiplier=10, to_fahrenheit=T, output.dir=paste0(EXTRACTION.DIR,"gdd/"))
gdd.may_sept <- annualizePRISM_MONTHLY(prism.brick=gdd.monthly, months=c(5:9), fun='sum', out_dir=paste0(EXTRACTION.DIR,"GDD_may_sept/"))
gdd.may_sept.chunks <- demosaic(raster_brick=gdd.may_sept, corners=extent.states.SW.corners, out_dir=paste0(EXTRACTION.DIR,"GDD_may_sept_demosaic/"))
rm(gdd.may_sept); rm(gdd.may_sept.chunks); gc(); gc()


system("umount /Volumes/DATA")
