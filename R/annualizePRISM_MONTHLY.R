annualizePRISM_MONTHLY <- function(prism.brick, months=c(1:12), fun){
  brick.names <- names(prism.brick)
  brick.years <- as.numeric(lapply(strsplit(brick.names,"[A-Z]"),'[[',2))
  brick.months <- as.numeric(lapply(strsplit(brick.names,"[A-Z]"),'[[',3))
  
  # If more months than a year, break
  if(length(months)>12){
    stop("ERROR! Too many months.")
  }
  
  # Process the months to get months from current, previous, and future years
  previous.year <- 12+months[months<1]
  current.year <- months[months>=1 & months<=12]
  next.year <- months[months>12]-12
  no.year <- (1:12)[!(1:12 %in% c(previous.year,current.year,next.year))]
  
  brick.years[brick.months %in% previous.year] <- brick.years[brick.months %in% previous.year]+1
  brick.years[brick.months %in% next.year] <- brick.years[brick.months %in% next.year]-1
  brick.years[brick.months %in% no.year] <- 0
  
  prism.brick <- prism.brick[[which(brick.years %in% c(0,as.numeric(names(table(brick.years))[table(brick.years)==length(months)])))]]
  brick.years <- brick.years[which(brick.years %in% c(0,as.numeric(names(table(brick.years))[table(brick.years)==length(months)])))]
  
#   signal.brick.temp <- setZ(prism.brick, brick.years, "year")
  
  if(fun=="sum"){
    signal.brick.temp <- stackApply(signal.brick.temp, indices=as.integer(as.factor(brick.years)), fun=sum)
  }else if(fun=="mean"){
    signal.brick.temp <- stackApply(signal.brick.temp, indices=as.integer(as.factor(brick.years)), fun=mean)
  }
  
  return(signal.brick.temp)
}
