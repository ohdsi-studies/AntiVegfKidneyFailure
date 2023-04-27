# Install keyring - one time operation ---------
#install.packages("keyring")

# Provide your environment specific values ------
dbms <- "redshift"
cdmConnectionString <- "jdbc:redshift://your.server.goes.here:5439/your_cdm_database"
username <- "username-goes-here"
password = "password-goes-here"

# Set the Strategus keyring environment password
# running usethis::edit_r_environ(), then add
# this line to your file:
# 
# STRATEGUS_KEYRING_PASSWORD='sos'
#
# Restart your R Session to confirm it worked
if (Sys.getenv("STRATEGUS_KEYRING_PASSWORD") == "") {
  stop("Please set your .Renviron file up as instructed.")
}

# Run the rest to setup keyring ----------
##################################
# DO NOT MODIFY BELOW THIS POINT
##################################
keyringName <- "sos-challenge"
keyringPassword <- "sos" # This password is simply to avoid a prompt when creating the keyring

# Create the keyring if it does not exist.
# If it exists, clear it out so we can re-load the keys
allKeyrings <- keyring::keyring_list()
if (keyringName %in% allKeyrings$keyring) {
  if (keyring::keyring_is_locked(keyring = keyringName)) {
    keyring::keyring_unlock(keyring = keyringName, password = keyringPassword)
  }  
  # Delete all keys from the keyring so we can delete it
  message(paste0("Delete existing keyring: ", keyringName))
  keys <- keyring::key_list(keyring = keyringName)
  if (nrow(keys) > 0) {
    for (i in 1:nrow(keys)) {
      keyring::key_delete(keys$service[i], keyring = keyringName)
    }
  }
  keyring::keyring_delete(keyring = keyringName)
}
keyring::keyring_create(keyring = keyringName, password = keyringPassword)

# Store the the user-specific configuration -----
keyring::key_set_with_value("dbms", password = dbms, keyring = keyringName)
keyring::key_set_with_value("cdmConnectionString", password = cdmConnectionString, keyring = keyringName)
keyring::key_set_with_value("username", password = username, keyring = keyringName)
keyring::key_set_with_value("password", password = password, keyring = keyringName)

# Print the values to confirm the configuration
message("Keyring values set as:")
keys <- c("dbms", "cdmConnectionString", "username", "password")
for (i in seq_along(keys)) {
  message(paste0(" - ", keys[i], ": ", keyring::key_get(keys[i], keyring = keyringName)))
}
