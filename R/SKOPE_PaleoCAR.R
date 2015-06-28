# Set the climate signal... This corresponds to very particular directories below!
signal <- commandArgs(TRUE)

# Set the working directory to the location of R-scripts
setwd("/projects/EOT/skope/PaleoCAR-SKOPE/R")

# Load the functions for all analyses below
# install.packages("devtools", dependencies=T, repos = "http://cran.rstudio.com")
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
states <- rgdal::readOGR("../../PaleoCAR_RUN/DATA/NATIONAL_ATLAS/statep010","statep010")
states <- states[states$STATE %in% c("Arizona","Colorado","New Mexico","Utah"),]
states <- rgeos::gUnaryUnion(states)

# Create a 10-degree buffer around the 4C states
treePoly <- suppressWarnings(rgeos::gBuffer(states, width=10, quadsegs=1000))

# Extract the Four Corners standardized tree-ring chronologies
ITRDB <- data.frame(YEAR=prediction.years, get_itrdb(template=treePoly, label="SKOPE_4CORNERS_PLUS_10DEG", raw.dir = "../../PaleoCAR_RUN/DATA/ITRDB/RAW/ITRDB/", extraction.dir = "../../PaleoCAR_RUN/DATA/ITRDB/EXTRACTIONS/ITRDB/", recon.years=prediction.years, calib.years=calibration.years, measurement.type="Ring Width", chronology.type="Standard")[['widths']])

# Load the annual chunked raster bricks
ppt.water_year_chunks.files <- list.files(paste0("../../PaleoCAR_RUN/DATA/PRISM/EXTRACTIONS/SKOPE_4CORNERS/",signal), full.names=T)
# gdd.may_sept_chunks.files <- list.files(paste0(EXTRACTION.DIR,"GDD_may_sept/"), full.names=T)

## BEGIN PARALLELIZATION!
process.brick <- function(brick.file, brick.years, calibration.years, prediction.years, chronologies, out.dir, ...){
  dir.create(out.dir, recursive=T, showWarnings=F)
#   cat("\n\nProcessing",basename(brick.file))
  the.brick <- raster::brick(brick.file)
  if(all(is.na(the.brick[]))) return()
  # These bricks are for the whole PRISM time period (1895--2013)
  # Get only calibration years
  the.brick <- raster::subset(the.brick,which(brick.years %in% calibration.years))
  names(the.brick) <- calibration.years
  
  junk <- PaleoCAR::paleoCAR.batch(predictands=the.brick, label=basename(tools::file_path_sans_ext(brick.file)), asInt=T, chronologies=chronologies, calibration.years=calibration.years, prediction.years=prediction.years, out.dir=out.dir, ...)
  return()
}

# ## PARALLEL RUN
cl <- makeCluster(detectCores())
clusterEvalQ(cl, {library(PaleoCAR)})
parLapply(cl, ppt.water_year_chunks.files, process.brick, brick.years=1896:2013, out.dir=paste0("../../PaleoCAR_RUN/OUTPUT/",signal,"/"), floor=0, verbose=F, calibration.years=calibration.years, prediction.years=prediction.years, chronologies=ITRDB, force.redo=F)
stopCluster(cl)