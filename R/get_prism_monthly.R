get_prism_monthly <- function(template, label, types=c("ppt","tmin","tmax"), prism.800.dir, extraction.dir){
  junk <- lapply(paste0(extraction.dir,label,"/",types),dir.create, showWarnings=F, recursive=T)
  
  # Extract and crop all types
  type.stacks <- lapply(types, function(type){
    
    if(file.exists(paste0(extraction.dir,label,"/",type,"/"))){
      monthly.files <- list.files(paste0(extraction.dir,label,"/",type), recursive=T, full.names=T)
      if(length(monthly.files)!=0){
        # Trim to only file names that are rasters
        monthly.files <- grep("*\\.tif$", monthly.files, value=TRUE)
        type.list.cropped <- raster::stack(monthly.files,native=F,quick=T)
        return(type.list.cropped)
      }
    }
    
    # Get all file names
    monthly.files <- list.files(paste0(prism.800.dir,type), recursive=T, full.names=T)
    
    # Trim to only file names that are rasters
    monthly.files <- grep("*\\.bil$", monthly.files, value=TRUE)
    monthly.files <- grep("spqc", monthly.files, value=TRUE, invert=T)
    monthly.files <- grep("/cai", monthly.files, value=TRUE)
    
    # Generate the raster stack
    type.list <- raster::unstack(raster::stack(monthly.files,native=F,quick=T))
    
    cl <- parallel::makeCluster(8)
    system.time(type.list.cropped <- parallel::parLapply(cl,type.list,function(type,prism.800.dir,extraction.dir,template,label,rast){
      layer.name <- basename(raster::filename(rast))
      yearmonth <- gsub(".*_","",layer.name)
      yearmonth <- gsub(".bil","",yearmonth)
      year <- as.numeric(substr(yearmonth,1,4))
      month <- as.numeric(substr(yearmonth,5,6))
      out.rast <- round(raster::crop(rast,template)*ifelse(type=='ppt',1,10))
      return(raster::writeRaster(out.rast,file=paste0(extraction.dir,label,"/",type,'/','Y',sprintf("%04d", year),'M',sprintf("%02d", month),'.tif'), datatype=ifelse(type=='ppt',"INT2U","INT2S"), options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"), overwrite=T, setStatistics=FALSE))
    },template=template, label=label, type=type,prism.800.dir=prism.800.dir, extraction.dir=extraction.dir))
    parallel::stopCluster(cl)
    
    type.list.cropped <- raster::stack(type.list.cropped, quick=T)
    
    return(type.list.cropped)
  })
  
  names(type.stacks) <- types
  return(type.stacks)
}