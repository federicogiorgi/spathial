% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/linearUtilities.R
\name{find_elbow}
\alias{find_elbow}
\title{Find the elbow in a fuction f, as the point on f with max distance
from the line connecting f[0,:] and f[-1,:]}
\usage{
find_elbow(f)
}
\arguments{
\item{f:}{function(Nx2 array in the form [x, f(x)])}
}
\value{
elb_id: index of the elbow
}
\description{
Find the elbow in a fuction f, as the point on f with max distance
from the line connecting f[0,:] and f[-1,:]
}
