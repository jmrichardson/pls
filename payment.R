library(shiny)
library(shinyBS)
library(tvm)
library(financial)

# Change working directory
if ( file.exists('/home/john') ) {
  setwd("/home/john/Dropbox/pls")
  path <- '/usr/bin/chromium-browser'
} else {
  setwd("C:/Users/john/Dropbox/pls")
  path <- file.path('C:','Program Files (x86)','Google','Chrome','Application','chrome.exe')
}

# Load xIRR and lcROI functions
load('data/lcROI.rda')

help <- function() {
return('
<p>NO HELP YET</p>
')
}

dollar <- function(value, currency.sym="$", digits=2, sep=",", decimal=".") {
  gsub(".00$","",paste(
        currency.sym,
        formatC(value, format = "f", big.mark = sep, digits=digits, decimal.mark=decimal),
        sep=""
  ))
}

percent <- function(x, digits = 2, format = "f", ...) {
  paste0(formatC(100 * x, format = format, digits = digits, ...), "%")
}

if(!exists('noteInfo')) {
  load('data/noteInfo.rda')
}


ui <- shinyUI(fluidPage(
  
  tags$head(
    tags$style(type="text/css","
    .well {
      margin-left: 20px;
      margin-right: 20px;
    }
    .container-fluid {
      margin-top: 20px;
    }
    .inline {
      display: inline-block;
    }
    .alert {
      margin-left: 20px;
    }
   
    ")
  ),
  
  fluidRow(
    wellPanel(
      div(class='inline',
          numericInput("nid","Note ID", value=NULL, min=0, step=1, width='200px')
      ),
      actionButton("submit", "Submit",class='inline'),
      tags$button( "Close", id="close", type="button", class="btn action-button", onclick="self.close()"),
      bsAlert("alert")
    )
  ),
  fluidRow(
    wellPanel(
      bsCollapse(id = "main", multiple=TRUE, open = c("Summary","Payment History"),
        bsCollapsePanel("Summary", 
          
          fluidRow(
            column(3,
              "Note ID:", 
              textOutput('id', inline=TRUE)
            ),
            column(3,
              "Interest Rate:", 
              textOutput('intRate', inline=TRUE)
            ),
            column(3,
              "Term:", 
              textOutput('term', inline=TRUE)
            ),
            column(3,
              "Installment:", 
              textOutput('installment', inline=TRUE)
            )
          ),
          fluidRow(
            column(3,
              "Status:", 
              textOutput('status', inline=TRUE)
            ),
            column(3,
              "Issue Date:", 
              textOutput('issueDate', inline=TRUE)
            ),
            column(3,
              "Amount:", 
              textOutput('amount', inline=TRUE)
            ),
            column(3,
              "IRR:", 
              textOutput('irr', inline=TRUE)
            )
          ),
          fluidRow(
            column(3,
              "Balance:", 
              textOutput('balance', inline=TRUE)
            ),
            column(3,
              "Age:", 
              textOutput('age', inline=TRUE)
            ),
            column(3,
              "Vintage:", 
              textOutput('vintage', inline=TRUE)
            ),
            column(3,
              "", 
              textOutput('', inline=TRUE)
            )
          ),
          
           
          style = "info"),
        bsCollapsePanel("Payment History", 
          dataTableOutput('payHis'),
          style = "info")
        )
      
    )
  )


))

df<-data.frame()
server <- function(input, output, session) {
  
  session$onSessionEnded(function() {
    stopApp()
  })
  
#   # Get payment history
#   payHis <- reactive({
#     id=isolate(input$nid)
#     noteInfo[[id]][[id]][[1]]
#   })
#   
#   # Get probability curve
#   curve <- reactive({
#     id=isolate(input$nid)
#     noteInfo[[id]][[id]][[3]]
#   })
#   
#   # Get note summary
#   status <- reactive({
#     id=isolate(input$nid)
#     noteInfo[[id]][[id]][[2]]
#   })
  
  observeEvent(input$submit, {
    
    if (is.na(input$nid)) {
      createAlert(session,"alert", alertId="a1", 
        content="Please enter a valid Lending Club Note ID",
        style = "danger",
        append = FALSE)
      return()
    }
    
    id=as.character(input$nid)

    ret <<- lcROI(
      id,
      noteInfo[[id]][1],
      noteInfo[[id]][2],
      noteInfo[[id]][3]
    )
    
    
    
    output$irr <- renderText(
      percent(as.numeric(ret[2]))
    )
    
    
    output$id <- renderText(id)
    output$intRate <- renderText(percent(as.numeric(noteInfo[id][[1]][[2]]['IntRate'])))
    output$term <- renderText(as.character(noteInfo[id][[1]][[2]]['Term']))
    output$installment <- renderText(dollar(as.numeric(noteInfo[id][[1]][[2]]['Installment'])))
    output$status <- renderText(as.character(noteInfo[id][[1]][[2]]['Status']))
    # output$issueDate <- renderText(gsub('.{3}$', '',as.character.Date(noteInfo[id][[1]][[2]]['IssuedDate'])))
    output$amount <- renderText(dollar(as.numeric(noteInfo[id][[1]][[2]]['LoanAmount'])))
    output$age <- renderText(as.numeric(noteInfo[id][[1]][[2]]['Age']))
    output$vintage <- renderText(as.character(noteInfo[id][[1]][[2]]['Vintage']))
    output$balance <- renderText(dollar(as.numeric(noteInfo[id][[1]][[2]]['Balance'])))
    
    df <- noteInfo[id][[1]][[1]]
    df$Payment <- dollar(df$Payment)
    df$Principal <- dollar(df$Principal)
    # df$Month <- gsub('.{3}$', '',as.character.Date(df$Month))
    output$payHis <- renderDataTable(
      df[c(3,2,1)],
      options = list(paging = FALSE,
        searching = FALSE))
  })

  
}

# Browser launch settings
launch.browser = function(appUrl, browser.path=path) {
  system(sprintf('"%s" --disable-gpu --app="data:text/html,<html>
    <head>
    <title>Payment History</title>
    </head>
    <body>
    <script>window.resizeTo(850,850);window.location=\'%s\';</script>
    </body></html>" &', browser.path, appUrl))
}

shinyApp(ui = ui, server = server, options = list(launch.browser=launch.browser))

