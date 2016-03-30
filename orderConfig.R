# Load required libraries
# library(shiny)
# library(shinyBS)

# Load user configuration
load('config/user.rda')

# Initialize list
lc=list()

# Maximum times to check for new notes per list (roughly once a second)
lc$maxNoteCount = 300

# Number of new notes required for list detection
lc$numNotesThresh = 15

# LC API Version
lc$apiVersion = "v1"

# API URL
lc$urlLoanList = paste("https://api.lendingclub.com/api/investor/", 
  lc$apiVersion, 
  "/loans/listing",
  sep='')

# API URLs
lc$urlLoanList = paste("https://api.lendingclub.com/api/investor/", 
  lc$apiVersion, 
  "/loans/listing",
  sep='')
lc$urlLoanListAll = paste("https://api.lendingclub.com/api/investor/", 
  lc$apiVersion, 
  "/loans/listing?showAll=true",
  sep='')
lc$urlNotesOwned = paste("https://api.lendingclub.com/api/investor/",
  lc$apiVersion,
  "/accounts/",
  user$accNum,
  "/notes",
  sep='')
lc$urlCash = paste("https://api.lendingclub.com/api/investor/",
  lc$apiVersion,
  "/accounts/",
  user$accNum,
  "/availablecash",
  sep='')
lc$urlOrders = paste("https://api.lendingclub.com/api/investor/",
  lc$apiVersion,
  "/accounts/",
  user$accNum,
  "/orders",
  sep='')

# Curl options
options(RCurlOptions = list(verbose = FALSE, 
  followlocation = TRUE, 
  autoreferer = TRUE,
  ssl.verifypeer = FALSE,
  httpheader = c("Authorization" = user$token,
    "Accept" = "application/json",
    'Content-Type' = "application/json"),
  useragent = "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.101 Safari/537.36"))
