
## ----------------------------------------------------------------------------
## PERTURBATIONS
## ----------------------------------------------------------------------------


# internal functions


IntegrateSol <- function(FDET, N.Pert, porGrid, Grid)
    sum(FDET[1:N.Pert] * (1.-porGrid$mid[1:N.Pert]) * Grid$dx[1:N.Pert])

IntegrateLiq <- function(CONC, N.Pert,porGrid, Grid)
    sum(CONC[1:N.Pert] * porGrid$mid[1:N.Pert] * Grid$dx[1:N.Pert])

#===============================================================================
# Function to mix a solid, e.g. detritus  - same as in CNPDIA
#===============================================================================

MixDET <- function (FDET, N.Pert, porGrid, Grid) {
  # Integrated concentration
   TotalFdet <- sum(FDET[1:N.Pert] *
                   (1.-porGrid$mid[1:N.Pert]) * Grid$dx[1:N.Pert])
   
  # approximate mean concentration
   MeanFdet <- TotalFdet / sum(Grid$dx[1:N.Pert])

   TotalFdet2 <- sum(MeanFdet *
                  (1.-porGrid$mid[1:N.Pert]) * Grid$dx[1:N.Pert])

   if (TotalFdet2 > 0 )
     Fac <- TotalFdet / TotalFdet2
   else
     Fac <- 1

  # Mixed concentration
   FDET[1:N.Pert] <- MeanFdet*Fac
   return(FDET)
}

#===============================================================================
# Deposition of detritus on top of sediment
#===============================================================================

DepositDET <- function (FDET, N.Pert, porGrid, Grid, fac) {
  # Integrated concentration
   TotalFdet <- sum(FDET[1:N.Pert] *
                   (1.-porGrid$mid[1:N.Pert]) * Grid$dx[1:N.Pert])
  # approximate mean concentration
   MeanFdet <- TotalFdet / sum(Grid$dx[1:N.Pert])
   TotalFdet2 <- sum(MeanFdet *
                  (1.-porGrid$mid[1:N.Pert]) * Grid$dx[1:N.Pert])

   if (TotalFdet2 > 0 )
     Fac <- TotalFdet / TotalFdet2* fac
   else
     Fac <- 1
   
    NewGrid <- c(Grid$x.mid[1:N.Pert], Grid$x.mid+Grid$x.mid[N.Pert+1])
    FDETerode <- c(rep(MeanFdet*Fac, N.Pert), FDET)
    FDETn <- approx(x = NewGrid, y = FDETerode, xout = Grid$x.mid)$y
    
    FDETn <- mixDET_bound(FDETn)
#    FDETn <- oce::lowpass(runmed(FDETn, k = 5), n = 5)

   return(FDETn)
}


#===============================================================================
# Deposition for dissolved substances -  interstitial conc = bottom water conc
#===============================================================================

DepositBW <- function (O2, N.Pert, bwO2, Grid) {
    NewGrid <- c(Grid$x.mid[1:N.Pert], Grid$x.mid+Grid$x.mid[N.Pert+1])
    O2erode <- c(rep(bwO2, N.Pert), O2)
    O2n <- approx(x = NewGrid, y = O2erode, xout = Grid$x.mid)$y

   return(O2n)
}

#===============================================================================
# Erosion of the top of the sediment
#===============================================================================

Erode <- function (FDET, N.Pert, porGrid, Grid) {

   NewGrid   <- c(Grid$x.mid[-(1:N.Pert)]-Grid$x.mid[N.Pert+1], Grid$x.mid[Grid$N])
   FDETerode <- c(FDET[-(1:N.Pert)], FDET[Grid$N])
   FDETn     <- approx(x = NewGrid, y = FDETerode, xout = Grid$x.mid)$y

   return(FDETn)
}

## --------------------------------------------------------------------------------------------------
## --------------------------------------------------------------------------------------------------
# Main FESDIA perturbation function
## --------------------------------------------------------------------------------------------------
## --------------------------------------------------------------------------------------------------

FESDIAperturb <- function (parms = list(), times = 0:365, spinup = NULL, 
     yini = NULL, gridtype = 1, Grid = NULL, porosity = NULL, bioturbation = NULL, 
     irrigation = NULL, surface = NULL, 
     diffusionfactor = NULL,  dynamicbottomwater = FALSE, 
     perturbType = "deposit", perturbTimes, 
     perturbDepth = 5, concfac = NULL, 
     CfluxForc  = NULL, FeOH3fluxForc = NULL, CaPfluxForc = NULL,  
     O2bwForc   = NULL,   NO3bwForc  = NULL,  
     NO2bwForc  = NULL,   NH3bwForc  = NULL,  FebwForc   = NULL,  
     H2SbwForc  = NULL,   SO4bwForc  = NULL,  CH4bwForc  = NULL,  
     PO4bwForc  = NULL,   DICbwForc  = NULL,  ALKbwForc  = NULL, 
     wForc      = NULL,   biotForc   = NULL,  irrForc    = NULL,  
     rFastForc  = NULL,   rSlowForc  = NULL,  pFastForc  = NULL,  
     MPBprodForc= NULL,  gasfluxForc = NULL,  HwaterForc = NULL, 
     ratefactor = NULL,  MnbwForc = NULL,     MnO2fluxForc = NULL,  
     verbose = FALSE, ...) {
  
  # if(length(concfac) == 1) concfac <- rep(concfac, 6)
  if(is.null(concfac)) concfac <- matrix(1, nrow = length(perturbTimes), ncol = 6)

## check parameter inputs
  model <- 1
  CaCO3fluxForc <- NULL
  ARAGfluxForc  <- NULL
  CabwForc      <- NULL
  if (dynamicbottomwater) model <- 2

  
  CfluxForc    <- checkforcs(CfluxForc,       "CfluxForc")
  FeOH3fluxForc<- checkforcs(FeOH3fluxForc, "FeOH3fluxForc")
  CaPfluxForc  <- checkforcs(CaPfluxForc,     "CaPfluxForc")
  O2bwForc     <- checkforcs(O2bwForc ,        "O2bwForc")
  NO3bwForc    <- checkforcs(NO3bwForc,       "NO3bwForc")
  NO2bwForc    <- checkforcs(NO2bwForc,       "NO2bwForc")
  NH3bwForc    <- checkforcs(NH3bwForc,       "NH3bwForc")
  H2SbwForc    <- checkforcs(H2SbwForc,       "H2SbwForc")
  SO4bwForc    <- checkforcs(SO4bwForc,       "SO4bwForc")
  CH4bwForc    <- checkforcs(CH4bwForc,       "CH4bwForc")
  PO4bwForc    <- checkforcs(PO4bwForc,       "PO4bwForc")
  FebwForc     <- checkforcs(FebwForc,        "FebwForc")
  DICbwForc    <- checkforcs(DICbwForc,       "DICbwForc")
  ALKbwForc    <- checkforcs(ALKbwForc,       "ALKbwForc")
  wForc        <- checkforcs(wForc,               "wForc")
  biotForc     <- checkforcs(biotForc,         "biotForc")
  irrForc      <- checkforcs(irrForc,           "irrForc")
  rFastForc    <- checkforcs(rFastForc,       "rFastForc")
  rSlowForc    <- checkforcs(rSlowForc,       "rSlowForc")
  pFastForc    <- checkforcs(pFastForc,       "pFastForc")
  MPBprodForc  <- checkforcs(MPBprodForc,   "MPBprodForc")
  gasfluxForc  <- checkforcs(gasfluxForc,   "gasfluxForc")
  HwaterForc   <- checkforcs(HwaterForc,     "HwaterForc") 
  CaCO3fluxForc <- checkforcs(CaCO3fluxForc, "CaCO3fluxForc")
  ARAGfluxForc  <- checkforcs(ARAGfluxForc ,  "ARAGfluxForc")
  CabwForc      <- checkforcs(CabwForc,           "CabwForc")
  
  ratefactor   <- checkforcs(ratefactor,     "ratefactor")
  
  MnbwForc      <- checkforcs(MnbwForc,           "MnbwForc")
  MnO2fluxForc  <- checkforcs(MnO2fluxForc,    "MnO2fluxForc")

  Hlist <- list(Hwater = 1)

  if (is.null(spinup)) Times <- times else Times <- spinup
  
  if (is.null(yini)) {
    STD <- FESDIAsolve_full(parms, gridtype = gridtype, CfluxForc = CfluxForc, 
                      O2bwForc  = O2bwForc, NO3bwForc = NO3bwForc, 
                      NO2bwForc = NO2bwForc, NH3bwForc = NH3bwForc,
                      CH4bwForc = CH4bwForc, FebwForc = FebwForc, H2SbwForc = H2SbwForc,
                      SO4bwForc = SO4bwForc, PO4bwForc = PO4bwForc, DICbwForc = DICbwForc, ALKbwForc = ALKbwForc,
                      gasfluxForc = gasfluxForc, wForc = wForc, biotForc = biotForc, irrForc = irrForc, ratefactor = ratefactor,
                      rFastForc = rFastForc, rSlowForc = rSlowForc, pFastForc = pFastForc, 
                      MPBprodForc = MPBprodForc, HwaterForc = HwaterForc,
                      times = Times, Grid = Grid, porosity = porosity,
                      bioturbation = bioturbation, irrigation = irrigation,
                      surface = surface, diffusionfactor = diffusionfactor, 
		                  MnbwForc = MnbwForc, MnO2fluxForc = MnO2fluxForc,
                      model = model, verbose = verbose)
    yini <- STD$y
  } else  
    STD <- initFESDIA(parms, gridtype = gridtype, CfluxForc = CfluxForc, 
                      O2bwForc  = O2bwForc, NO3bwForc = NO3bwForc, 
                      NO2bwForc = NO2bwForc, NH3bwForc = NH3bwForc,
                      CH4bwForc = CH4bwForc, FebwForc = FebwForc, H2SbwForc = H2SbwForc,
                      SO4bwForc = SO4bwForc, PO4bwForc = PO4bwForc, DICbwForc = DICbwForc, ALKbwForc = ALKbwForc,
                      gasfluxForc = gasfluxForc, wForc = wForc, biotForc = biotForc, irrForc = irrForc, ratefactor = ratefactor,
                      rFastForc = rFastForc, rSlowForc = rSlowForc, pFastForc = pFastForc, 
                      MPBprodForc = MPBprodForc, HwaterForc = HwaterForc,
                      times = Times, Grid = Grid, porosity = porosity, 
                      bioturbation = bioturbation, irrigation = irrigation,
		                  MnbwForc = MnbwForc, MnO2fluxForc = MnO2fluxForc,
                      surface = surface, 
                      diffusionfactor = diffusionfactor, model = model)
  Grid <- STD$Grid
  porGrid <- STD$porGrid

  pertCONC <- yini
  PertFlux <- PertBW <- PertBW2 <- NULL 
  events <- NULL

  Parms <- STD$Parms
  PP <- unlist(Parms)

  nspec        <- 22

  ## event time counter index
  tindex <- 0
  tmap <- 0
#===============================================================================
# Function to Perturb all states
#===============================================================================

   Perturb <- function (out, t) {

    ## time dependent alpha/concfac and pertdepth
    ## The concfac and pertdepth is now given as matrix 
    ## pertdepth is a N x 1 vector 
    ## concfac is a N x length(confac) matrix
     
     cat("time is: ", t, "\n")

    if(t == 0){

      tindex <<- 0
      
      depthPert <- perturbDepth[1, ]
      perttype <- match.arg(perturbType[1, ], c("mix", "erode", "deposit"), several.ok = TRUE)

      depthPert <- rep(depthPert, length.out = length(perttype))
      # depthPert <- rep(depthPert, each = length(perttype))
      names(depthPert) <- as.character(perttype)
      numPert <- length(depthPert)


      alpha <- concfac[1, ]
      c1 = alpha[1]
      c2 = alpha[2]
      c3 = alpha[3]
      c4 = alpha[4]
      c5 = alpha[5]
      c6 = alpha[6]
    }


    if(t != 0){
      cat("time is: ", t, "\n")

      tindex <<- tindex + 1
      
      perttype <- match.arg(perturbType[tindex, ], c("mix", "erode", "deposit"), several.ok = TRUE)
      depthPert <- perturbDepth[tindex, ]
      
      depthPert <- rep(depthPert, length.out = length(perttype))
      # depthPert <- rep(depthPert, each = length(perttype))
      
      names(depthPert) <- as.character(perttype)
      numPert <- length(depthPert)

      alpha <- concfac[tindex, ]
      c1 = alpha[1]
      c2 = alpha[2]
      c3 = alpha[3]
      c4 = alpha[4]
      c5 = alpha[5]
      c6 = alpha[6]
    }

    # Number of layers that are perturbed 
    # Note: there can be more than one type of perturbation 

    N.Pert <- rep(0, times = length(depthPert))
    
    # cat("Depthpert: ", depthPert, "\n")

    for (i in 1:length(depthPert[1]))
    N.Pert[i] <- length(Grid$x.int[Grid$x.int < depthPert[i]])
    names(N.Pert) <- as.character(perttype)

    
    for(i in 1:length(depthPert[1])){
    }

    
    
    ii <- which (N.Pert > 0)

    
    # cat("N.pert: ", N.Pert, "\n")
     
    # integrated concentrations over the perturbed sediment layer
    if ("steady1D" %in% class(out))
      pertCONC <- out$y
    else
      pertCONC <- matrix(ncol = nspec, out, byrow = FALSE)

    colnames(pertCONC) <- .FESDIA$ynames
    
    Fluxes <-  c(FDET= 0,   SDET= 0,   O2  = 0,   NO3 = 0,
                 NO2 = 0,   NH3 = 0,   DIC = 0,   Fe = 0,
                 FeOH3 = 0, H2S = 0,   SO4 = 0,   CH4 = 0,
                 PO4 = 0,   FeP = 0,   CaP = 0,   Pads= 0, 
		            ALK = 0, FeOH3B = 0,  Mn  = 0,   MnO2 = 0, 
    		        MnO2B = 0, MnCO3 = 0)

    if (model == 1){
      bw_O2  <- bwO2(t)
      bw_NO3 <- bwNO3(t)
      bw_NO2 <- bwNO2(t)
      bw_NH3 <- bwNH3(t)
      bw_CH4 <- bwCH4(t)
      bw_DIC <- bwDIC(t)
      bw_ALK <- bwALK(t)
      bw_PO4 <- bwPO4(t)
      bw_H2S <- bwH2S(t)
      bw_SO4 <- bwSO4(t)
      bw_Fe  <- bwFe(t)
      bw_Mn  <- bwMn(t)
    } else {     # dynamic bottom water concentrations
      BW       <- pertCONC[1,]
      pertCONC <- pertCONC[-1,]
      bw_O2  <- BW["O2"]
      bw_NO3 <- BW["NO3"]
      bw_NO2 <- BW["NO2"]
      bw_NH3 <- BW["NH3"]
      bw_CH4 <- BW["CH4"]
      bw_DIC <- BW["DIC"]
      bw_ALK <- BW["ALK"]
      bw_PO4 <- BW["PO4"]
      bw_SO4 <- BW["SO4"]
      bw_H2S <- BW["H2S"]
      bw_Fe  <- BW["Fe"]
      bw_Mn  <- BW["Mn"]
    }

    for (i in ii){

    O2Conc  <- IntegrateLiq(pertCONC[ ,"O2"] , .FESDIA$N, porGrid, Grid)
    NO3Conc <- IntegrateLiq(pertCONC[ ,"NO3"], .FESDIA$N, porGrid, Grid)
    NO2Conc <- IntegrateLiq(pertCONC[ ,"NO2"], .FESDIA$N, porGrid, Grid)
    NH3Conc <- IntegrateLiq(pertCONC[ ,"NH3"], .FESDIA$N, porGrid, Grid)
    PO4Conc <- IntegrateLiq(pertCONC[ ,"PO4"], .FESDIA$N, porGrid, Grid)
    DICConc <- IntegrateLiq(pertCONC[ ,"DIC"], .FESDIA$N, porGrid, Grid)
    ALKConc <- IntegrateLiq(pertCONC[ ,"ALK"], .FESDIA$N, porGrid, Grid)
    CH4Conc <- IntegrateLiq(pertCONC[ ,"CH4"], .FESDIA$N, porGrid, Grid)
    H2SConc <- IntegrateLiq(pertCONC[ ,"H2S"], .FESDIA$N, porGrid, Grid)
    SO4Conc <- IntegrateLiq(pertCONC[ ,"SO4"], .FESDIA$N, porGrid, Grid)
    FeConc  <- IntegrateLiq(pertCONC[ ,"Fe" ], .FESDIA$N, porGrid, Grid)
    FDETConc  <- IntegrateSol(pertCONC[ ,"FDET"] ,.FESDIA$N, porGrid, Grid)
    SDETConc  <- IntegrateSol(pertCONC[ ,"SDET"] ,.FESDIA$N, porGrid, Grid)
    FePConc   <- IntegrateSol(pertCONC[ ,"FeP"]  ,.FESDIA$N, porGrid, Grid)
    CaPConc   <- IntegrateSol(pertCONC[ ,"CaP"]  ,.FESDIA$N, porGrid, Grid)
    PadsConc  <- IntegrateSol(pertCONC[ ,"Pads"] ,.FESDIA$N, porGrid, Grid)
    FeOH3Conc <- IntegrateSol(pertCONC[ ,"FeOH3"],.FESDIA$N, porGrid, Grid)
    FeOH3BConc <- IntegrateSol(pertCONC[ ,"FeOH3B"],.FESDIA$N, porGrid, Grid)

    MnConc    <- IntegrateLiq(pertCONC[ ,"Mn" ], .FESDIA$N, porGrid, Grid)
    MnO2Conc  <- IntegrateSol(pertCONC[ ,"MnO2"],.FESDIA$N, porGrid, Grid)
    MnO2BConc <- IntegrateSol(pertCONC[ ,"MnO2B"],.FESDIA$N, porGrid, Grid)
    MnCO3Conc <- IntegrateSol(pertCONC[ ,"MnCO3"],.FESDIA$N, porGrid, Grid)

    if (perttype[i] == "mix") {    # mixed
      pertCONC[,"FDET"]  <- MixDET (pertCONC[,"FDET"], N.Pert[i], porGrid, Grid)
      pertCONC[,"SDET"]  <- MixDET (pertCONC[,"SDET"], N.Pert[i], porGrid, Grid)
      pertCONC[,"FeP"]   <- MixDET (pertCONC[,"FeP"] , N.Pert[i], porGrid, Grid)
      pertCONC[,"CaP"]   <- MixDET (pertCONC[,"CaP"] , N.Pert[i], porGrid, Grid)
      pertCONC[,"Pads"]  <- MixDET (pertCONC[,"Pads"], N.Pert[i], porGrid, Grid)
      pertCONC[,"FeOH3"] <- MixDET (pertCONC[,"FeOH3"],N.Pert[i], porGrid, Grid)
      pertCONC[,"FeOH3B"] <- MixDET (pertCONC[,"FeOH3B"],N.Pert[i], porGrid, Grid)
      pertCONC[,"MnO2"]   <- MixDET (pertCONC[,"MnO2"],N.Pert[i], porGrid, Grid)
      pertCONC[,"MnO2B"]  <- MixDET (pertCONC[,"MnO2B"],N.Pert[i], porGrid, Grid)
      pertCONC[,"MnCO3"]  <- MixDET (pertCONC[,"MnCO3"],N.Pert[i], porGrid, Grid)
      pertCONC[1:N.Pert[i], "O2"]  <- bw_O2
      pertCONC[1:N.Pert[i], "NO3"] <- bw_NO3
      pertCONC[1:N.Pert[i], "NO2"] <- bw_NO2
      pertCONC[1:N.Pert[i], "NH3"] <- bw_NH3
      pertCONC[1:N.Pert[i], "DIC"] <- bw_DIC
      pertCONC[1:N.Pert[i], "ALK"] <- bw_ALK
      pertCONC[1:N.Pert[i], "PO4"] <- bw_PO4
      pertCONC[1:N.Pert[i], "CH4"] <- bw_CH4
      pertCONC[1:N.Pert[i], "H2S"] <- bw_H2S
      pertCONC[1:N.Pert[i], "SO4"] <- bw_SO4
      pertCONC[1:N.Pert[i], "Fe" ] <- bw_Fe
      pertCONC[1:N.Pert[i], "Mn" ] <- bw_Mn

     } else if (perttype[i] == "erode") {  # erosion
       pertCONC[,"FDET"] <- Erode (pertCONC[,"FDET"] , N.Pert[i], porGrid, Grid)
       pertCONC[,"SDET"] <- Erode (pertCONC[,"SDET"] , N.Pert[i], porGrid, Grid)
       pertCONC[,"FeP"]  <- Erode (pertCONC[,"FeP"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"CaP"]  <- Erode (pertCONC[,"CaP"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"Pads"] <- Erode (pertCONC[,"Pads"] , N.Pert[i], porGrid, Grid)
       pertCONC[,"FeOH3"]<- Erode (pertCONC[,"FeOH3"], N.Pert[i], porGrid, Grid)
       pertCONC[,"FeOH3B"]<- Erode (pertCONC[,"FeOH3B"], N.Pert[i], porGrid, Grid)
       pertCONC[,"MnO2"] <- Erode (pertCONC[,"MnO2"], N.Pert[i], porGrid, Grid)
       pertCONC[,"MnO2B"] <- Erode (pertCONC[,"MnO2B"], N.Pert[i], porGrid, Grid)
       pertCONC[,"MnCO3"] <- Erode (pertCONC[,"MnCO3"], N.Pert[i], porGrid, Grid)
       pertCONC[,"O2"]   <- Erode (pertCONC[,"O2"]   , N.Pert[i], porGrid, Grid)
       pertCONC[,"NO3"]  <- Erode (pertCONC[,"NO3"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"NO2"]  <- Erode (pertCONC[,"NO2"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"NH3"]  <- Erode (pertCONC[,"NH3"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"DIC"]  <- Erode (pertCONC[,"DIC"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"ALK"]  <- Erode (pertCONC[,"ALK"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"PO4"]  <- Erode (pertCONC[,"PO4"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"CH4"]  <- Erode (pertCONC[,"CH4"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"H2S"]  <- Erode (pertCONC[,"H2S"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"SO4"]  <- Erode (pertCONC[,"SO4"]  , N.Pert[i], porGrid, Grid)
       pertCONC[,"Fe"]   <- Erode (pertCONC[,"Fe"]   , N.Pert[i], porGrid, Grid)
       pertCONC[,"Mn"]   <- Erode (pertCONC[,"Mn"]   , N.Pert[i], porGrid, Grid)
     } else { # deposit
       pertCONC[,"FDET"] <- DepositDET (pertCONC[,"FDET"],  N.Pert[i], porGrid, Grid, c1)
       pertCONC[,"SDET"] <- DepositDET (pertCONC[,"SDET"],  N.Pert[i], porGrid, Grid, c2)
       pertCONC[,"FeP"]  <- DepositDET (pertCONC[,"FeP"] ,  N.Pert[i], porGrid, Grid, 1)
       pertCONC[,"CaP"]  <- DepositDET (pertCONC[,"CaP"] ,  N.Pert[i], porGrid, Grid, 1)
       pertCONC[,"FeOH3"]<- DepositDET (pertCONC[,"FeOH3"], N.Pert[i], porGrid, Grid, c3)
       pertCONC[,"FeOH3B"]<-DepositDET (pertCONC[,"FeOH3B"], N.Pert[i], porGrid,Grid, c4)
       pertCONC[,"MnO2"]  <-DepositDET (pertCONC[,"MnO2"], N.Pert[i], porGrid,  Grid, c5)
       pertCONC[,"MnO2B"] <-DepositDET (pertCONC[,"MnO2B"], N.Pert[i], porGrid,  Grid, c6)
       pertCONC[,"Pads"]  <- DepositDET (pertCONC[,"Pads"],  N.Pert[i], porGrid, Grid, 1)
       pertCONC[,"MnCO3"] <- DepositDET (pertCONC[,"MnCO3"],  N.Pert[i], porGrid, Grid,0)
       pertCONC[,"O2"]   <- DepositBW (pertCONC[,"O2"]  ,   N.Pert[i], bwO2(t) , Grid)
       pertCONC[,"NO3"]  <- DepositBW (pertCONC[,"NO3"] ,   N.Pert[i], bwNO3(t), Grid)
       pertCONC[,"NO2"]  <- DepositBW (pertCONC[,"NO2"] ,   N.Pert[i], bwNO2(t), Grid)
       pertCONC[,"NH3"]  <- DepositBW (pertCONC[,"NH3"] ,   N.Pert[i], bwNH3(t), Grid)
       pertCONC[,"DIC"]  <- DepositBW (pertCONC[,"DIC"] ,   N.Pert[i], bwDIC(t), Grid)
       pertCONC[,"ALK"]  <- DepositBW (pertCONC[,"ALK"] ,   N.Pert[i], bwALK(t), Grid)
       pertCONC[,"PO4"]  <- DepositBW (pertCONC[,"PO4"] ,   N.Pert[i], bwPO4(t), Grid)
       pertCONC[,"CH4"]  <- DepositBW (pertCONC[,"CH4"] ,   N.Pert[i], bwCH4(t), Grid)
       pertCONC[,"H2S"]  <- DepositBW (pertCONC[,"H2S"] ,   N.Pert[i], bwH2S(t), Grid)
       pertCONC[,"SO4"]  <- DepositBW (pertCONC[,"SO4"] ,   N.Pert[i], bwSO4(t), Grid)
       pertCONC[,"Fe" ]  <- DepositBW (pertCONC[,"Fe" ] ,   N.Pert[i], bwFe(t) , Grid)
       pertCONC[,"Mn" ]  <- DepositBW (pertCONC[,"Mn" ] ,   N.Pert[i], bwMn(t) , Grid)
     }
    Fluxes <- Fluxes + 
       c(FDET = -(FDETConc - IntegrateSol(pertCONC[ ,"FDET"],.FESDIA$N, porGrid, Grid)),
         SDET = -(SDETConc - IntegrateSol(pertCONC[ ,"SDET"],.FESDIA$N, porGrid, Grid)),
         O2   = -(O2Conc   - IntegrateLiq(pertCONC[ ,"O2"] ,.FESDIA$N, porGrid, Grid)),
         NO3  = -(NO3Conc  - IntegrateLiq(pertCONC[ ,"NO3"],.FESDIA$N, porGrid, Grid)),
         NO2  = -(NO2Conc  - IntegrateLiq(pertCONC[ ,"NO2"],.FESDIA$N, porGrid, Grid)),
         NH3  = -(NH3Conc  - IntegrateLiq(pertCONC[ ,"NH3"],.FESDIA$N, porGrid, Grid)),
         PO4  = -(PO4Conc  - IntegrateLiq(pertCONC[ ,"PO4"],.FESDIA$N, porGrid, Grid)),
         FeP  = -(FePConc  - IntegrateSol(pertCONC[ ,"FeP"],.FESDIA$N, porGrid, Grid)),
         CaP  = -(CaPConc  - IntegrateSol(pertCONC[ ,"CaP"],.FESDIA$N, porGrid, Grid)),
         Pads = -(PadsConc - IntegrateSol(pertCONC[ ,"Pads"],.FESDIA$N, porGrid, Grid)),
         DIC  = -(DICConc  - IntegrateLiq(pertCONC[ ,"DIC"],.FESDIA$N, porGrid, Grid)),
         Fe   = -(FeConc   - IntegrateLiq(pertCONC[ ,"Fe"] ,.FESDIA$N, porGrid, Grid)),
         FeOH3=-(FeOH3Conc - IntegrateSol(pertCONC[,"FeOH3"],.FESDIA$N, porGrid, Grid)),
         H2S  = -(H2SConc  - IntegrateLiq(pertCONC[ ,"H2S"],.FESDIA$N, porGrid, Grid)),
         SO4  = -(SO4Conc  - IntegrateLiq(pertCONC[ ,"SO4"],.FESDIA$N, porGrid, Grid)),
         CH4  = -(CH4Conc  - IntegrateLiq(pertCONC[ ,"CH4"],.FESDIA$N, porGrid, Grid)),
         ALK  = -(ALKConc  - IntegrateLiq(pertCONC[ ,"ALK"],.FESDIA$N, porGrid, Grid)),
         FeOH3B=-(FeOH3BConc-IntegrateSol(pertCONC[ ,"FeOH3B"],.FESDIA$N, porGrid, Grid)),
         Mn   = -(MnConc-IntegrateLiq(pertCONC[ ,"Mn"],.FESDIA$N, porGrid, Grid)), 
         MnO2 = -(MnO2Conc-IntegrateSol(pertCONC[ ,"MnO2"],.FESDIA$N, porGrid, Grid)), 
         MnO2B=-(MnO2BConc-IntegrateSol(pertCONC[ ,"MnO2B"],.FESDIA$N, porGrid, Grid)), 
         MnCO3=-(MnCO3Conc-IntegrateSol(pertCONC[ ,"MnCO3"],.FESDIA$N, porGrid, Grid)))
    }
      PertFlux <<- rbind(PertFlux, Fluxes)
      
      if (model == 2){
        PertBW   <<- rbind(PertBW  , BW)
        BW <- BW - Fluxes[.FESDIA$ynames]/bwHeight(t)
        BW <- pmax(BW, 0)
        pertCONC <- rbind(BW, pertCONC)
        PertBW2   <<- rbind(PertBW2  , BW)
    
      }
    return(pertCONC)
  }

#===============================================================================
# Event Function
#===============================================================================

  EventFunc <- function(t, y, parms){
     print (paste("event at time", t))
    # tindex <<- tindex + 1
    assign("tindex", tindex + 1)
     pertCONC <- Perturb(y, t)
      cat(pertCONC[, "Mn"], "\n")
     return (as.vector(pertCONC))
     # browser()
  }

  initpar = unlist(STD$initpar)

  events <- list(func = EventFunc, time = perturbTimes)

  if (STD$isDistReact | model == 2) {
     band   <- 0
     lrw <- 500000
  } else  {
      band   <- 1
     lrw <- 300000
  }

  if (model == 1) {
    func <- "fesdiamod"
    N    <- .FESDIA$N
  } else {
    func <- "fesdiamodbw"
    N    <- .FESDIA$N+1  
  }  
  if(length(yini) != nspec*N)
    stop ("'yini' not of correct length, should be ", nspec*N)
  
  ZZ <- NULL  
  is.spinup <- ! is.null(spinup)
  if (is.spinup)
    is.spinup <- (length(spinup) > 1)
  if (is.spinup) {
    if (model == 1) 
      HWATERForc <- Setforcings (Hlist, "Hwater",     HwaterForc, spinup, fac = 1)   # not used
    else 
      HWATERForc <- Setforcings (STD$Parms, "Hwater", HwaterForc, spinup, fac = 1)

    forcings <- list()
    forcings[[1]]  <- Setforcings (STD$Parms, "Cflux", CfluxForc, spinup, fac = 1)
    forcings[[2]]  <- Setforcings (STD$Parms, "FeOH3flux", FeOH3fluxForc, spinup, fac = 1)
    forcings[[3]]  <- Setforcings (STD$Parms, "CaPflux",     CaPfluxForc, spinup, fac = 1)
    forcings[[4]]  <- Setforcings (STD$Parms, "w",         wForc, spinup, fac = 1)
    forcings[[5]]  <- Setforcings (STD$other, "biot",   biotForc, spinup, fac = 1/STD$other[["biot"]])
    forcings[[6]]  <- Setforcings (STD$other, "irr",     irrForc, spinup, fac = 1/STD$other[["irr"]])
    forcings[[7]]  <- Setforcings (STD$Parms, "rFast", rFastForc, spinup, fac = 1)
    forcings[[8]]  <- Setforcings (STD$Parms, "rSlow", rSlowForc, spinup, fac = 1)
    forcings[[9]]  <- Setforcings (STD$Parms, "pFast", pFastForc, spinup, fac = 1)
    forcings[[10]] <- Setforcings (STD$Parms, "gasflux",     gasfluxForc, spinup, fac = 1)
    forcings[[11]] <- Setforcings (STD$Parms, "MPBprod",     MPBprodForc, spinup, fac = 1)
    forcings[[12]] <- Setforcings (STD$Parms, "O2bw",   O2bwForc, spinup, fac = 1)
    forcings[[13]] <- Setforcings (STD$Parms, "NO3bw", NO3bwForc, spinup, fac = 1)
    forcings[[14]] <- Setforcings (STD$Parms, "NO2bw", NO2bwForc, spinup, fac = 1)
    forcings[[15]] <- Setforcings (STD$Parms, "NH3bw", NH3bwForc, spinup, fac = 1)
    forcings[[16]] <- Setforcings (STD$Parms, "CH4bw", CH4bwForc, spinup, fac = 1)
    forcings[[17]] <- Setforcings (STD$Parms, "Febw",  FebwForc,  spinup, fac = 1)
    forcings[[18]] <- Setforcings (STD$Parms, "H2Sbw", H2SbwForc, spinup, fac = 1)
    forcings[[19]] <- Setforcings (STD$Parms, "SO4bw", SO4bwForc, spinup, fac = 1)
    forcings[[20]] <- Setforcings (STD$Parms, "PO4bw", PO4bwForc, spinup, fac = 1)
    forcings[[21]] <- Setforcings (STD$Parms, "DICbw", DICbwForc, spinup, fac = 1)
    forcings[[22]] <- Setforcings (STD$Parms, "ALKbw", ALKbwForc, spinup, fac = 1)
    forcings[[23]] <- HWATERForc
    forcings[[24]] <- Setforcings (list(ratefactor = 1), "ratefactor", ratefactor, spinup, fac = 1)

    forcings[[25]] <- Setforcings (STD$Parms,      "Mnbw",      MnbwForc, spinup, fac = 1)
    forcings[[26]] <- Setforcings (STD$Parms,      "MnO2flux",      MnO2fluxForc, spinup, fac = 1)


    forcings[[27]] <- Setforcings (STD$Parms, "CaCO3flux", CaCO3fluxForc, spinup, fac = 1)
    forcings[[28]] <- Setforcings (STD$Parms,  "ARAGflux",  ARAGfluxForc, spinup, fac = 1)
    forcings[[29]] <- Setforcings (STD$Parms,      "Cabw",      CabwForc, spinup, fac = 1)
  
    
    if (model == 1){
     bwO2  <- approxfun(x = forcings[[12]], rule = 2)
     bwNO3 <- approxfun(x = forcings[[13]], rule = 2)
     bwNO2 <- approxfun(x = forcings[[14]], rule = 2)
     bwNH3 <- approxfun(x = forcings[[15]], rule = 2)
     bwCH4 <- approxfun(x = forcings[[16]], rule = 2)
     bwFe  <- approxfun(x = forcings[[17]], rule = 2)
     bwH2S <- approxfun(x = forcings[[18]], rule = 2)
     bwSO4 <- approxfun(x = forcings[[19]], rule = 2)
     bwPO4 <- approxfun(x = forcings[[20]], rule = 2)
     bwDIC <- approxfun(x = forcings[[21]], rule = 2)
     bwALK <- approxfun(x = forcings[[22]], rule = 2)
     bwMn  <- approxfun(x = forcings[[25]], rule = 2)
     bwCa  <- approxfun(x = forcings[[29]], rule = 2)

    } else {
      BWapprox <- approxfun(x = range(times), y = c(0,0), rule = 2)
      bwO2 <- bwNO3 <- bwNO2 <- bwNH3 <- bwCH4 <- bwFe <- bwH2S <- BWapprox
      bwSO4 <- bwPO4 <- bwDIC <- bwALK <- wCa <- bwMn <- BWapprox
    }
      
    if (model == 2) 
      bwHeight <- approxfun(x = forcings[[23]], rule = 2)
    
    ZZ <- c(ZZ, capture.output(suppressWarnings(   
      DYN <- ode.1D(y = yini, names = .FESDIA$ynames, initforc = "initfesforc",
                   forcings = forcings,  times = spinup, method = "lsodes",
                   func = func, initfunc = "initfesdia", lrw = lrw,
                   initpar = initpar, dllname = "FESDIA", bandwidth = band,
                   nout = .FESDIA$nout, outnames = .FESDIA$outnames,
                   events = events, nspec = nspec, ...)
    )))   
    yini <- DYN[nrow(DYN),2:(nspec*N+1)]
  }
  
  assign("tindex", 0)
  cat("\nFinish spinup!\n\n"); cat("tindex after spinup: ", tindex, "\n")

   if (model == 1) 
     HWATERForc <- Setforcings (Hlist, "Hwater",     HwaterForc, times, fac = 1)   # not used
   else 
     HWATERForc <- Setforcings (STD$Parms, "Hwater", HwaterForc, times, fac = 1)
    forcings <- list()
  
    forcings[[1]]  <- Setforcings (STD$Parms, "Cflux", CfluxForc, times, fac = 1)
    forcings[[2]]  <- Setforcings (STD$Parms, "FeOH3flux", FeOH3fluxForc, times, fac = 1)
    forcings[[3]]  <- Setforcings (STD$Parms, "CaPflux",     CaPfluxForc, times, fac = 1)
    forcings[[4]]  <- Setforcings (STD$Parms, "w",         wForc, times, fac = 1)
    forcings[[5]]  <- Setforcings (STD$other, "biot",   biotForc, times, fac = 1/STD$other[["biot"]])
    forcings[[6]]  <- Setforcings (STD$other, "irr",     irrForc, times, fac = 1/STD$other[["irr"]])
    forcings[[7]]  <- Setforcings (STD$Parms, "rFast", rFastForc, times, fac = 1)
    forcings[[8]]  <- Setforcings (STD$Parms, "rSlow", rSlowForc, times, fac = 1)
    forcings[[9]]  <- Setforcings (STD$Parms, "pFast", pFastForc, times, fac = 1)
    forcings[[10]] <- Setforcings (STD$Parms, "gasflux", gasfluxForc, times, fac = 1)
    forcings[[11]] <- Setforcings (STD$Parms, "MPBprod", MPBprodForc, times, fac = 1)
    forcings[[12]] <- Setforcings (STD$Parms, "O2bw",   O2bwForc, times, fac = 1)
    forcings[[13]] <- Setforcings (STD$Parms, "NO3bw", NO3bwForc, times, fac = 1)
    forcings[[14]] <- Setforcings (STD$Parms, "NO2bw", NO2bwForc, times, fac = 1)
    forcings[[15]] <- Setforcings (STD$Parms, "NH3bw", NH3bwForc, times, fac = 1)
    forcings[[16]] <- Setforcings (STD$Parms, "CH4bw", CH4bwForc, times, fac = 1)
    forcings[[17]] <- Setforcings (STD$Parms, "Febw",  FebwForc,  times, fac = 1)
    forcings[[18]] <- Setforcings (STD$Parms, "H2Sbw", H2SbwForc, times, fac = 1)
    forcings[[19]] <- Setforcings (STD$Parms, "SO4bw", SO4bwForc, times, fac = 1)
    forcings[[20]] <- Setforcings (STD$Parms, "PO4bw", PO4bwForc, times, fac = 1)
    forcings[[21]] <- Setforcings (STD$Parms, "DICbw", DICbwForc, times, fac = 1)
    forcings[[22]] <- Setforcings (STD$Parms, "ALKbw", ALKbwForc, times, fac = 1)
    forcings[[23]] <- HWATERForc
    forcings[[24]] <- Setforcings (list(ratefactor = 1), "ratefactor", ratefactor, times, fac = 1)

    forcings[[25]] <- Setforcings (STD$Parms,      "Mnbw",      MnbwForc, times, fac = 1)
    forcings[[26]] <- Setforcings (STD$Parms,      "MnO2flux",      MnO2fluxForc, times, fac = 1)


    forcings[[27]] <- Setforcings (STD$Parms, "CaCO3flux", CaCO3fluxForc, times, fac = 1)
    forcings[[28]] <- Setforcings (STD$Parms,  "ARAGflux",  ARAGfluxForc, times, fac = 1)
    forcings[[29]] <- Setforcings (STD$Parms,      "Cabw",      CabwForc, times, fac = 1)

    bwO2  <- approxfun(x = forcings[[12]], rule = 2)
    bwNO3 <- approxfun(x = forcings[[13]], rule = 2)
    bwNO2 <- approxfun(x = forcings[[14]], rule = 2)
    bwNH3 <- approxfun(x = forcings[[15]], rule = 2)
    bwCH4 <- approxfun(x = forcings[[16]], rule = 2)
    bwFe  <- approxfun(x = forcings[[17]], rule = 2)
    bwH2S <- approxfun(x = forcings[[18]], rule = 2)
    bwSO4 <- approxfun(x = forcings[[19]], rule = 2)
    bwPO4 <- approxfun(x = forcings[[20]], rule = 2)
    bwDIC <- approxfun(x = forcings[[21]], rule = 2)
    bwALK <- approxfun(x = forcings[[22]], rule = 2)
    bwMn  <- approxfun(x = forcings[[25]], rule = 2)
    bwCa  <- approxfun(x = forcings[[29]], rule = 2)

  
    if (model == 2) 
      bwHeight <- approxfun(x = forcings[[23]], rule = 2)

    PertFlux <- PertBW <- PertBW2 <- NULL 
    ZZ <- c(ZZ, capture.output(suppressWarnings(   
      DYN <- ode.1D(y = yini, names = .FESDIA$ynames, initforc = "initfesforc",
                   forcings = forcings,  times = times, method = "lsodes",
                   func = func, initfunc = "initfesdia", lrw = lrw,
                   initpar = initpar, dllname = "FESDIA", bandwidth = band,
                   nout = .FESDIA$nout, outnames = .FESDIA$outnames,
                   events = events, nspec = nspec, ...)
  )))
  
  colnames(DYN)[2:(nspec*N+1)] <- as.vector(sapply(.FESDIA$ynames, FUN = function(x) rep(x, times = N)))
  
  if (model == 2) {
    cn <- colnames(DYN)
    cn[seq(2, by = N, length.out = nspec)] <- paste(.FESDIA$ynames, "bw", sep ="")
    colnames(DYN) <- cn
  }
  if (verbose) print (ZZ)
  attr(DYN, "Depth") <- STD$Depth
  attr(DYN, "dx") <- STD$dx
  attr(DYN, "porosity")   <- STD$porosity
  attr(DYN, "bioturbation") <- STD$bioturbation
  attr(DYN, "irrigation")   <- STD$irrigation
  attr(DYN, "DistReact")   <- STD$DistReact
#  attr(DYN, "forcings") <- forcings
  
  attr(DYN, "Parms") <- STD$Parms
  attr(DYN, "perturbFluxes")  <- data.frame(time = perturbTimes[1:nrow(PertFlux)], PertFlux)
  if (model == 2) {
    attr(DYN, "BWbeforePert") <- data.frame(time = PertBW[1:nrow(PertBW)], PertBW)
    attr(DYN, "BWafterPert")  <- data.frame(time = PertBW2[1:nrow(PertBW2)], PertBW2)
  }
  attr(DYN, "perturbSettings") <- list(perturbType = perturbType, 
               perturbTimes =  perturbTimes, perturbDepth = perturbDepth, concfac = concfac)
  attr(DYN, "warnings")     <- ZZ
  attr(DYN, "model")        <- paste("FESDIA_model_",model,sep="")
  class(DYN) <- c("FESDIAdyn", class(DYN))
  
  return(DYN)
 
}


FESDIAperturbFluxes <- function(out, which = NULL) {
  
  if (missing(out)) 
    stop("object 'out' should be given")
  
  if (! "FESDIAdyn" %in% (class(out))) 
     stop("perturbation fluxes can only be obtained from a run performed with 'FESDIAdyn' or 'FESDIAperturb'" )
    
  W <- attributes(out)$perturbFluxes
    
  if (! is.null(W)) { 
    if (! is.null(which))
      W <- cbind(W$time, W[,which])
  }
  return(W)
}  

FESDIAperturbSettings <- function(out) {
  
  if (missing(out)) 
    stop("object 'out' should be given")
  
  if (! "FESDIAdyn" %in% (class(out))) 
     stop("perturbation settings can only be obtained from a run performed with 'FESDIAdyn' or 'FESDIAperturb'" )
    
  W <- attributes(out)$perturbSettings
  return(W)
}  
