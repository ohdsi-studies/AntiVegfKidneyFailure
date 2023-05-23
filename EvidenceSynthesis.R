# Code for performing the evidence synthesis across sites. This does not need
# to be executed by each site. Instead, this code will be run only by the study
# coordinating center, after all results have been uploaded to the results database.
# install.packages("EvidenceSynthesis")
# install.packages("Strategus")
# remotes::install_github("ohdsi/ResultModelManager")

# Start of inputs --------------------------------------------------------------
resultsDatabaseConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  port = 5432,
  server = paste(keyring::key_get("antiVegfStudyServer"), keyring::key_get("antiVegfStudyDatabase"), sep = "/"),
  user = keyring::key_get("antiVegfStudyUser"),
  password = keyring::key_get("antiVegfStudyPassword")
)
resultsDatabaseSchema = keyring::key_get("antiVegfStudySchema")
outputLocation <- "D:/AntiVegfKidneyFailure"
# End of inputs ----------------------------------------------------------------


# Create Strategus analysis specifications -------------------------------------
library(Strategus)
library(dplyr)
source("https://raw.githubusercontent.com/ohdsi/EvidenceSynthesisModule/v0.1.3/SettingsFunctions.R")
evidenceSynthesisSourceCm <- createEvidenceSynthesisSource(sourceMethod = "CohortMethod",
                                                         likelihoodApproximation = "adaptive grid")
metaAnalysisCm <- createBayesianMetaAnalysis(evidenceSynthesisAnalysisId = 1,
                                           alpha = 0.05,
                                           evidenceSynthesisDescription = "Bayesian random-effects alpha 0.05 - adaptive grid",
                                           evidenceSynthesisSource = evidenceSynthesisSourceCm)
evidenceSynthesisSourceSccs <- createEvidenceSynthesisSource(sourceMethod = "SelfControlledCaseSeries",
                                                           likelihoodApproximation = "adaptive grid")
metaAnalysisSccs <- createBayesianMetaAnalysis(evidenceSynthesisAnalysisId = 2,
                                           alpha = 0.05,
                                           evidenceSynthesisDescription = "Bayesian random-effects alpha 0.05 - adaptive grid",
                                           evidenceSynthesisSource = evidenceSynthesisSourceSccs)
evidenceSynthesisAnalysisList <- list(metaAnalysisCm, metaAnalysisSccs)
evidenceSynthesisAnalysisSpecifications <- createEvidenceSynthesisModuleSpecifications(evidenceSynthesisAnalysisList)
analysisSpecifications <- createEmptyAnalysisSpecificiations() %>%
  addModuleSpecifications(evidenceSynthesisAnalysisSpecifications) 

# Create Strategus execution settings ------------------------------------------
library(Strategus)
storeConnectionDetails(connectionDetails = resultsDatabaseConnectionDetails,
                       connectionDetailsReference = "antiVegfResultsConnectionDetailsRef")
executionSettings <- createResultsExecutionSettings(
  resultsConnectionDetailsReference = "antiVegfResultsConnectionDetailsRef",
  resultsDatabaseSchema = resultsDatabaseSchema,
  workFolder = file.path(outputLocation, "work"),
  resultsFolder = file.path(outputLocation, "results"),
  minCellCount = 5
)

# Run Strategus ----------------------------------------------------------------
library(Strategus)
execute(analysisSpecifications = analysisSpecifications,
        executionSettings = executionSettings)

# Upload evidence synthesis results to database --------------------------------
library(dplyr)
connection <- DatabaseConnector::connect(resultsDatabaseConnectionDetails)
# # Backup old tables:
# backupFolder <- "d:/temp/resultsBackup"
# dir.create(backupFolder)
# tables <- DatabaseConnector::getTableNames(connection, resultsDatabaseSchema)
# for (table in tables) {
#   message(sprintf("Backing up table '%s.%s'", resultsDatabaseSchema, table))
#   data <- DatabaseConnector::dbReadTable(connection, table, databaseSchema = resultsDatabaseSchema)
#   saveRDS(data, file.path(backupFolder, sprintf("%s.rds", table)))
# }


# Create tables
resultsFolder <- file.path(outputLocation, "results", "EvidenceSynthesisModule_1")
rdmsFile <- file.path(resultsFolder, "resultsDataModelSpecification.csv")
specification <- readr::read_csv(file = rdmsFile, show_col_types = FALSE) %>%
  SqlRender::snakeCaseToCamelCaseNames()
if (DatabaseConnector::existsTable(connection, resultsDatabaseSchema, specification$tableName[1])) {
  # Tables already exist. Delete first. See https://github.com/OHDSI/ResultModelManager/issues/30
  sql <- paste(sprintf("DROP TABLE %s.%s;", resultsDatabaseSchema, unique(specification$tableName)), collapse = "\n")
  DatabaseConnector::executeSql(connection, sql) 
}
sql <- ResultModelManager::generateSqlSchema(csvFilepath = rdmsFile)
sql <- SqlRender::render(
  sql = sql,
  database_schema = resultsDatabaseSchema
)
DatabaseConnector::executeSql(connection, sql)

# Upload results
ResultModelManager::uploadResults(
  connection = connection,
  schema = resultsDatabaseSchema,
  resultsFolder = resultsFolder,
  purgeSiteDataBeforeUploading = F,
  specifications = specification
)

DatabaseConnector::disconnect(connection)
