# Install correct versions of HADES packages
# options(install.packages.compile.from.source = "never")
# remotes::install_github("ohdsi/CohortGenerator", ref = "v0.8.0")
# remotes::install_github("ohdsi/CohortDiagnostics", ref = "v3.1.2")
# remotes::install_github("ohdsi/Characterization", ref = "v0.1.1")
# remotes::install_github("ohdsi/CohortIncidence", ref = "v3.1.2")
# remotes::install_github("ohdsi/CohortMethod", ref = "74f017107e0cc1b740a2badc82879ab6ad291b23")
# remotes::install_github("ohdsi/SelfControlledCaseSeries", ref = "15918616814b88137f82bf2aa9986e1dcdf39e74")
# remotes::install_github("ohdsi/PatientLevelPrediction", ref = "v6.3.1")
# remotes::install_github("ohdsi/ROhdsiWebApi")
#
# Interrogate the installed packages to confirm versions above
# installedPackages <- as.data.frame(installed.packages())[,c("Package", "Version")]
# installedPackages[installedPackages$Package %in% c("CohortGenerator", "CohortDiagnostics", "Characterization", "CohortIncidence", "CohortMethod", "SelfControlledCaseSeries", "PatientLevelPrediction", "ROhdsiWebApi"), ]

library(dplyr)
rootFolder <- "C:/SOS/VEGF ESRD"

tcis <- list(
  list(
    targetId = 1782483, # Aflibercept
    comparatorId = 1782481, # Ranibizumab
    indicationId = 1782480, # blinding diseases
    genderConceptIds = c(8507, 8532), # use valid genders (remove unknown)
    minAge = 18, # All ages In years. Can be NULL
    maxAge = NULL, # All ages In years. Can be NULL
    excludedCovariateConceptIds = c(
      40244266, # aflibercept
      19080982 # ranibuzumab
    ) 
  ),
  list(
    targetId = 1782483, # Aflibercept
    comparatorId = 1782482, # bevacizumab
    indicationId = 1782480, # blinding diseases
    genderConceptIds = c(8507, 8532), # use valid genders (remove unknown)
    minAge = 18, # All ages In years. Can be NULL
    maxAge = NULL, # All ages In years. Can be NULL
    excludedCovariateConceptIds = c(
      40244266, # aflibercept
      1397141, # bevacizumab
      4319466, # Complete blood count with white cell differential, automated
      2314231, #Chemotherapy administration, intravenous infusion technique; each additional hour (List separately in addition to code for primary procedure)
      2314229, #Chemotherapy administration, intravenous infusion technique; up to 1 hour, single or initial substance/drug
      2314233, #Chemotherapy administration, intravenous infusion technique; each additional sequential infusion (different substance/drug), up to 1 hour (List separately in addition to code for primary procedure)
      4203722, #Patient encounter procedure
      2111025, #Intravitreal injection of a pharmacologic agent (separate procedure)
      38003354, #Drugs Identification - Drugs Requiring Detailed Coding
      4273629, #Chemotherapy
      4030886, #Intravenous infusion
      4201612, #Ophthalmoscopy
      2000665, #Other operations on vitreous
      4064074 #Tonometry
    ) 
  ),
  list(
    targetId = 1782481, # Ranibizumab
    comparatorId = 1782482, # bevacizumab
    indicationId = 1782480, # blinding diseases
    genderConceptIds = c(8507, 8532), # use valid genders (remove unknown)
    minAge = 18, # All ages In years. Can be NULL
    maxAge = NULL, # All ages In years. Can be NULL
    excludedCovariateConceptIds = c(
      19080982, # ranibuzumab
      1397141, # bevacizumab
      4319466, # Complete blood count with white cell differential, automated
      2314231, #Chemotherapy administration, intravenous infusion technique; each additional hour (List separately in addition to code for primary procedure)
      2314229, #Chemotherapy administration, intravenous infusion technique; up to 1 hour, single or initial substance/drug
      2314233, #Chemotherapy administration, intravenous infusion technique; each additional sequential infusion (different substance/drug), up to 1 hour (List separately in addition to code for primary procedure)
      4203722, #Patient encounter procedure
      2111025, #Intravitreal injection of a pharmacologic agent (separate procedure)
      38003354, #Drugs Identification - Drugs Requiring Detailed Coding
      4273629, #Chemotherapy
      4030886, #Intravenous infusion
      4201612, #Ophthalmoscopy
      2000665, #Other operations on vitreous
      4064074 #Tonometry
    ) 
  ) 
)
outcomes <- tibble(
  cohortId = c(1782164), # ESRD
  cleanWindow = c(9999)
)
negativeConceptSetId <- 1873445  #candidate controls for aflibercept, ranibuzumab,bevacizumab 
timeAtRisks <- tibble(
  label = c("On treatment"),
  riskWindowStart  = c(1),
  startAnchor = c("cohort start"),
  riskWindowEnd  = c(0),
  endAnchor = c("cohort end"),
)
# Try to avoid intent-to-treat TARs for SCCS, or then at least disable calendar time spline:
sccsTimeAtRisks <- tibble(
  label = c("On treatment"),
  riskWindowStart  = c(1),
  startAnchor = c("cohort start"),
  riskWindowEnd  = c(0),
  endAnchor = c("cohort end"),
)
# Try to use fixed-time TARs for patient-level prediction:
plpTimeAtRisks <- tibble(
  riskWindowStart  = c(1),
  startAnchor = c("cohort start"),
  riskWindowEnd  = c(365),
  endAnchor = c("cohort start"),
)
studyStartDate <- "" # YYYYMMDD, e.g. "2001-02-01" for January 1st, 2001
studyEndDate <- "" # YYYYMMDD

# Probably don't change below this line ----------------------------------------

useCleanWindowForPriorOutcomeLookback <- FALSE # If FALSE, lookback window is all time prior, i.e., including only first events
psMatchMaxRatio <- 1 # If bigger than 1, the outcome model will be conditioned on the matched set

# Don't change below this line (unless you know what you're doing) -------------


# Shared Resources -------------------------------------------------------------
source("https://raw.githubusercontent.com/OHDSI/CohortGeneratorModule/v0.1.0/SettingsFunctions.R")

baseUrl <- 'http://api.ohdsi.org:80/WebAPI'  # Sys.getenv("baseUrl")


#ROhdsiWebApi::authorizeWebApi(
#  baseUrl = baseUrl,
#  authMethod = "windows")
cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(
  cohortIds =  unique(
    c(
      outcomes$cohortId,
      unlist(sapply(tcis, function(x) c(x$targetId, x$comparatorId, x$indicationId)))
    )
  ),
  generateStats = TRUE,
  baseUrl = baseUrl
)
negativeControlOutcomeCohortSet <- ROhdsiWebApi::getConceptSetDefinition(
  conceptSetId = negativeConceptSetId,
  baseUrl = baseUrl
) %>%
  ROhdsiWebApi::resolveConceptSet(
    baseUrl = baseUrl
  ) %>%
  ROhdsiWebApi::getConcepts(
    baseUrl = baseUrl
  ) %>%
  rename(outcomeConceptId = "conceptId",
         cohortName = "conceptName") %>%
  mutate(cohortId = row_number() + 1000)


# TODO: we need to get the unique indication + target/comparator 
# and then 
dfUniqueTcis <- data.frame()
for (i in seq_along(tcis)) {
  dfUniqueTcis <- rbind(dfUniqueTcis, data.frame(cohortId = tcis[[i]]$targetId,
                                                 indicationId = paste(tcis[[i]]$indicationId, collapse = ","),
                                                 genderConceptIds = paste(tcis[[i]]$genderConceptIds, collapse = ","),
                                                 minAge = paste(tcis[[i]]$minAge, collapse = ","),
                                                 maxAge = paste(tcis[[i]]$maxAge, collapse = ",")
  ))
  dfUniqueTcis <- rbind(dfUniqueTcis, data.frame(cohortId = tcis[[i]]$comparatorId,
                                                 indicationId = paste(tcis[[i]]$indicationId, collapse = ","),
                                                 genderConceptIds = paste(tcis[[i]]$genderConceptIds, collapse = ","),
                                                 minAge = paste(tcis[[i]]$minAge, collapse = ","),
                                                 maxAge = paste(tcis[[i]]$maxAge, collapse = ",")
  ))
}
dfUniqueTcis <- unique(dfUniqueTcis)
for (i in 1:nrow(dfUniqueTcis)) {
  tci <- dfUniqueTcis[i,]
  subsetOperators <- list()
  if (tci$indicationId != "") {
    subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createCohortSubset(
      cohortIds = tci$indicationId,
      negate = FALSE,
      cohortCombinationOperator = "all",
      startWindow = CohortGenerator::createSubsetCohortWindow(-99999, 0, "cohortStart"),
      endWindow = CohortGenerator::createSubsetCohortWindow(-99999, 99999, "cohortStart")
    )
  }
  subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createLimitSubset(
    priorTime = 365,
    followUpTime = 1,
    limitTo = "firstEver"
  )
  if (tci$genderConceptIds != "" ||
      tci$minAge != "" ||
      tci$maxAge != "") {
    subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createDemographicSubset(
      ageMin = if(tci$minAge == "") 0 else as.integer(tci$minAge),
      ageMax = if(tci$maxAge == "") 99999 else as.integer(tci$maxAge),
      gender = if(tci$genderConceptIds == "") NULL else as.integer(strsplit(tci$genderConceptIds, ",")[[1]])
    )
  }
  if (studyStartDate != "" || studyEndDate != "") {
    subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createLimitSubset(
      calendarStartDate = if (studyStartDate == "") NULL else as.Date(studyStartDate, "%Y%m%d"),
      calendarEndDate = if (studyEndDate == "") NULL else as.Date(studyEndDate, "%Y%m%d")
    )
  }
  subsetDef <- CohortGenerator::createCohortSubsetDefinition(
    name = "",
    definitionId = i,
    subsetOperators = subsetOperators
  )
  cohortDefinitionSet <- cohortDefinitionSet %>%
    CohortGenerator::addCohortSubsetDefinition(
      cohortSubsetDefintion = subsetDef,
      targetCohortIds = tci$cohortId
    ) 
}

dfUniqueIndications <- unique(dfUniqueTcis[,-1])
for (i in 1:nrow(dfUniqueIndications)) {
  indicationCohort <- dfUniqueIndications[i,]
  subsetOperators <- list()
  subsetId <- nrow(dfUniqueTcis) + i
  subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createLimitSubset(
    priorTime = 365,
    followUpTime = 1,
    limitTo = "firstEver"
  )
  if (indicationCohort$genderConceptIds != "" ||
      indicationCohort$minAge != "" ||
      indicationCohort$maxAge != "") {
    subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createDemographicSubset(
      ageMin = if(indicationCohort$minAge == "") 0 else as.integer(indicationCohort$minAge),
      ageMax = if(indicationCohort$maxAge == "") 99999 else as.integer(indicationCohort$maxAge),
      gender = if(indicationCohort$genderConceptIds == "") NULL else as.integer(strsplit(indicationCohort$genderConceptIds, ",")[[1]])
    )
  }
  if (studyStartDate != "" || studyEndDate != "") {
    subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createLimitSubset(
      calendarStartDate = if (studyStartDate == "") NULL else as.Date(studyStartDate, "%Y%m%d"),
      calendarEndDate = if (studyEndDate == "") NULL else as.Date(studyEndDate, "%Y%m%d")
    )
  }
  subsetDef <- CohortGenerator::createCohortSubsetDefinition(
    name = "",
    definitionId = subsetId,
    subsetOperators = subsetOperators
  )
  cohortDefinitionSet <- cohortDefinitionSet %>%
    CohortGenerator::addCohortSubsetDefinition(
      cohortSubsetDefintion = subsetDef,
      targetCohortIds = as.integer(indicationCohort$indicationId)
    ) 
}

if (any(duplicated(cohortDefinitionSet$cohortId, negativeControlOutcomeCohortSet$cohortId))) {
  stop("*** Error: duplicate cohort IDs found ***")
  rstudioapi::showDialog("Error", "Duplicate cohort IDs found") 
}
cohortDefinitionShared <- createCohortSharedResourceSpecifications(cohortDefinitionSet)
negativeControlsShared <- createNegativeControlOutcomeCohortSharedResourceSpecifications(
  negativeControlOutcomeCohortSet = negativeControlOutcomeCohortSet,
  occurrenceType = "first",
  detectOnDescendants = TRUE
)


# CohortGeneratorModule --------------------------------------------------------
source("https://raw.githubusercontent.com/OHDSI/CohortGeneratorModule/v0.1.0/SettingsFunctions.R")
cohortGeneratorModuleSpecifications <- createCohortGeneratorModuleSpecifications(
  incremental = TRUE,
  generateStats = TRUE
)


# CohortDiagnosticsModule ------------------------------------------------------
source("https://raw.githubusercontent.com/OHDSI/CohortDiagnosticsModule/v0.0.7/SettingsFunctions.R")
library(CohortDiagnostics)
cohortDiagnosticsModuleSpecifications <- createCohortDiagnosticsModuleSpecifications(
  runInclusionStatistics = TRUE,
  runIncludedSourceConcepts = TRUE,
  runOrphanConcepts = TRUE,
  runTimeSeries = FALSE,
  runVisitContext = TRUE,
  runBreakdownIndexEvents = TRUE,
  runIncidenceRate = TRUE,
  runCohortRelationship = TRUE,
  runTemporalCohortCharacterization = TRUE,
  minCharacterizationMean = 0.0001,
  temporalCovariateSettings = getDefaultCovariateSettings(),
  incremental = FALSE,
  cohortIds = cohortDefinitionSet$cohortId)


# CharacterizationModule Settings ---------------------------------------------
source("https://raw.githubusercontent.com/OHDSI/CharacterizationModule/v0.3.1/SettingsFunctions.R")
allCohortIdsExceptOutcomes <- cohortDefinitionSet %>%
  filter(!cohortId %in% outcomes$cohortId) %>%
  pull(cohortId)
characterizationModuleSpecifications <- createCharacterizationModuleSpecifications(
  targetIds = allCohortIdsExceptOutcomes,
  outcomeIds = outcomes$cohortId,
  dechallengeStopInterval = 30,
  dechallengeEvaluationWindow = 30,
  timeAtRisk = timeAtRisks,
  covariateSettings = FeatureExtraction::createDefaultCovariateSettings()
)


# CohortIncidenceModule --------------------------------------------------------
source("https://raw.githubusercontent.com/OHDSI/CohortIncidenceModule/v0.0.6/SettingsFunctions.R")
exposureIndicationIds <- cohortDefinitionSet %>%
  filter(!cohortId %in% outcomes$cohortId & isSubset) %>%
  pull(cohortId)
targetList <- lapply(
  exposureIndicationIds,
  function(cohortId) {
    CohortIncidence::createCohortRef(
      id = cohortId, 
      name = cohortDefinitionSet$cohortName[cohortDefinitionSet$cohortId == cohortId]
    )
  }
)
outcomeList <- lapply(
  seq_len(nrow(outcomes)),
  function(i) {
    CohortIncidence::createOutcomeDef(
      id = i, 
      name = cohortDefinitionSet$cohortName[cohortDefinitionSet$cohortId == outcomes$cohortId[i]], 
      cohortId = outcomes$cohortId[i], 
      cleanWindow = outcomes$cleanWindow[i]
    )
  }
)
tars <- list()
for (i in seq_len(nrow(timeAtRisks))) {
  tars[[i]] <- CohortIncidence::createTimeAtRiskDef(
    id = i, 
    startWith = gsub("cohort ", "", timeAtRisks$startAnchor[i]), 
    endWith = gsub("cohort ", "", timeAtRisks$endAnchor[i]), 
    startOffset = timeAtRisks$riskWindowStart[i],
    endOffset = timeAtRisks$riskWindowEnd[i]
  )
}
analysis1 <- CohortIncidence::createIncidenceAnalysis(
  targets = exposureIndicationIds,
  outcomes = seq_len(nrow(outcomes)),
  tars = seq_along(tars)
)
irDesign <- CohortIncidence::createIncidenceDesign(
  targetDefs = targetList,
  outcomeDefs = outcomeList,
  tars = tars,
  analysisList = list(analysis1),
  strataSettings = CohortIncidence::createStrataSettings(
    byYear = TRUE,
    byGender = TRUE,
    byAge = TRUE,
    ageBreaks = seq(0, 110, by = 10)
  )
)
cohortIncidenceModuleSpecifications <- createCohortIncidenceModuleSpecifications(
  irDesign = irDesign$toList()
)


# CohortMethodModule -----------------------------------------------------------
source("https://raw.githubusercontent.com/OHDSI/CohortMethodModule/v0.1.0/SettingsFunctions.R")
covariateSettings <- FeatureExtraction::createDefaultCovariateSettings(
  addDescendantsToExclude = TRUE # Keep TRUE because you're excluding concepts
)
outcomeList <- append(
  lapply(seq_len(nrow(outcomes)), function(i) {
    if (useCleanWindowForPriorOutcomeLookback)
      priorOutcomeLookback <- outcomes$cleanWindow[i]
    else
      priorOutcomeLookback <- 99999
    CohortMethod::createOutcome(
      outcomeId = outcomes$cohortId[i],
      outcomeOfInterest = TRUE,
      trueEffectSize = NA,
      priorOutcomeLookback = priorOutcomeLookback
    )
  }),
  lapply(negativeControlOutcomeCohortSet$cohortId, function(i) {
    CohortMethod::createOutcome(
      outcomeId = i,
      outcomeOfInterest = FALSE,
      trueEffectSize = 1
    )
  })
)
targetComparatorOutcomesList <- list()
for (i in seq_along(tcis)) {
  tci <- tcis[[i]]
  targetId <- cohortDefinitionSet %>% 
    filter(subsetParent == tci$targetId & subsetDefinitionId == i) %>%
    pull(cohortId)
  comparatorId <- cohortDefinitionSet %>% 
    filter(subsetParent == tci$comparatorId & subsetDefinitionId == i) %>%
    pull(cohortId)
  targetComparatorOutcomesList[[i]] <- CohortMethod::createTargetComparatorOutcomes(
    targetId = targetId,
    comparatorId = comparatorId,
    outcomes = outcomeList,
    excludedCovariateConceptIds = tci$excludedCovariateConceptIds
  )
}
getDbCohortMethodDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(
  restrictToCommonPeriod = TRUE,
  studyStartDate = studyStartDate,
  studyEndDate = studyEndDate,
  maxCohortSize = 0,
  covariateSettings = covariateSettings
)
createPsArgs = CohortMethod::createCreatePsArgs(
  maxCohortSizeForFitting = 250000,
  errorOnHighCorrelation = TRUE,
  stopOnError = FALSE, # Setting to FALSE to allow Strategus complete all CM operations; when we cannot fit a model, the equipoise diagnostic should fail
  estimator = "att",
  prior = createPrior(
    priorType = "laplace", 
    exclude = c(0), 
    useCrossValidation = TRUE
  ),
  control = createControl(
    noiseLevel = "silent", 
    cvType = "auto", 
    seed = 1, 
    resetCoefficients = TRUE, 
    tolerance = 2e-07, 
    cvRepetitions = 10, 
    startingVariance = 0.01
  )
)
matchOnPsArgs = CohortMethod::createMatchOnPsArgs(
  maxRatio = psMatchMaxRatio,
  caliper = 0.2,
  caliperScale = "standardized logit",
  allowReverseMatch = FALSE,
  stratificationColumns = c()
)
# stratifyByPsArgs <- CohortMethod::createStratifyByPsArgs(
#   numberOfStrata = 5,
#   stratificationColumns = c(),
#   baseSelection = "all"
# )
computeSharedCovariateBalanceArgs = CohortMethod::createComputeCovariateBalanceArgs(
  maxCohortSize = 250000,
  covariateFilter = NULL
)
computeCovariateBalanceArgs = CohortMethod::createComputeCovariateBalanceArgs(
  maxCohortSize = 250000,
  covariateFilter = FeatureExtraction::getDefaultTable1Specifications()
)
fitOutcomeModelArgs = CohortMethod::createFitOutcomeModelArgs(
  modelType = "cox",
  stratified = psMatchMaxRatio != 1,
  useCovariates = FALSE,
  inversePtWeighting = FALSE,
  prior = createPrior(
    priorType = "laplace", 
    useCrossValidation = TRUE
  ),
  control = createControl(
    cvType = "auto", 
    seed = 1, 
    resetCoefficients = TRUE,
    startingVariance = 0.01, 
    tolerance = 2e-07, 
    cvRepetitions = 10, 
    noiseLevel = "quiet"
  )
)
cmAnalysisList <- list()
for (i in seq_len(nrow(timeAtRisks))) {
  createStudyPopArgs <- CohortMethod::createCreateStudyPopulationArgs(
    firstExposureOnly = FALSE,
    washoutPeriod = 0,
    removeDuplicateSubjects = "keep first",
    censorAtNewRiskWindow = TRUE,
    removeSubjectsWithPriorOutcome = TRUE,
    priorOutcomeLookback = 99999,
    riskWindowStart = timeAtRisks$riskWindowStart[[i]],
    startAnchor = timeAtRisks$startAnchor[[i]],
    riskWindowEnd = timeAtRisks$riskWindowEnd[[i]],
    endAnchor = timeAtRisks$endAnchor[[i]],
    minDaysAtRisk = 1,
    maxDaysAtRisk = 99999
  )
  cmAnalysisList[[i]] <- CohortMethod::createCmAnalysis(
    analysisId = i,
    description = sprintf(
      "Cohort method, %s",
      timeAtRisks$label[i]
    ),
    getDbCohortMethodDataArgs = getDbCohortMethodDataArgs,
    createStudyPopArgs = createStudyPopArgs,
    createPsArgs = createPsArgs,
    matchOnPsArgs = matchOnPsArgs,
    # stratifyByPsArgs = stratifyByPsArgs,
    computeSharedCovariateBalanceArgs = computeSharedCovariateBalanceArgs,
    computeCovariateBalanceArgs = computeCovariateBalanceArgs,
    fitOutcomeModelArgs = fitOutcomeModelArgs
  )
}
cohortMethodModuleSpecifications <- createCohortMethodModuleSpecifications(
  cmAnalysisList = cmAnalysisList,
  targetComparatorOutcomesList = targetComparatorOutcomesList,
  analysesToExclude = NULL,
  refitPsForEveryOutcome = FALSE,
  refitPsForEveryStudyPopulation = FALSE,  
  cmDiagnosticThresholds = createCmDiagnosticThresholds(
    mdrrThreshold = Inf,
    easeThreshold = 0.25,
    sdmThreshold = 0.1,
    equipoiseThreshold = 0.2,
    attritionFractionThreshold = 1
  )
)


# SelfControlledCaseSeriesmodule -----------------------------------------------
source("https://raw.githubusercontent.com/OHDSI/SelfControlledCaseSeriesModule/v0.1.3/SettingsFunctions.R")

uniqueTargetIndications <- lapply(tcis,
                                  function(x) data.frame(
                                    exposureId = c(x$targetId, x$comparatorId),
                                    indicationId = if (is.null(x$indicationId)) NA else x$indicationId,
                                    genderConceptIds = paste(x$genderConceptIds, collapse = ","),
                                    minAge = if (is.null(x$minAge)) NA else x$minAge,
                                    maxAge = if (is.null(x$maxAge)) NA else x$maxAge
                                  )) %>%
  bind_rows() %>%
  distinct()

uniqueTargetIds <- uniqueTargetIndications %>%
  distinct(exposureId) %>%
  pull()

eoList <- list()
for (targetId in uniqueTargetIds) {
  for (outcomeId in outcomes$cohortId) {
    eoList[[length(eoList) + 1]] <- SelfControlledCaseSeries::createExposuresOutcome(
      outcomeId = outcomeId,
      exposures = list(
        SelfControlledCaseSeries::createExposure(
          exposureId = targetId,
          trueEffectSize = NA
        )
      )
    )
  }
  for (outcomeId in negativeControlOutcomeCohortSet$cohortId) {
    eoList[[length(eoList) + 1]] <- SelfControlledCaseSeries::createExposuresOutcome(
      outcomeId = outcomeId,
      exposures = list(SelfControlledCaseSeries::createExposure(
        exposureId = targetId, 
        trueEffectSize = 1
      ))
    )
  }
}
sccsAnalysisList <- list()
analysisToInclude <- data.frame()
for (i in seq_len(nrow(uniqueTargetIndications))) {
  targetIndication <- uniqueTargetIndications[i, ]
  getDbSccsDataArgs <- SelfControlledCaseSeries::createGetDbSccsDataArgs(
    maxCasesPerOutcome = 1000000,
    useNestingCohort = !is.na(targetIndication$indicationId),
    nestingCohortId = targetIndication$indicationId,
    studyStartDate = studyStartDate,
    studyEndDate = studyEndDate,
    deleteCovariatesSmallCount = 0
  )
  createStudyPopulationArgs = SelfControlledCaseSeries::createCreateStudyPopulationArgs(
    firstOutcomeOnly = TRUE,
    naivePeriod = 365,
    minAge = if (is.na(targetIndication$minAge)) NULL else targetIndication$minAge,
    maxAge = if (is.na(targetIndication$maxAge)) NULL else targetIndication$maxAge
  )
  covarPreExp <- SelfControlledCaseSeries::createEraCovariateSettings(
    label = "Pre-exposure",
    includeEraIds = "exposureId",
    start = -30,
    startAnchor = "era start",
    end = -1,
    endAnchor = "era start",
    firstOccurrenceOnly = FALSE,
    allowRegularization = FALSE,
    profileLikelihood = FALSE,
    exposureOfInterest = FALSE
  )
  calendarTimeSettings <- SelfControlledCaseSeries::createCalendarTimeCovariateSettings(
    calendarTimeKnots = 5,
    allowRegularization = TRUE,
    computeConfidenceIntervals = FALSE
  )
  # seasonalitySettings <- SelfControlledCaseSeries:createSeasonalityCovariateSettings(
  #   seasonKnots = 5,
  #   allowRegularization = TRUE,
  #   computeConfidenceIntervals = FALSE
  # )
  fitSccsModelArgs <- SelfControlledCaseSeries::createFitSccsModelArgs(
    prior = createPrior("laplace", useCrossValidation = TRUE), 
    control = createControl(
      cvType = "auto", 
      selectorType = "byPid", 
      startingVariance = 0.1, 
      seed = 1, 
      resetCoefficients = TRUE, 
      noiseLevel = "quiet")
  )
  for (j in seq_len(nrow(sccsTimeAtRisks))) {
    covarExposureOfInt <- SelfControlledCaseSeries::createEraCovariateSettings(
      label = "Main",
      includeEraIds = "exposureId",
      start = sccsTimeAtRisks$riskWindowStart[j],
      startAnchor = gsub("cohort", "era", sccsTimeAtRisks$startAnchor[j]),
      end = sccsTimeAtRisks$riskWindowEnd[j],
      endAnchor = gsub("cohort", "era", sccsTimeAtRisks$endAnchor[j]),
      firstOccurrenceOnly = FALSE,
      allowRegularization = FALSE,
      profileLikelihood = TRUE,
      exposureOfInterest = TRUE
    )
    createSccsIntervalDataArgs <- SelfControlledCaseSeries::createCreateSccsIntervalDataArgs(
      eraCovariateSettings = list(covarPreExp, covarExposureOfInt),
      # seasonalityCovariateSettings = seasonalityCovariateSettings,
      calendarTimeCovariateSettings = calendarTimeSettings
    )
    description <- "SCCS"
    if (!is.na(targetIndication$indicationId)) {
      description <- sprintf("%s, having %s", description, cohortDefinitionSet %>% 
                               filter(cohortId == targetIndication$indicationId) %>%
                               pull(cohortName))
    }
    if (targetIndication$genderConceptIds == "8507") {
      description <- sprintf("%s, male", description)
    } else if (targetIndication$genderConceptIds == "8532") {
      description <- sprintf("%s, female", description)
    }
    if (!is.na(targetIndication$minAge) || !is.na(targetIndication$maxAge)) {
      description <- sprintf("%s, age %s-%s", 
                             description,
                             if(is.na(targetIndication$minAge)) "" else targetIndication$minAge,
                             if(is.na(targetIndication$maxAge)) "" else targetIndication$maxAge)
    }
    description <- sprintf("%s, %s", description, sccsTimeAtRisks$label[j])
    sccsAnalysisList[[length(sccsAnalysisList) + 1]] <- SelfControlledCaseSeries::createSccsAnalysis(
      analysisId = length(sccsAnalysisList) + 1,
      description = description,
      getDbSccsDataArgs = getDbSccsDataArgs,
      createStudyPopulationArgs = createStudyPopulationArgs,
      createIntervalDataArgs = createSccsIntervalDataArgs,
      fitSccsModelArgs = fitSccsModelArgs
    )
    analysisToInclude <- bind_rows(analysisToInclude, data.frame(
      exposureId = targetIndication$exposureId,
      analysisId = length(sccsAnalysisList)
    ))
  }
}
analysesToExclude <- expand.grid(
  exposureId = unique(analysisToInclude$exposureId),
  analysisId = unique(analysisToInclude$analysisId)
) %>%
  anti_join(analysisToInclude, by = join_by(exposureId, analysisId))
selfControlledModuleSpecifications <- creatSelfControlledCaseSeriesModuleSpecifications(
  sccsAnalysisList = sccsAnalysisList,
  exposuresOutcomeList = eoList,
  analysesToExclude = analysesToExclude,
  combineDataFetchAcrossOutcomes = FALSE,
  sccsDiagnosticThresholds = SelfControlledCaseSeries::createSccsDiagnosticThresholds(
    mdrrThreshold = 10,
    easeThreshold = 0.25,
    timeTrendPThreshold = 0.05,
    preExposurePThreshold = 0.05
  )
)


# PatientLevelPredictionModule -------------------------------------------------
source("https://raw.githubusercontent.com/OHDSI/PatientLevelPredictionModule/v0.1.0/SettingsFunctions.R")

modelDesignList <- list()
for (i in seq_along(tcis)) {
  tci <- tcis[[i]]
  targetId <- cohortDefinitionSet %>% 
    filter(subsetParent == tci$targetId & subsetDefinitionId == i) %>%
    pull(cohortId)
  for (j in seq_len(nrow(plpTimeAtRisks))) {
    for (k in seq_along(nrow(outcomes))) {
      if (useCleanWindowForPriorOutcomeLookback)
        priorOutcomeLookback <- outcomes$cleanWindow[k]
      else
        priorOutcomeLookback <- 99999
      modelDesignList[[length(modelDesignList) + 1]] <- PatientLevelPrediction::createModelDesign(
        targetId = targetId,
        outcomeId = outcomes$cohortId[k],
        restrictPlpDataSettings = PatientLevelPrediction::createRestrictPlpDataSettings(
          sampleSize = 1000000,
          studyStartDate = studyStartDate,
          studyEndDate = studyEndDate,
          firstExposureOnly = FALSE,
          washoutPeriod = 0
        ),
        populationSettings = PatientLevelPrediction::createStudyPopulationSettings(
          riskWindowStart = plpTimeAtRisks$riskWindowStart[j],
          startAnchor = plpTimeAtRisks$startAnchor[j],
          riskWindowEnd = plpTimeAtRisks$riskWindowEnd[j],
          endAnchor = plpTimeAtRisks$endAnchor[j],
          removeSubjectsWithPriorOutcome = TRUE,
          priorOutcomeLookback = priorOutcomeLookback,
          requireTimeAtRisk = FALSE,
          binary = TRUE,
          includeAllOutcomes = TRUE,
          firstExposureOnly = FALSE,
          washoutPeriod = 0,
          minTimeAtRisk = plpTimeAtRisks$riskWindowEnd[j] - plpTimeAtRisks$riskWindowStart[j],
          restrictTarToCohortEnd = FALSE
        ),
        covariateSettings = FeatureExtraction::createCovariateSettings(
          useDemographicsGender = TRUE,
          useDemographicsAgeGroup = TRUE,
          useConditionGroupEraLongTerm = TRUE,
          useDrugGroupEraLongTerm = TRUE,
          useVisitConceptCountLongTerm = TRUE
        ),
        preprocessSettings = PatientLevelPrediction::createPreprocessSettings(),
        modelSettings = PatientLevelPrediction::setLassoLogisticRegression()
      )
    }
  }
}
plpModuleSpecifications <- createPatientLevelPredictionModuleSpecifications(
  modelDesignList = modelDesignList
)


# Combine across modules -------------------------------------------------------
analysisSpecifications <- Strategus::createEmptyAnalysisSpecificiations() %>%
  Strategus::addSharedResources(cohortDefinitionShared) %>% 
  Strategus::addSharedResources(negativeControlsShared) %>%
  Strategus::addModuleSpecifications(cohortGeneratorModuleSpecifications) %>%
  Strategus::addModuleSpecifications(cohortDiagnosticsModuleSpecifications) %>%
  Strategus::addModuleSpecifications(characterizationModuleSpecifications) %>%
  Strategus::addModuleSpecifications(cohortIncidenceModuleSpecifications) %>%
  Strategus::addModuleSpecifications(cohortMethodModuleSpecifications) %>%
  Strategus::addModuleSpecifications(selfControlledModuleSpecifications) %>%
  Strategus::addModuleSpecifications(plpModuleSpecifications)

if (!dir.exists(rootFolder)) {
  dir.create(rootFolder, recursive = TRUE)
}
ParallelLogger::saveSettingsToJson(analysisSpecifications, file.path(rootFolder, "analysisSpecifications.json"))