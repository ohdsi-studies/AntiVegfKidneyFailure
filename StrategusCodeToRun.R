# install the network package
# install.packages('remotes')
# remotes::install_github("OHDSI/Strategus", ref="results-upload")
library(Strategus)

##=========== START OF INPUTS ==========
connectionDetailsReference <- "Jmdc"
connectionDetails = DatabaseConnector::createConnectionDetails(
  dbms = keyring::key_get("dbms", keyring = "sos-challenge"),
  connectionString = keyring::key_get("cdmConnectionString", keyring = "sos-challenge"),
  user = keyring::key_get("username", keyring = "sos-challenge"),
  password = keyring::key_get("password", keyring = "sos-challenge")
)
workDatabaseSchema <- 'scratch_asena5'
cdmDatabaseSchema <- 'cdm_jmdc_v2325'
outputLocation <- 'D:/git/anthonysena/AntiVegfKidneyFailure'
minCellCount <- 5
cohortTableName <- "sos_vegf_kf"
resultsDatabaseSchema <- "sos_vegf_kf"

##=========== END OF INPUTS ==========
##################################
# DO NOT MODIFY BELOW THIS POINT
##################################
analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = "inst/analysisSpecification.json"
)

storeConnectionDetails(
  connectionDetails = connectionDetails,
  connectionDetailsReference = connectionDetailsReference,
  keyringName = "sos-challenge"
)

executionSettings <- createCdmExecutionSettings(
  connectionDetailsReference = connectionDetailsReference,
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTableName),
  workFolder = file.path(outputLocation, connectionDetailsReference, "strategusWork"),
  resultsFolder = file.path(outputLocation, connectionDetailsReference, "strategusOutput"),
  minCellCount = minCellCount
)

# Note: this environmental variable should be set once for each compute node
Sys.setenv("INSTANTIATED_MODULES_FOLDER" = file.path(outputLocation, "StrategusInstantiatedModules"))

execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  executionScriptFolder = file.path(outputLocation, connectionDetailsReference, "strategusExecution"),
  keyringName = "sos-challenge"
)


