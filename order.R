# Load required libraries


library(RCurl)
library(jsonlite)
library(plyr)
library(dplyr)
library(stringr)
library(lubridate)
library(gbm)
library(gtools)

# Get script arguments
args<-commandArgs(TRUE)
arg1<-args[1]
if (invalid(arg1)) {
  arg1=''
}

# Change working directory
if ( file.exists('/home/john') ) {
  setwd("/home/john/Dropbox/pls")
} else if ( file.exists('/home/user') ) {
  setwd("/home/user/pls")
} else {
  setwd("C:/Users/john/Dropbox/pls")
}

# Load pre-built models
load('models/fitGbm.rda')

# Include milliseconds in log
options(digits.secs=4)

# Function to log status message
log <- function(msg) {
  # now=paste(with_tz(now(),"America/Los_Angeles"),'PST')
  now=paste(now(),'PST')
  write(paste(now,msg,sep="|"), file="log/system.log",append=TRUE)
}

# Helper function to view structures in RStudio window
more <- function(x) {
  file <- tempfile()
  sink(file); on.exit(sink())
  print(x)
  file.show(file, delete.file = T)
}

# Currency formatter function
printCurrency <- function(value, currency.sym="$", digits=2, sep=",", decimal=".") {
  paste(currency.sym,
    formatC(value, format = "f", big.mark = sep, digits=digits, decimal.mark=decimal),sep="")
}

# Number formatter function
printNumber <- function(value, digits=0, sep=",", decimal=".") {
  formatC(value, format = "f", big.mark = sep, digits=digits, decimal.mark=decimal)
}


log('-----------------------------------------------------------------------------------------------------')
log("Starting PLS")

# Load User(s) configuration
source('orderConfig.R')

# Load User(s)
load('config/filter.rda')

# Test API authentication
header=getURL(lc$urlCash,header = TRUE, httpheader = c('Authorization' = user$token,
  'Accept' = "application/json",
  'Content-type' = "application/json"))
if(grepl('Unauthorized',header)) {
  msg='Lending Club Authentication failed.  Check user configuration'
  log(msg)
  stop(msg)
}

# Get previously purchased note ids
if(file.exists('config/ids.rda')) {
  load('config/ids.rda')
} else {
  ids=c()
}

# Obtain initial cash 
h = basicTextGatherer()
for (attempt in 1:5) {
  lc$jsonCash <- getURL(lc$urlCash,httpheader = c('Authorization' = user$token,
    'Accept' = "application/json",
    'Content-type' = "application/json"))
  if ( is.null(lc$jsonCash) | length(lc$jsonCash) == 0 ) {
    log(paste('Unable to get initial available cash. Attempt: ',attempt,sep=""))
    next
  }
  if ( ! grepl("availableCash",lc$jsonCash) ) {
    log(paste('Unable to obtain initial available cash. Attempt: ',attempt,sep=""))
    next
  }
  lc$cash <- fromJSON(lc$jsonCash)$availableCash
  if ( ! is.numeric(lc$cash) ) {
    log(paste('Unable to obtain initial available cash. Attempt: ',attempt,sep=""))
    next
  }
  log(paste('Initial cash available: ',printCurrency(lc$cash),sep=""))
  break
}
if ( ! is.numeric(lc$cash) ) {
  msg='Unable to obtain initial available cash'
  log(msg)
  stop(msg)
}

# Verify have above minimum cash level + investment amount
if(lc$cash <= user$minCash + user$amountPerNote) {
  msg <- paste('Available cash less than min cash plus amount per note: $',
    user$minCash + user$amountPerNote,' (exit)',sep='')
  log(msg)
  stop(msg)
}

# Set maximum notes per cash parameters
lc$maxNotesPerCash <- floor(lc$cash / user$amountPerNote)


if(arg1=='nolist') {
  log('Downloading notes from most recent listing period')
  # Set default apiTime
  apiTimeStart <- proc.time()[3]
  for (cnt in 1:lc$maxNoteCount) {
    # Loop to wait 1 second between API calls
    while (TRUE) {
      if(proc.time()[3] > apiTimeStart+1) { 
        apiTimeStart <- proc.time()[3]
        newJson <- getURL(lc$urlLoanList,httpheader = c('Authorization' = user$token,
          'Accept' = "application/json",
          'Content-type' = "application/json"))
        apiTimeElapse <- proc.time()[3] - apiTimeStart
        break
      }
    }
    if ( is.null(newJson) | length(newJson) == 0 ) {
      log(paste("List detection (",cnt," of ",lc$maxNoteCount,") - Invalid API response",sep=''))
      next
    }
    if ( ! grepl("pubRec",newJson) ) {
      log(paste("List detection (",cnt," of ",lc$maxNoteCount,") - Invalid API response",sep=''))
      next
    }
    loans = fromJSON(newJson)$loans
    if ( ! nrow(loans) ) {
      log(paste("List detection (",cnt," of ",lc$maxNoteCount,") - Invalid API result",sep=''))
      next
    }
    newIds <- loans$id
    newNoteCount <- length(newIds)
    log(paste("Note count of most recent list: ",newNoteCount,sep=''))
    list=TRUE
    listTime=with_tz(now(),"America/Los_Angeles")
    break
  }
} else {
  log("Starting loan list detection")
  
  # Obtain starting note count
  prevIds <- c()
  for (attempt in 1:5) {
    startJson <- getURL(lc$urlLoanList,httpheader = c('Authorization' = user$token,
      'Accept' = "application/json",
      'Content-type' = "application/json"))
    if ( is.null(startJson) | length(startJson) == 0 ) {
      log("Invalid API result from start note count.  Attempting connection again...")
      next
    }
    if ( ! grepl("pubRec",startJson) ) {
      log("Invalid API response from start note count.  Attempting connection again...")
      next
    }
    prevIds <- fromJSON(startJson)$loans$id
    if ( ! length(prevIds) ) {
      log("Invalid API response from initial note count.  Attempting connection again...")
      next
    }
    log(paste("Initial note count of most recent loan list:",length(prevIds)))
    break
  }
  if(length(prevIds)==0) {
    msg <- 'Unable to obtain initial note count'
    log(msg)
    stop(msg)
  }
  
  
  # List detection
  list=FALSE
  # Set default apiTime
  apiTimeStart <- proc.time()[3]
  for (cnt in 1:lc$maxNoteCount) {
    # Loop to wait 1 second between API calls
    while (TRUE) {
      if(proc.time()[3] > apiTimeStart+1) { 
        apiTimeStart <- proc.time()[3]
        newJson <- getURL(lc$urlLoanList,httpheader = c('Authorization' = user$token,
          'Accept' = "application/json",
          'Content-type' = "application/json"))
        apiTimeElapse <- proc.time()[3] - apiTimeStart
        break
      }
    }
    if ( is.null(newJson) | length(newJson) == 0 ) {
      log(paste("List detection (",cnt," of ",lc$maxNoteCount,") - Invalid API response",sep=''))
      next
    }
    if ( ! grepl("pubRec",newJson) ) {
      log(paste("List detection (",cnt," of ",lc$maxNoteCount,") - Invalid API response",sep=''))
      next
    }
    loans = fromJSON(newJson)$loans
    if ( ! nrow(loans) ) {
      log(paste("List detection (",cnt," of ",lc$maxNoteCount,") - Invalid API result",sep=''))
      next
    }
    newIds <- loans$id
    newNoteCount <- length(newIds)
    
    # No previous notes in new notes and greater than threshold to detect list
    if ( ! any(prevIds %in% newIds) & newNoteCount > lc$numNotesThresh ) {
      list=TRUE
      listTime=with_tz(now(),"America/Los_Angeles")
      log(paste("List detected - Note count of most recent list: ",newNoteCount,sep=''))
      break
    } else {
      log(paste("List detection (",cnt," of ",lc$maxNoteCount,")",sep=''))
    }
  }
  
  # Used for testing
  # save(loans,newIds,newNoteCount,list,listTime,file='data/loans.rda')
  
  # Only continue if note list detected
  if(!list) { 
    msg="New note listing not detected"
    log(msg)
    stop(msg)
  }
}

# Add model probability to each loan
loans$earliestCrLine <- ymd(substring(loans$earliestCrLine,1,10))
loans$n=ymd(Sys.Date())
loans$earliestCrLineMonths=as.integer(round((loans$n - loans$earliestCrLine)/30.4375)-1)
loans$installmentIncomeRatio=round(loans$installment/(loans$annualInc/12)*100)
loans$revolBalAnnualIncRatio=round(loans$revolBal/loans$annualInc*100)
loans$grade <- factor(loans$grade)
loans$subGrade <- factor(loans$subGrade)
loans$homeOwnership <- factor(loans$homeOwnership)
loans$purpose <- factor(loans$purpose)
loans$addrState <- factor(loans$addrState)
loans$addrZip <- factor(loans$addrZip)
loans$model=predict(fitGbm,newdata=loans,n.trees=fitGbm$n.trees,type="response")
loans$model=round(loans$model*100-1)

# Remvoe any rows with missing model values
loans=subset(loans, !is.na(model))
newNoteCount=nrow(loans)
if(newNoteCount<=0) {
  msg='Loan modelling error'
  log(msg)
  stop(msg)
}

# Remove uneeded fields
loans$n=NULL
loans$gbmProb=NULL


#loans$pctFunded = loans$fundedAmount / loans$loanAmount
#avgPctFunded <- round(mean(loans$pctFunded)*100)
#log(paste('Average notes funded: ',avgPctFunded,'%',sep=''))

timeStampFile = gsub(" ","_",gsub(":","-",listTime))
save(loans,file=paste('loans/',timeStampFile,'_new_loans.rda',sep=''))


# timeStampFile = gsub(" ","_",gsub(":","-",listTime))
# write.csv(loans,file=paste('data/loans/',timeStampFile,'_PST_new_notes.csv',sep=''),row.names=F)

# Simple loop to stop execution on error
for(one in 1) {
  
  # Set maximum notes allowed per filter
  lc$maxNotesPerFilterMax <- round(user$filterMaxPct/100 * newNoteCount)
  
  # Obtain loan ids based on user provided criteria
  lc$filteredLoansIds <- loans %>%
    filter_(filterStrProd) %>%
    arrange_(paste(user$sortOrder,'(',user$sortField,')',sep='')) %>%
    select(id) 
  
  lc$totalFilteredLoans <- nrow(lc$filteredLoansIds)
  
  if (lc$totalFilteredLoans < 1) {
    log('No notes match filter criteria')
    break
  }
  
  if (lc$totalFilteredLoans > lc$maxNotesPerFilterMax) {
    log('Filtered notes exceed max percent notes per filter')
    break
  }
  
  # Apply user maximums to filtered notes
  lc$filteredLoansIds <- head(lc$filteredLoansIds,user$maxNotesPerOrder)
  lc$filteredLoansIds <- head(lc$filteredLoansIds,lc$maxNotesPerCash)

  lc$totalFilteredLoans <- nrow(lc$filteredLoansIds)
  log(paste('Filtered notes after search criteria and user parameters:',lc$totalFilteredLoans))

  # Do not purchase notes PLS already invested
  skipNotes <- lc$filteredLoansIds[lc$filteredLoansIds$id %in% ids,]
  numSkipNotes <- length(skipNotes)
  if(numSkipNotes > 0) {
    for(i in 1:numSkipNotes) {
      log(paste('Previously invested in loan ID:',skipNotes[[i]] ))
    }
    lc$filteredLoansIds <- as.data.frame(lc$filteredLoansIds[!lc$filteredLoansIds$id %in% ids,])
  }
  
  # Total filtered loans given filter and user maximums
  lc$totalFilteredLoans <- nrow(lc$filteredLoansIds)
  
  # One final test to make sure there are at least one id left to order
  if (lc$totalFilteredLoans < 1) {
    log('No notes to order')
    break
  } 
  
  log(paste('Notes to order:',lc$totalFilteredLoans))
  
  
  ##################
  ### Order code ###
  ##################
  
  if (user$submit=='Yes') {
    
    # Create order JSON based on filtered Ids
    lc$order$aid <- user$accNum
    if (user$portfolioId) {
      lc$order$orders <- data.frame(lc$filteredLoansIds,
        user$amountPerNote,
        user$portfolioId)
      colnames(lc$order$orders) <- c('loanId','requestedAmount','portfolioId')
    } else {
      lc$order$orders <- data.frame(lc$filteredLoansIds,
        user$amountPerNote)
      colnames(lc$order$orders) <- c('loanId','requestedAmount')
    }
    lc$orderJSON <- toJSON(lc$order,auto_unbox=TRUE)
    
    log('Sending API order request to Lending Club')
    lc$resultOrderJSON <- postForm(lc$urlOrders,.opts=list(postfields = lc$orderJSON,
      httpheader = c('Authorization' = user$token,
        'Accept' = "application/json",
        'Content-type' = "application/json")))
    if ( is.null(lc$resultOrderJSON) | length(lc$resultOrderJSON) == 0 ) {
      log('Order error')
      break
    }
    if ( ! grep("orderInstructId",lc$resultOrderJSON) ) {
      log('Order failed')
      break
    }
    lc$resultOrder <- fromJSON(lc$resultOrderJSON)
    
    # Log LC order response
    res=lc$resultOrder$orderConfirmations
    for(i in 1:nrow(res)) {
      row <- res[i,]
      log(paste('loanId:',row$loanId,' reqAmnt:$',row$requestedAmount,
        ' invAmnt:$',row$investedAmount,' status:',row$executionStatus,sep=''))   
    }
    
    # Save ordered ids to avoid re-purchase
    newIds=lc$resultOrder$orderConfirmations$loanId
    ids=unique(c(ids,newIds))  
    save(ids,file='config/ids.rda')
    
    # Log results
    lc$resultOrder$requestedAmount <- sum(lc$resultOrder$orderConfirmation$requestedAmount)
    log(paste('Total requested amount:',lc$resultOrder$requestedAmount))
    lc$resultOrder$investedAmount <- sum(lc$resultOrder$orderConfirmation$investedAmount)
    log(paste('Total invested amount:',lc$resultOrder$investedAmount))
    lc$resultOrder$numOrderedNotes <- nrow(subset(lc$resultOrder$orderConfirmation, investedAmount>0))
    log(paste('Total ordered notes:',lc$resultOrder$numOrderedNotes))
  } else {
    log('Order submission disabled')
  }        
}
log('PLS Service Finished')




