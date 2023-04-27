# install the network package
# install.packages('remotes')
remotes::install_github("OHDSI/Strategus")

library(Strategus)

##=========== START OF INPUTS ==========
# Add your json file location, connection to OMOP CDM data settings and 

# load the json spec
analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = "inst/analysisSpecification.json"
)
connectionDetailsReference <- "OptumDod"

connectionDetails = DatabaseConnector::createConnectionDetails(
  dbms = "redshift",
  connectionString = keyring::key_get(paste0("redShiftConnectionStringOhda", "OptumDod"), keyring = "ohda"),
  user = keyring::key_get("redShiftUserName", keyring = "ohda"),
  password = keyring::key_get("redShiftPassword", keyring = "ohda")
)


workDatabaseSchema <- 'scratch_asena5'
cdmDatabaseSchema <- 'cdm_optum_extended_dod_v2323'

outputLocation <- 'D:/git/ohdsi-studies/AntiVegfKidneyFailure'
minCellCount <- 5
cohortTableName <- "sos_vegf_kf"
resultsDatabaseSchema <- "sos_vegf_kf"

##=========== END OF INPUTS ==========

storeConnectionDetails(
  connectionDetails = connectionDetails,
  connectionDetailsReference = connectionDetailsReference
)

executionSettings <- createCdmExecutionSettings(
  connectionDetailsReference = connectionDetailsReference,
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTableName),
  workFolder = file.path(outputLocation, "strategusWork"),
  resultsFolder = file.path(outputLocation, "strategusOutput"),
  minCellCount = minCellCount
)

# Note: this environmental variable should be set once for each compute node
Sys.setenv("INSTANTIATED_MODULES_FOLDER" = file.path(outputLocation, "StrategusInstantiatedModules"))

execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  executionScriptFolder = file.path(outputLocation, "strategusExecution")
)

# Results Table Creation -------------------------------------------------------------
resultsDatabaseConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  connectionString = keyring::key_get("resultsServer", keyring = "ohda"),
  user = keyring::key_get("resultsUser", keyring = "ohda"),
  password = keyring::key_get("resultsPassword", keyring = "ohda")
)

# Setup logging 
ParallelLogger::addDefaultFileLogger(
  fileName = file.path(outputLocation, "results-schema-setup-log.txt"),
  name = "RESULTS_SCHEMA_SETUP_FILE_LOGGER"
)
ParallelLogger::addDefaultErrorReportLogger(
  fileName = file.path(outputLocation, 'results-schema-setup-errorReport.R'),
  name = "RESULTS_SCHEMA_SETUP_ERROR_LOGGER"
)

# Connect to the database 
connection <- DatabaseConnector::connect(connectionDetails = resultsDatabaseConnectionDetails)

# Create the schema (PG Specific)
sql <- "DROP SCHEMA IF EXISTS @schema CASCADE; CREATE SCHEMA @schema;"
sql <- SqlRender::render(sql = sql, schema = resultsDatabaseSchema)
DatabaseConnector::executeSql(connection = connection, sql = sql)

# Create the tables
isModuleComplete <- function(moduleFolder) {
  doneFileFound <- (length(list.files(path = moduleFolder, pattern = "done")) > 0)
  isDatabaseMetaDataFolder <- basename(moduleFolder) == "DatabaseMetaData"
  return(doneFileFound || isDatabaseMetaDataFolder)
}
moduleFolders <- list.dirs(path = file.path(outputLocation, "strategusOutput"), recursive = FALSE)
message("Creating result tables based on definitions found in ", file.path(outputLocation, "strategusOutput"))
for (moduleFolder in moduleFolders) {
  moduleName <- basename(moduleFolder)
  if (!isModuleComplete(moduleFolder)) {
    warning("Module ", moduleName, " did not complete. Skipping table creation")
  } else {
    if (startsWith(moduleName, "PatientLevelPrediction")) {
      message("- Creating PatientLevelPrediction tables")
      dbSchemaSettings <- PatientLevelPrediction::createDatabaseSchemaSettings(
        resultSchema = resultsDatabaseSchema,
        tablePrefix = "plp",
        targetDialect = DatabaseConnector::dbms(connection)
      )
      PatientLevelPrediction::createPlpResultTables(
        connectionDetails = resultsDatabaseConnectionDetails,
        targetDialect = dbSchemaSettings$targetDialect,
        resultSchema = dbSchemaSettings$resultSchema,
        deleteTables = FALSE,
        createTables = TRUE,
        tablePrefix = dbSchemaSettings$tablePrefix
      )
    } else if (startsWith(moduleName, "CohortDiagnostics")) {
      message("- Creating CohortDiagnostics tables")
      CohortDiagnostics::createResultsDataModel(
        connectionDetails = resultsDatabaseConnectionDetails,
        databaseSchema = resultsDatabaseSchema,
        tablePrefix = "cd_"
      )
    } else {
      message("- Creating results for module ", moduleName)
      rdmsFile <- file.path(moduleFolder, "resultsDataModelSpecification.csv")
      if (!file.exists(rdmsFile)) {
        stop("resultsDataModelSpecification.csv not found in ", resumoduleFolderltsFolder)
      } else {
        specification <- CohortGenerator::readCsv(file = rdmsFile)
        sql <- ResultModelManager::generateSqlSchema(csvFilepath = rdmsFile)
        sql <- SqlRender::render(
          sql = sql,
          database_schema = resultsDatabaseSchema
        )
        DatabaseConnector::executeSql(connection = connection, sql = sql)
      }
    }
  }
}

# Grant read only permissions to all tables (PG Specific)
sql <- "GRANT USAGE ON SCHEMA @schema TO @results_user;
        GRANT SELECT ON ALL TABLES IN SCHEMA @schema TO @results_user; 
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA @schema TO @results_user;"
sql <- SqlRender::render(
  sql = sql, 
  schema = resultsDatabaseSchema,
  results_user = keyring::key_get("resultsUser", keyring = "ohda")
)
DatabaseConnector::executeSql(connection = connection, sql = sql)

# Disconnect from the database
DatabaseConnector::disconnect(connection)

# Unregister loggers
ParallelLogger::unregisterLogger("RESULTS_SCHEMA_SETUP_FILE_LOGGER")
ParallelLogger::unregisterLogger("RESULTS_SCHEMA_SETUP_ERROR_LOGGER")

# Results upload ----------------------------------------------------------------
ParallelLogger::addDefaultFileLogger(
  fileName = file.path(outputLocation, "upload-log.txt"),
  name = "RESULTS_FILE_LOGGER"
)
ParallelLogger::addDefaultErrorReportLogger(
  fileName = file.path(outputLocation, 'upload-errorReport.R'),
  name = "RESULTS_ERROR_LOGGER"
)

# Connect to the database ------------------------------------------------------
connection <- DatabaseConnector::connect(connectionDetails = resultsDatabaseConnectionDetails)

# Upload results -----------------
isModuleComplete <- function(moduleFolder) {
  doneFileFound <- (length(list.files(path = moduleFolder, pattern = "done")) > 0)
  isDatabaseMetaDataFolder <- basename(moduleFolder) == "DatabaseMetaData"
  return(doneFileFound || isDatabaseMetaDataFolder)
}
# TODO - augment the execution pipeline to save things per-database
message("Uploading results")
moduleFolders <- list.dirs(path =  file.path(outputLocation, "strategusOutput"), recursive = FALSE)
for (moduleFolder in moduleFolders) {
  moduleName <- basename(moduleFolder)
  if (!isModuleComplete(moduleFolder)) {
    warning("Module ", moduleName, " did not complete. Skipping upload")
  } else {
    if (startsWith(moduleName, "PatientLevelPrediction")) {
      dbSchemaSettings <- PatientLevelPrediction::createDatabaseSchemaSettings(
        resultSchema = resultsDatabaseSchema,
        tablePrefix = "plp",
        targetDialect = DatabaseConnector::dbms(connection)
      )
      message("Loading PLP results")
      modulePath <- list.files(
        path = file.path(outputLocation, "strategusOutput"), 
        pattern = "PatientLevelPredictionModule",
        full.names = TRUE,
        include.dirs = TRUE
      )
      performanceFile <- file.path(modulePath, "performances.csv")
      if (!file.exists(performanceFile)) {
        warning("PatientLevelPrediction module in ",modulePath, " did not complete. Skipping upload")
      } else {
        PatientLevelPrediction::insertCsvToDatabase(
          csvFolder = modulePath,
          connectionDetails = resultsDatabaseConnectionDetails,
          databaseSchemaSettings = dbSchemaSettings,
          modelSaveLocation =  file.path(outputLocation, "strategusOutput", "PlPModels"),
          csvTableAppend = ""
        )
      }        
    } else {
      message("- Uploading results for module ", moduleName)
      rdmsFile <- file.path(moduleFolder, "resultsDataModelSpecification.csv")
      if (!file.exists(rdmsFile)) {
        stop("resultsDataModelSpecification.csv not found in ", resumoduleFolderltsFolder)
      } else {
        specification <- CohortGenerator::readCsv(file = rdmsFile)
        runCheckAndFixCommands = grepl("CohortDiagnostics", moduleName)
        ResultModelManager::uploadResults(
          connection = connection,
          schema = resultsDatabaseSchema,
          resultsFolder = moduleFolder,
          purgeSiteDataBeforeUploading = TRUE,
          databaseIdentifierFile = file.path(
            outputLocation, 
            "strategusOutput",
            "DatabaseMetaData/database_meta_data.csv"
          ),
          runCheckAndFixCommands = runCheckAndFixCommands,
          specifications = specification
        )
      }
    }
  }
}


# Disconnect from the database -------------------------------------------------
DatabaseConnector::disconnect(connection)

# Unregister loggers -----------------------------------------------------------
ParallelLogger::unregisterLogger("RESULTS_FILE_LOGGER")
ParallelLogger::unregisterLogger("RESULTS_ERROR_LOGGER")

