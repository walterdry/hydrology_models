
paran <- c(5.842, 836.713, 0.787473, 1499.808, 0.8013374, 499.930,  84.984, 1842.081, 0.091967, 0.003917, 0.849845, 0.008715, 0.001861, 0.380005, 0.999997, 0.112234)
hola <- sacsmamodel(ETp = etp, CMB=lluvia, Qin = rep(0, length(lluvia)), Qout = caudal, N=length(lluvia), Area = area_cuenca, Params = paran)

