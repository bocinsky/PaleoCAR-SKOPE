demosaic <- function(raster_brick, corners, out_dir=NULL, corner_loc="SW"){
  out_brick_list <- apply(corners,1,function(corner){
    cat("\nTesting location",corner)
    raster::crop(raster_brick,raster::extent(corner[1],corner[1]+1,corner[2],corner[2]+1))
  })
  
  names(out_brick_list) <- paste0(0-corners[,1],"W",corners[,2],"N")
  
  if(!is.null(out_dir)){
    dir.create(out_dir, showWarnings=F)
    for(i in 1:length(out_brick_list)){
      writeRaster(out_brick_list[[i]],paste0(out_dir,names(out_brick_list)[i],'.tif'), datatype="INT2S", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"),overwrite=T,setStatistics=FALSE)
    }
  }
  
  return(out_brick_list)
}