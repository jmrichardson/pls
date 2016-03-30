#https://www.lendingclub.com/browse/loanDetail.action?loan_id=38576176

# System configuration
library(shiny)
library(shinyBS)
library(RCurl)
library(jsonlite)
library(lubridate)
library(dplyr)
library(gbm)
library(gtools)


# Change working directory
if ( file.exists('/home/john') ) {
  setwd("/home/john/Dropbox/pls")
} else if ( file.exists('/home/user') ) {
  setwd("/home/user/pls")
} else {
  setwd("C:/Users/john/Dropbox/pls")
}

path <- '/usr/bin/chromium-browser'
# Change working directory
if ( file.exists('/home/john') ) {
  setwd("/home/john/Dropbox/pls")
} else if ( file.exists('/home/user') ) {
  setwd("/home/user/pls")
} else {
  setwd("C:/Users/john/Dropbox/pls")
  path <- file.path('C:','Program Files (x86)','Google','Chrome','Application','chrome.exe')
}

if (file.exists('config/filter.rda')) {
  load('config/filter.rda')
} else {
  filter <- list()
}

# Browser launch settings
launch.browser = function(appUrl, browser.path=path) {
  system(sprintf('"%s" --disable-gpu --app="data:text/html,<html>
    <head>
    <title>Browse Notes</title>
    </head>
    <body>
    <script>window.resizeTo(1050,700);window.location=\'%s\';</script>
    </body></html>" &', browser.path, appUrl))
}

# Load pre-built models
load('models/fitGbm.rda')

source('orderConfig.R')

# Test API authentication
header=getURL(lc$urlCash,header = TRUE, httpheader = c('Authorization' = user$token,
  'Accept' = "application/json",
  'Content-type' = "application/json"))
if(grepl('Unauthorized',header)) {
  system("notify-send -i error 'Lending Club Authentication Failed' 'Check user configuration'")
  stop('Authentication failed')
}




# Obtain all notes
for (attempt in 1:5) {
  notesJson <- getURL(lc$urlLoanListAll,httpheader = c('Authorization' = user$token,
    'Accept' = "application/json",
    'Content-type' = "application/json"))
  if ( is.null(notesJson) | length(notesJson) == 0 ) {
    next
  }
  if ( ! grepl("pubRec",notesJson) ) {
    next
  }
  loans = fromJSON(notesJson)$loans
  if ( ! nrow(loans) ) {
    next
  }
  break
}
if(nrow(loans)==0) {
  system("notify-send -i error 'Download Failed' 'Error downloading all notes'")
  stop('Download failed')
}


# Add model probability and other custom fields
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
loans$n=NULL

numLoans=nrow(loans)

loansFilter <- loans %>%
  filter_(filterStrProd) %>%
  arrange_(paste(user$sortOrder,'(',user$sortField,')',sep=''))

numLoansFilter <- nrow(loansFilter)

# Obtain new notes
for (attempt in 1:5) {
  notesJson <- getURL(lc$urlLoanList,httpheader = c('Authorization' = user$token,
    'Accept' = "application/json",
    'Content-type' = "application/json"))
  if ( is.null(notesJson) | length(notesJson) == 0 ) {
    next
  }
  if ( ! grepl("pubRec",notesJson) ) {
    next
  }
  newLoans = fromJSON(notesJson)$loans
  if ( ! nrow(newLoans) ) {
    next
  }
  break
}
if(nrow(newLoans)==0) {
  system("notify-send -i error 'Download Failed' 'Error downloading new notes'")
  stop('Download failed')
}

# Add model probability and other custom fields
newLoans$earliestCrLine <- ymd(substring(newLoans$earliestCrLine,1,10))
newLoans$n=ymd(Sys.Date())
newLoans$earliestCrLineMonths=as.integer(round((newLoans$n - newLoans$earliestCrLine)/30.4375)-1)
newLoans$installmentIncomeRatio=round(newLoans$installment/(newLoans$annualInc/12)*100)
newLoans$revolBalAnnualIncRatio=round(newLoans$revolBal/newLoans$annualInc*100)
newLoans$grade <- factor(newLoans$grade)
newLoans$subGrade <- factor(newLoans$subGrade)
newLoans$homeOwnership <- factor(newLoans$homeOwnership)
newLoans$purpose <- factor(newLoans$purpose)
newLoans$addrState <- factor(newLoans$addrState)
newLoans$addrZip <- factor(newLoans$addrZip)
newLoans$model=predict(fitGbm,newdata=newLoans,n.trees=fitGbm$n.trees,type="response")
newLoans$model=round(newLoans$model*100-1)

numNewLoans=nrow(newLoans)

newLoansFilter <- newLoans %>%
  filter_(filterStrProd) %>%
  arrange_(paste(user$sortOrder,'(',user$sortField,')',sep=''))

numNewLoansFilter <- nrow(newLoansFilter)

# load('test.rda')

shinyApp(
  
  ui = fluidPage(
    tags$head(
      tags$style(HTML("
        .dataTable td {
          overflow: hidden; /* this is what fixes the expansion */
          text-overflow: ellipsis; /* not supported in all browsers, but I accepted the tradeoff */
          white-space: nowrap;
        }
    "))
    ),
    fluidRow(
      br(),
      tabsetPanel(type = "tabs", 
        tabPanel("All Notes", 
          HTML('All notes currently listed (double click row to browse on Lending Club)<br><br>'),
          dataTableOutput(outputId="all")
        ), 
        tabPanel("All Notes Filtered", 
          HTML('All notes currently listed filtered by user criteria<br><br>'),
          dataTableOutput(outputId="allFiltered")
        ), 
        tabPanel("New Notes", 
          HTML('New notes listed in the most recent listing period<br><br>'),
          dataTableOutput(outputId="new")
        ), 
        tabPanel("New Notes Filtered", 
          HTML('New notes listed in the most recent listing period filtered by user criteria<br><br>'),          
          dataTableOutput(outputId="newFiltered")
        )
      )
    )
  ), 
  
  server = function(input, output, session) {
    
    session$onSessionEnded(function() {
      stopApp()
    })
    output$all <- renderDataTable(
     loans,
      options = list(lengthMenu = c(25, 50, 100, numLoans)),
      callback = "function(table) {
        table.on('click.dt', 'tr', function() {
          $(this).toggleClass('selected');
        });
        table.on('dblclick.dt', 'tr', function() {
          $(this).toggleClass('selected');
          Shiny.onInputChange('id',
                            $(this).closest('tr').find('td:first').text());
        });
      }"
    )
    output$allFiltered <- renderDataTable(
      loansFilter,
      options = list(lengthMenu = c(25, 50, 100, numLoansFilter)),
      callback = "function(table) {
        table.on('click.dt', 'tr', function() {
          $(this).toggleClass('selected');
        });
        table.on('dblclick.dt', 'tr', function() {
          $(this).toggleClass('selected');
          Shiny.onInputChange('id',
                            $(this).closest('tr').find('td:first').text());
        });
      }"
    )
    output$new <- renderDataTable(
      newLoans,
      options = list(lengthMenu = c(25, 50, 100, numNewLoans)),
      callback = "function(table) {
        table.on('click.dt', 'tr', function() {
          $(this).toggleClass('selected');
        });
        table.on('dblclick.dt', 'tr', function() {
          $(this).toggleClass('selected');
          Shiny.onInputChange('id',
                            $(this).closest('tr').find('td:first').text());
        });
      }"
    )
    output$newFiltered <- renderDataTable(
      newLoansFilter,
      options = list(lengthMenu = c(25, 50, 100, numNewLoansFilter)),
      callback = "function(table) {
        table.on('click.dt', 'tr', function() {
          $(this).toggleClass('selected');
        });
        table.on('dblclick.dt', 'tr', function() {
          $(this).toggleClass('selected');
          Shiny.onInputChange('id',
                            $(this).closest('tr').find('td:first').text());
        });
      }"
      
    )
    observe({
      if(!invalid(input$id>0)) {
        system(paste(path,' --disable-gpu "https://www.lendingclub.com/browse/loanDetail.action?loan_id=',input$id,'"',sep=''))
      }
    })

    
  },
  options = list(launch.browser=launch.browser)
)
    
    
      
      
      
 

