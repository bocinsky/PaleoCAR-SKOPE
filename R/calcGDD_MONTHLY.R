calcGDD_MONTHLY <- function(tmin_brick, tmax_brick, t.base, t.cap=NULL, to_fahrenheit=T, output.dir='./gdd/'){
  if(nlayers(tmin_brick)!=nlayers(tmax_brick)){
    stop("tmin and tmax bricks must have same number of layers!")
  }
  
  files <- names(tmin_brick)
  files <- gsub("tmin","gdd",files)
  
  GDD_months <- as.numeric(substr(gsub("\\D","",names(tmin_brick)),7,8))
  year_months <- 1:12
  days_per_month <- c(31,28,31,30,31,30,31,31,30,31,30,31)
  GDD_days <- as.numeric(mapply(gsub, year_months, days_per_month, GDD_months))
  
  for(i in 1:nlayers(tmin_brick)){
    if(file.exists(paste0(output.dir,files[i],".tif"))) next
    tmin <- tmin_brick[[i]]
    tmax <- tmax_brick[[i]]
    
    # Floor tmax and tmin at Tbase
    tmin <- calc(tmin,function(x) { x[x<t.base] <- t.base; return(x) })
    tmax <- calc(tmax,function(x) { x[x<t.base] <- t.base; return(x) })
    
    # Cap tmax and tmin at Tut
    if(!is.null(t.cap)){
      tmin <- calc(tmin,function(x) { x[x>t.cap] <- t.cap; return(x) })
      tmax <- calc(tmax,function(x) { x[x>t.cap] <- t.cap; return(x) })
    }
    
    GDD <- ((tmin+tmax)/2)-t.base
    
    # Multiply by days per month, and convert to Fahrenheit GDD
    GDD <- GDD * GDD_days[i]
    
    if(to_fahrenheit){
      GDD <- GDD * 1.8
    }
    
    GDD <- round(GDD)
    
    writeRaster(GDD,paste0(output.dir,files[i],".tif"), datatype="INT2U", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"),overwrite=T,setStatistics=FALSE)
  }

  return(stack(list.files(output.dir, full.names=T), quick=T))
}