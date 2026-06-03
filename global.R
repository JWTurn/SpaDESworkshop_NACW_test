# global setupProject to forecast RSF

# general set up
if (!require("pak")) install.packages("pak")
pak::pak(c("Require")) # on CRAN; these should be unchanging for a while
options(repos = unique(c("https://predictiveecology.r-universe.dev", getOption("repos"))))
Require::Install(c("SpaDES.core", "reproducible (>3.1.1)",
                   "PredictiveEcology/SpaDES.project@development (>=1.0.1.9308)"))

# set up project path where you want it saved on your computer
projPath = "~/git/SpaDESworkshop_NACW_test"

#lapply(dir('R', '*.R', full.names = TRUE), source)


out <- SpaDES.project::setupProject(
  Restart = TRUE,
  useGit = 'JWTurn',
  updateRprofile = TRUE,
  #overwrite = TRUE,
  paths = list(projectPath =  projPath
  ),
  options = options(spades.allowInitDuringSimInit = TRUE,
                    spades.allowSequentialCaching = TRUE,
                    spades.moduleCodeChecks = FALSE,
                    spades.useRequire = TRUE,
                    spades.recoveryMode = 1,
                    reproducible.useMemoise = TRUE
                    ,reproducible.cloudFolderID = 'https://drive.google.com/drive/folders/199oEp-TVaCyacwqS4PPf3XWMbhPe4YBN?usp=share_link'
  ),
  modules = c(
    # forest simulation
    "PredictiveEcology/Biomass_borealDataPrep@development",
    "PredictiveEcology/Biomass_core@development",
    "PredictiveEcology/Biomass_regeneration@master",
    # fire simulation
    file.path("PredictiveEcology/scfm@development/modules",
              c("scfmDataPrep",
                "scfmIgnition", "scfmEscape", "scfmSpread",
                "scfmDiagnostics")),
    # RSF forecasting
    'JWTurn/RSFpredict@main'

  ),
  params = list(
    .globals = list(
      .plots = c("png"),
      .studyAreaName =  "dehchoN",
      .useCache = c(".inputObjects", 'init'),
      dataYear = 2020, #TODO Eliot, is 2025 an option now? #start year for predicted forest growth
      sppEquivCol = "LandR"
    ),

    scfmDataPrep = list(
      targetN = 2000, # keeping low for workshop example, better would be 4000
      .useParallelFireRegimePolys = F,
      .useCloud = T
    ),

    RSFpredict = list(
      simulationProcess = 'dynamic'
    )

  ),

  packages = c('RCurl', 'XML', 'snow', 'googledrive', 'httr2', "terra", "gert", "remotes", 'glmmTMB',
               "PredictiveEcology/reproducible@development", "PredictiveEcology/LandR@development",
               "PredictiveEcology/SpaDES.core@development"),

# expected for scfm
  cloudFolderID = 'https://drive.google.com/drive/folders/199oEp-TVaCyacwqS4PPf3XWMbhPe4YBN?usp=share_link',

 # years of sim
  times = list(start = 2020, end = 2075),

  model = reproducible::prepInputs(url = 'https://drive.google.com/file/d/1ma5qRk2NNidLhrQoiLIzd7W5ogeTaH5-/view?usp=share_link',
                                   fun = 'readRDS',
                                   destinationPath = 'inputs'),

  studyArea = reproducible::prepInputs(url = 'https://drive.google.com/file/d/1ma5qRk2NNidLhrQoiLIzd7W5ogeTaH5-/view?usp=share_link',
                                       fun =  'terra::vect',
                                       destinationPath = 'inputs'),

  # need to buffer the study area to avoid edge effects
  studyAreaLarge = terra::buffer(studyArea, 10000),
  studyAreaCalibration = studyAreaLarge,

  # premade landcover layers that the RSF data were extracted from
  modelLand = reproducible::prepInputs(url = 'https://drive.google.com/file/d/1LeYrZBKrEPq6jSIP1SWM-grfINTeQjvn/view?usp=share_link',
                                       fun =  'terra::rast',
                                       destinationPath = 'inputs'),


  # raster needed as template for borealBiomass and scfm
  # making it a finer resolution than final needed for RSF so can calculate proportion
  rasterToMatchLarge = {
    rtml <- terra::disagg(modelLand[[1]], fact = 2)
    rtml[] <- 1
    terra::mask(rtml, studyAreaLarge)
  },
  rasterToMatchCalibration = rasterToMatchLarge,

  rasterToMatch = {
    reproducible::postProcess(rasterToMatchLarge, cropTo = studyArea, maskTo = studyArea)
  },

  # species equivalencies for borealBiomass
  sppEquiv = {
    speciesInStudy <- LandR::speciesInStudyArea(studyAreaLarge, dPath = paths$inputPath)
    species <- LandR::equivalentName(speciesInStudy$speciesList, df = LandR::sppEquivalencies_CA, "LandR")
    sppEquiv <- LandR::sppEquivalencies_CA[LandR %in% species]
    sppEquiv <- sppEquiv[KNN != "" & LANDIS_traits != ""]
    sppEquiv
  }



  # OUTPUTS TO SAVE -----------------------
  # outputs = {
  #   # save to disk 2 objects, every year
  #
  #
  # }

)


results <- SpaDES.core::simInitAndSpades2(out)
results <- SpaDES.core::restartSpades()
