# View Strategus results in the results database
# remotes::install_github("ohdsi/ShinyAppBuilder", ref = "develop")
# remotes::install_github("ohdsi/OhdsiShinyModules", ref = "develop")

library(dplyr)
library(ShinyAppBuilder)
library(markdown)

##=========== START OF INPUTS ==========

connectionDetailsReference <- "Jmdc"
outputLocation <- 'D:/git/anthonysena/AntiVegfKidneyFailure'

##=========== END OF INPUTS ==========
##################################
# DO NOT MODIFY BELOW THIS POINT
##################################
# specify the connection to the results database
sqliteDbPath <- file.path(outputLocation, connectionDetailsReference, "results.sqlite")
resultsDatabaseSchema <- "main"
resultsDatabaseConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sqlite", 
  server = sqliteDbPath
)

# Specify about module ---------------------------------------------------------
aboutModule <- createDefaultAboutConfig(
  resultDatabaseDetails = NULL,
  useKeyring = FALSE
)

# Specify cohort generator module ----------------------------------------------
resultDatabaseDetails <- list(
  dbms = resultsDatabaseConnectionDetails$dbms,
  tablePrefix = 'cg_',
  cohortTablePrefix = 'cg_',
  databaseTablePrefix = '',
  schema = resultsDatabaseSchema,
  databaseTable = 'DATABASE_META_DATA'
)
cohortGeneratorModule <- createDefaultCohortGeneratorConfig(
  resultDatabaseDetails = resultDatabaseDetails,
  useKeyring = FALSE
)

# Specify cohort diagnostics module --------------------------------------------
resultDatabaseDetails <- list(
  dbms = resultsDatabaseConnectionDetails$dbms,
  tablePrefix = 'cd_',
#  cohortTablePrefix = 'cg_',
  databaseTablePrefix = '',
  schema = resultsDatabaseSchema,
  databaseTable = 'DATABASE_META_DATA'
)
cohortDiagnosticsModule <- createDefaultCohortDiagnosticsConfig(
  resultDatabaseDetails = resultDatabaseDetails,
  useKeyring = FALSE
)

# Specify characterization module ----------------------------------------------
resultDatabaseDetails <- list(
  dbms = resultsDatabaseConnectionDetails$dbms,
  tablePrefix = 'c_',
  cohortTablePrefix = 'cg_',
  databaseTablePrefix = '',
  schema = resultsDatabaseSchema,
  databaseTable = 'DATABASE_META_DATA',
  incidenceTablePrefix = "ci_"
)
characterizationModule <- createDefaultCharacterizationConfig(
  resultDatabaseDetails = resultDatabaseDetails,
  useKeyring = FALSE
)

# Specify cohort method module -------------------------------------------------
resultDatabaseDetails <- list(
  dbms = resultsDatabaseConnectionDetails$dbms,
  tablePrefix = 'cm_',
  cohortTablePrefix = 'cg_',
  databaseTablePrefix = '',
  schema = resultsDatabaseSchema,
  databaseTable = 'DATABASE_META_DATA'
)
cohortMethodModule <- createDefaultEstimationConfig(
  resultDatabaseDetails = resultDatabaseDetails,
  useKeyring = FALSE
)

# Specify cohort method module -------------------------------------------------
resultDatabaseDetails <- list(
  dbms = resultsDatabaseConnectionDetails$dbms,
  tablePrefix = 'sccs_',
  cohortTablePrefix = 'cg_',
  databaseTablePrefix = '',
  schema = resultsDatabaseSchema,
  databaseTable = 'DATABASE_META_DATA'
)
sccsModule <- createDefaultSCCSConfig(
  resultDatabaseDetails = resultDatabaseDetails,
  useKeyring = FALSE
)

# Specify patient-level prediction module --------------------------------------
resultDatabaseDetails <- list(
  dbms = resultsDatabaseConnectionDetails$dbms,
  tablePrefix = 'plp_',
  cohortTablePrefix = 'cg_',
  databaseTablePrefix = '',
  schema = resultsDatabaseSchema,
  databaseTable = 'DATABASE_META_DATA'
)
predictionModule <- createDefaultPredictionConfig(
  resultDatabaseDetails = resultDatabaseDetails,
  useKeyring = FALSE
)

# Combine module specifications ------------------------------------------------
shinyAppConfig <- initializeModuleConfig() %>%
  addModuleConfig(aboutModule) %>%
  addModuleConfig(cohortGeneratorModule) %>%
  addModuleConfig(cohortDiagnosticsModule) %>%
  addModuleConfig(characterizationModule) %>%
  addModuleConfig(cohortMethodModule) %>%
  addModuleConfig(sccsModule) %>%
  addModuleConfig(predictionModule)

# Launch shiny app -----------------------------------------------------
connectionHandler <- ResultModelManager::ConnectionHandler$new(resultsDatabaseConnectionDetails)
ShinyAppBuilder::createShinyApp(
  config = shinyAppConfig, 
  connection = connectionHandler
)