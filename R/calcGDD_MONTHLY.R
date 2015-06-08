calcGDD_MONTHLY <- function(tmin_brick, tmax_brick, t.base, t.cap=NULL, to_fahrenheit=T){
  if(nlayers(tmin_brick)!=nlayers(tmax_brick)){
    stop("tmin and tmax bricks must have same number of layers!")
  }
  
  # Floor tmax and tmin at Tbase
  tmin_brick <- calc(tmin_brick,function(x) { x[x<t.base] <- t.base; return(x) })
  tmax_brick <- calc(tmax_brick,function(x) { x[x<t.base] <- t.base; return(x) })
  
  # Cap tmax and tmin at Tut
  if(!is.null(t.cap)){
    tmin_brick <- calc(tmin_brick,function(x) { x[x>t.cap] <- t.cap; return(x) })
    tmax_brick <- calc(tmax_brick,function(x) { x[x>t.cap] <- t.cap; return(x) })
  }
  
  GDD_brick <- ((tmin_brick+tmax_brick)/2)-t.base
  GDD_brick_months <- as.numeric(gsub("Y\\d{4}[.]M","",names(GDD_brick)))
  
  year_months <- 1:12
  days_per_month <- c(31,28,31,30,31,30,31,31,30,31,30,31)
  
  GDD_brick_days <- as.numeric(mapply(gsub, year_months, days_per_month, GDD_brick_months))
  
  # Multiply by days per month, and convert to Fahrenheit GDD
  GDD_brick <- GDD_brick * GDD_brick_days
  
  if(to_fahrenheit){
    GDD_brick <- GDD_brick * 1.8
  }
  
  return(GDD_brick)
}