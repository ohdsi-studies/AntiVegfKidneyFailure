##=========== START OF INPUTS ==========
connectionDetailsReference <- "Jmdc"
outputLocation <- 'D:/git/anthonysena/AntiVegfKidneyFailure'
# For uploading the results. You should have received the key file from the study coordinator:
keyFileName <- "[location where you are storing: e.g. ~/keys/study-data-site-covid19.dat]"
userName <- "study-data-site-covid19"
##=========== END OF INPUTS ==========
##################################
# DO NOT MODIFY BELOW THIS POINT
##################################

rootFTPFolder <- function() {
  return("/sos-fq/")
}

zipResults <- function(outputLocation, connectionDetailsReference) {
  resultsFolder <- file.path(outputLocation, connectionDetailsReference, "strategusOutput")
  zipFileName <- file.path(resultsFolder, paste0("Results_", connectionDetailsReference, ".zip"))
  DatabaseConnector::createZipFile(
    zipFile = zipFileName,
    files = resultsFolder,
    rootFolder = resultsFolder
  )
  return(zipFileName)
}

#' Upload results to OHDSI server
#' 
#' @details 
#' This function uploads the 'Results_<databaseId>.zip' to the OHDSI SFTP server. Before sending, you can inspect the zip file,
#' wich contains (zipped) CSV files. You can send the zip file from a different computer than the one on which is was created.
#' 
#' @param privateKeyFileName   A character string denoting the path to the RSA private key provided by the study coordinator.
#' @param userName             A character string containing the user name provided by the study coordinator.
#' @param outputFolder         Name of local folder to place results; make sure to use forward slashes
#'                             (/). Do not use a folder on a network drive since this greatly impacts
#'                             performance.
#'                             
uploadResults <- function(outputLocation,
                          connectionDetailsReference,
                          privateKeyFileName, 
                          userName, 
                          remoteFolder = rootFTPFolder()) {
  fileName <- zipResults(outputLocation, connectionDetailsReference)
  OhdsiSharing::sftpUploadFile(privateKeyFileName = privateKeyFileName, 
                               userName = userName,
                               remoteFolder = remoteFolder,
                               fileName = fileName)
  ParallelLogger::logInfo("Finished uploading")
}

uploadResults(
  outputLocation = outputLocation,
  connectionDetailsReference = connectionDetailsReference,
  privateKeyFileName = privateKeyFileName,
  userName = userName
)