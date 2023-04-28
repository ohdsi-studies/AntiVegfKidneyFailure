##=========== START OF INPUTS ==========

connectionDetailsReference <- "Jmdc"
outputLocation <- 'D:/git/anthonysena/AntiVegfKidneyFailure'

##=========== END OF INPUTS ==========
##################################
# DO NOT MODIFY BELOW THIS POINT
##################################

# Results Table Creation -------------------------------------------------------------
strategusOutputPath <- file.path(outputLocation, connectionDetailsReference, "strategusOutput")
sqliteDbPath <- file.path(outputLocation, connectionDetailsReference, "results.sqlite")
resultsDatabaseSchema <- "main"
resultsDatabaseConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sqlite", 
  server = sqliteDbPath
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

# Create the tables
isModuleComplete <- function(moduleFolder) {
  doneFileFound <- (length(list.files(path = moduleFolder, pattern = "done")) > 0)
  isDatabaseMetaDataFolder <- basename(moduleFolder) == "DatabaseMetaData"
  return(doneFileFound || isDatabaseMetaDataFolder)
}
moduleFolders <- list.dirs(path = strategusOutputPath, recursive = FALSE)
message("Creating result tables based on definitions found in ", strategusOutputPath)
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

# Upload results -----------------
message("Uploading results")
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
        path = strategusOutputPath, 
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
          modelSaveLocation =  file.path(strategusOutputPath, "PlPModels"),
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
            strategusOutputPath,
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
