sacsmamodel <- function (etp, prec, Qin, Qout, N, Area, Params=c(5.842, 836.713, 0.787473, 1499.808, 0.8013374, 499.930,  84.984, 1842.081, 0.091967, 0.003917, 0.849845, 0.008715, 0.001861, 0.380005, 0.999997, 0.112234)) {

  storage.mode(etp) <- "double"
  storage.mode(prec) <- "double"
  storage.mode(Qin) <- "double"
  storage.mode(Qout) <- "double"
  storage.mode(N) <- "integer"
  storage.mode(Area) <- "double"
  storage.mode(Params) <- "double"
  Qbac <- rep(-99.9, length(prec))

  dummy <- .Fortran("sacsmamodel", etp=etp, prec=prec, Qin=Qin, Qout=Qout, N=N, Area=Area, Params=Params, Qbac=Qbac, PACKAGE="hydrologymodels")

 return(dummy)
}
