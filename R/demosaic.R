demosaic <- function(raster_brick, corners, out_dir, corner_loc="SW", datatype="INT2S"){
  dir.create(out_dir, showWarnings=F)
  
  corners <- lapply(1:nrow(corners),function(i){as.numeric(corners[i,])})
  
  cl <- parallel::makeCluster(8)
  junk <- parallel::parLapply(cl, corners, function(raster_brick, out_dir, datatype, corner){
    if(file.exists(paste0(out_dir,0-corner[1],"W",corner[2],"N",".tif"))) return()
    out <- raster::crop(raster_brick,raster::extent(corner[1],corner[1]+1,corner[2],corner[2]+1), filename=paste0(out_dir,0-corner[1],"W",corner[2],"N",".tif"), datatype=datatype, options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"),overwrite=T,setStatistics=FALSE)
    return()
  }, raster_brick=raster_brick, out_dir=out_dir, datatype=datatype)
  parallel::stopCluster(cl)
  
  return(raster::stack(list.files(out_dir, full.names=T), quick=T))
  
  #   names(out_brick_list) <- paste0(0-corners[,1],"W",corners[,2],"N")
  #   
  #   if(!is.null(out_dir)){
  #     dir.create(out_dir, showWarnings=F)
  #     for(i in 1:length(out_brick_list)){
  #       writeRaster(out_brick_list[[i]],paste0(out_dir,names(out_brick_list)[i],'.tif'), datatype="INT2S", options=c("COMPRESS=DEFLATE", "ZLEVEL=9", "INTERLEAVE=BAND"),overwrite=T,setStatistics=FALSE)
  #     }
  #   }
  #   
  #   return(out_brick_list)
}