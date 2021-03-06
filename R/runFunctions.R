#' Select starting and ending points
#'
#' Get the coordinates of the starting and ending points
#'
#' @param X data points
#' @param X_labels labels of the data points
#' @param mode strategy for boundary selection
#' \itemize{
#'   \item 1 - centroids
#'   \item 2 - selected by the user
#'   \item 3 - insert the row name of the starting and ending points
#' }
#' @param from - starting class or row name of the starting point
#' @param to - ending class or row name of the ending point
#' @return list
#' \itemize{
#'   \item boundary ids - The indexes of the boundaries
#'   \item X - The new data matrix with the boundary
#'   \item X_labels - The new labels of the data matrix with the boundary labels
#' }
#' @export
spathial_boundary_ids <- function(X, X_labels, mode, from = NULL, to = NULL){
  if(mode == 2){
    X_2D <- spathial_2D(X)
    plot(X_2D$Y[,1],X_2D$Y[,2], pch=20,col="black",main="Click to select path start and end points")
    boundary_ids<-rownames(X)[identify(X,n=2,plot=FALSE)]
    points(
      X_2D$Y[boundary_ids,1], X_2D$Y[boundary_ids,2],pch="x",col="red",cex=4,
      xlab="Dimension 1",ylab="Dimension 2"
    )
  }else if(mode == 1){
    if(is.null(from) | is.null(to)){
      stop("You should insert the starting label and the ending label")
    }else if(!(from %in% X_labels)){
      stop("from is not a valid class")
    }else if(!(to %in% X_labels)){
      stop("to is not a valid class")
    }else{
      starting_centroid <- colMeans(X[which(X_labels == from),], na.rm = TRUE)
      ending_centroid <- colMeans(X[which(X_labels == to),], na.rm = TRUE)
      X <- rbind(X, starting_centroid, ending_centroid)
      rownames(X)[nrow(X):(nrow(X)-1)]<-c("Centroid2","Centroid1")
      X_labels <- c(X_labels, from)
      X_labels <- c(X_labels, to)
      names(X_labels)<-rownames(X)
      boundary_ids <- rownames(X[grep("Centroid", rownames(X)),])
    }
  }else if(mode == 3){
    if(is.null(from) | is.null(to)){
      stop("You should insert the starting label and the ending label")
    }else if(!(from %in% rownames(X)) ){
      stop("from is not an existing sample")
    }else if(!(to %in% rownames(X))){
      stop("to is not an existing sample")
    }else{
      starting_point <- X[which(rownames(X) == from),]
      ending_point <- X[which(rownames(X) == to),]
      boundary_ids <- rownames(rbind(starting_point, ending_point))
    }
  }else{
    stop("Insert a valid mode")
  }

  outlist<-list(
    X=X,
    X_labels=X_labels,
    boundary_ids=boundary_ids
  )
  return(outlist)
}

#' Principal Path core
#'
#' Get the coordinates of the waypoints of the principal path
#'
#' @param X data points
#' @param boundary_ids starting and ending points
#' @param NC number of waypoints
#' @param prefiltering a boolean
#' @return ppath - spathial waypoints
#' @export
spathial_way <- function(X, boundary_ids, NC, prefiltering){
  if(prefiltering){
    ### Prefilter the data (function pp.rkm_prefilter)
    prefiltered<-rkm_prefilter(X,boundary_ids,plot_ax=TRUE)
    X<-prefiltered$X_filtered
    boundary_ids<-prefiltered$boundary_ids_filtered
    X_g<-prefiltered$X_garbage
    rm(prefiltered)
  }

  ### Initialize waypoints
  waypoint_ids<-initMedoids(X, NC, 'kpp', boundary_ids)
  waypoint_ids<-c(boundary_ids[1],waypoint_ids,boundary_ids[2])
  init_W<-X[waypoint_ids,]

  ### Annealing with rkm
  s_span<-pracma::logspace(5,-5)  #REMOVED ,n=NC -- the number of paths generated is different from the number of waypoint for each of them
  s_span<-c(s_span,0)
  #models<-array(data=NA,dim=c(length(s_span),NC+2,ncol(X)))
  #s<-s_span[1]

  models<-list()
  pb<-txtProgressBar(0,length(s_span),style=3)
  for(i in 1:length(s_span)){
    s<-s_span[i]
    W<-rkm(X,init_W,s,plot_ax=FALSE)
    init_W<-W
    models[[as.character(s)]]<-W
    #models[i,,]<-W
    setTxtProgressBar(pb,i)
  }
  W_dst_var <- rkm_MS_pathvar(models, s_span, X)
  s_elb_id <- find_elbow(cbind(s_span, W_dst_var))
  ppath <- models[[s_elb_id]]
  return(ppath)
}


#' Find labels
#'
#' Get the label of each waypoint accordin to the neighbourhood
#'
#' @param X data points
#' @param X_labels labels of the data points
#' @param ppath waypoints
#' @return ppath_labels - labels of the waypoints
#' @export
spathial_labels <- function(X, X_labels, ppath){
  library(class)
  X_labels <- X_labels[which(! grepl("Centroid", rownames(X)))]
  X <- X[which(! grepl("Centroid", rownames(X))),]
  ppath_no_centroids <- ppath[2:(nrow(ppath)-1), ]
  lbl <- knn(X, ppath_no_centroids, cl=X_labels, k=1)
  plot(c(1:length(lbl)), c(lbl), col=lbl, pch=19)
  return(lbl)
}

#' 2D spathial
#'
#' Get the 2D coordinates of each waypoint (using t-SNE algorithm for the dimensionality reduction)
#'
#' @param X data points
#' @param X_labels labels of the data points
#' @param ppath waypoints
#' @export
spathial_2D_plot <- function(X, X_labels, boundary_ids, ppath){
  ppath <- ppath[2:(nrow(ppath)-1),]
  rownames(ppath) <- paste("ppath",1:nrow(ppath))
  ppath_labels <- array(data = -1, dim=(nrow(ppath)))
  total_labels <- c(X_labels, ppath_labels)
  all_points <- rbind(X, ppath)

  library(Rtsne())
  set.seed(1)
  tsne_res <- Rtsne(as.matrix(all_points), dims = 2, perplexity = 1)
  points_2D <- tsne_res$Y

  X_2D <- points_2D[which(total_labels != -1 & total_labels != 0),]
  boundary_ids_2D <- points_2D[which(rownames(X) == boundary_ids[1] | rownames(X) == boundary_ids[2]),]
  ppath_2D <- points_2D[which(total_labels == -1),]
  ppath_2D <- rbind(boundary_ids_2D[1,], ppath_2D, boundary_ids_2D[2,])

  plot(X_2D[,1],X_2D[,2], col=X_labels, pch=19)
  points(boundary_ids_2D[,1],boundary_ids_2D[,2], col="black", pch=3)
  lines(ppath_2D[,1], ppath_2D[,2],lwd=3,col="blue",type="o",pch=15)
}

#' Correlation
#'
#' Get how much the features correlates with the path
#'
#' @param ppath waypoints
#' @return corr - correlation along the path
#' @export
spathial_corr <- function(ppath){
  colnames <- colnames(ppath[,,1])
  ppath <- array(unlist(ppath),dim=c(NC+2, ncol(X), (negb*negb)))

  correlations <- array(data = 0, dim=(c(dim(ppath)[3], dim(ppath)[2])))
  corr <- array(data = 0, dim=(dim(ppath)[2]))
  for(i in (1:dim(ppath)[3])){
    for(j in (1:dim(ppath)[2])){
      correlations[i,j] <- cor(ppath[,j,i], c(1:dim(ppath)[1]))
    }
  }
  correlations <- colMeans(correlations)
  #correlations <- apply(ppath, 3, function(x){
   # corr <- apply(x, 2, function(y){
    #  cor(y, c(1:length(y)))
    #})
    #return(corr)
  #})
  #return(correlations)
}

#' Compute Principal Path
#'
#' Get the coordinates of the waypoints of the principal path
#'
#' @param X data points
#' @param X_labels labels of the data points
#' @param boundary_ids starting and ending points
#' @param NC number of waypoints
#' @param prefiltering a boolean
#' @param negb the number of nearest nearest point to consider
#' @return ppath - spathial waypoints
#' @export
spathial_way_multiple <- function(X, X_labels, boundary_ids, NC, prefiltering, negb = NULL){
  if(is.null(negb)){
    negb <- 1
  }

  if(negb == 1){
    ppath <- spathial_way(X, boundary_ids, NC, prefiltering)
    colnames(ppath) <- colnames(X)
    perturbed_path <- NULL
  }
  else{
    ppath <- spathial_way(X, boundary_ids, NC, prefiltering)
    colnames(ppath) <- colnames(X)

    starting_class <- X_labels[which(rownames(X) == boundary_ids[1])]
    ending_class <- X_labels[which(rownames(X) == boundary_ids[2])]

    message(starting_class)
    message(ending_class)

    element_starting_class <- X[which(X_labels == starting_class),]
    element_ending_class <- X[which(X_labels == ending_class),]

    starting_class_neighbour <- find_nearest_points(X[which(rownames(X) == boundary_ids[1]),], element_starting_class, negb)
    ending_class_neighbour <- find_nearest_points(X[which(rownames(X) == boundary_ids[2]),], element_ending_class, negb)

    message(starting_class_neighbour)
    message(ending_class_neighbour)

    perturbed_path <- lapply(starting_class_neighbour, function(x){
      lapply(ending_class_neighbour, function(y){
        boundary_ids <- c(x, y)
        message("PP_start")
        perturbed <- spathial_way(X, boundary_ids, NC, prefiltering)
        message("PP_completed")
        colnames(perturbed) <- colnames(X)
        #return(as.matrix(pp))
        return(perturbed)
      })
    })
  }

  outlist<-list(
    ppath=ppath,
    perturbed_path=perturbed_path
  )
  return(outlist)
}

#' Get the names of the N-nearest points
#'
#' Get the name of the nearest point to one specified
#'
#' @param point a specific point
#' @param points the other points
#' @param negb the number of desired nearest neighbours
#' @return nearest_name - the name of the nearest points
#' @export
find_nearest_points <- function(point, points, negb){
  library(fields)
  #distances <- apply(points, 1, function(x){
    #dist <- sqrt(sum((point-x)^2))
    #dist <- rdist(point, x)
    #message(dist)
    #return(dist)
  #})
  distances <- rdist(point, points)
  ord <- order(distances)
  nearest_name <- rownames(points[ord[1:negb],])
  return(nearest_name)
}
