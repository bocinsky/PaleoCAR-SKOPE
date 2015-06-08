# Set the working directory to the location of R-scripts
setwd("/projects/EOT/skope/PaleoCAR_RUN/R")

# Load the functions for all analyses below
install.packages("devtools", dependencies=T, repos = "http://cran.rstudio.com")
# update.packages(ask=F, repos = "http://cran.rstudio.com")
devtools::install_github("bocinsky/FedData")
devtools::install_github("bocinsky/PaleoCAR")
library(FedData)
library(PaleoCAR)
pkg_test("parallel")

# Suppress use of scientific notation
options(scipen=999)

# Force Raster to load large rasters into memory
rasterOptions(chunksize=2e+07,maxmemory=2e+08)

## Set the calibration period
# Here, I use a 60 year period ending at 1983 
# to maximize the number of dendro series.
calibration.years <- 1924:1983

## Set the retrodiction years
# Here, we are setting it for 1--2000,
# for consistency with Bocinsky & Kohler 2014
prediction.years <- 1:2000

# The Four Corners states
states <- rgdal::readOGR("../DATA/NATIONAL_ATLAS/statep010","statep010")
states <- states[states$STATE %in% c("Arizona","Colorado","New Mexico","Utah"),]
states <- rgeos::gUnaryUnion(states)

# Extract the Four Corners standardized tree-ring chronologies
ITRDB <- data.frame(YEAR=prediction.years, get_itrdb(template=states, label="SKOPE_4CORNERS", raw.dir = "../DATA/ITRDB/RAW/ITRDB/", extraction.dir = "../DATA/ITRDB/EXTRACTIONS/ITRDB/", recon.years=prediction.years, calib.years=calibration.years, measurement.type="Ring Width", chronology.type="Standard")[['widths']])

# Load the annual chunked raster bricks
ppt.water_year_chunks.files <- list.files("../DATA/PRISM/EXTRACTIONS/SKOPE_4CORNERS/PPT_water_year", full.names=T)
# gdd.may_sept_chunks.files <- list.files(paste0(EXTRACTION.DIR,"GDD_may_sept/"), full.names=T)

## BEGIN PARALLELIZATION!
process.brick <- function(brick.file, brick.years, calibration.years, prediction.years, chronologies, out.dir, ...){
  dir.create(out.dir, recursive=T, showWarnings=F)
#   cat("\n\nProcessing",basename(brick.file))
  the.brick <- raster::brick(brick.file)
  
  # These bricks are for the whole PRISM time period (1895--2013)
  # Get only calibration years
  the.brick <- raster::subset(the.brick,which(brick.years %in% calibration.years))
  names(the.brick) <- calibration.years
  
  junk <- PaleoCAR::paleoCAR.batch(predictands=the.brick, label=basename(brick.file), chronologies=chronologies, calibration.years=calibration.years, prediction.years=prediction.years, out.dir=out.dir, ...)
  return()
}

## Looping Run
# junk <- lapply(ppt.water_year_chunks.files, process.brick, brick.years=1896:2013, out.dir="../OUTPUT/PPT_water_year/", floor=0, verbose=T, calibration.years=calibration.years, prediction.years=prediction.years, chronologies=ITRDB, force.redo=F)

# ## PARALLEL RUN
cl <- makeCluster(detectCores())
clusterEvalQ(cl, {library(PaleoCAR)})
parLapply(cl, ppt.water_year_chunks.files, process.brick, brick.years=1896:2013, out.dir="../OUTPUT/PPT_water_year/", floor=0, verbose=F, calibration.years=calibration.years, prediction.years=prediction.years, chronologies=ITRDB, force.redo=F)
stopCluster(cl)



