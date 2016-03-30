# System configuration
library(shiny)
library(shinyBS)

# Change working directory
if ( file.exists('/home/john') ) {
  setwd("/home/john/Dropbox/pls")
  path <- '/usr/bin/chromium-browser'
} else {
  setwd("C:/Users/john/Dropbox/pls")
  path <- file.path('C:','Program Files (x86)','Google','Chrome','Application','chrome.exe')
}

load('config/config.rda')
load('data/fields.rda') 

help <- function() {
return('
You must have a valid Lending Club account with API access enabled
to use Peer Lending Server. Enter your account number and API token.
You can hover your mouse over each field to learn more about how PLS
uses the information:
<p></p>
<b>Frequently Asked Questions</b>
<p></p>
<li>What is the difference between "maximum notes per order" and "filter 
max percent"?<br>
<p class="tab">
"Maximum note per order" is an absolute maximum amount of notes that PLS
will order per execution. PLS will order notes upto this threshold with
priority specified by the sort field and sort order inputs.<br>

"Filter Max percent" sets a maximum percent of new notes to order as an
additional saftey measure for filters which 
may be incorrectly configured.  If the percent of new notes matching your 
filter criteria is greater than the specified max percent specified of all
available notes, the order will be canceled.  For example, a user mistakenly
creates a filter of notes with an interest rate > 1% instead of 15%, all available notes
will match this criteria and all notes up to the "maximum notes per order" 
will be ordered.  If the filter max percent field is set less than 100%, this order
would be canceled and no new notes ordered.
</p>
<li>What does "maintain minimum cash level" field do?<br>
<p class="tab">
When PLS starts, it obtains your available cash.  If your available cash
is less than the specified minimum cash level, PLS will not purchase new notes.
</p>


')
}

# Browser launch settings
launch.browser = function(appUrl, browser.path=path) {
  system(sprintf('"%s" --disable-gpu --app="data:text/html,<html>
    <head>
    <title>System Configuration</title>
    </head>
    <body>
    <script>window.resizeTo(830,555);window.location=\'%s\';</script>
    </body></html>" &', browser.path, appUrl))
}


buttonSaveValue <- 0

shinyApp(
  ui = 
        fluidPage(
          
  tags$head(
    tags$style(HTML("
    .well {
        margin-left: 10px;
        margin-right: 10px;
    }
    .tab { 
        margin-left: 25px; 
    }
    "))
  ),
          
  
          fluidRow(
            br(),
            wellPanel(
              fluidRow(
                column(4,
                  numericInput('accNum', 'Account Number', ifelse(length(config$accNum)>0,config$accNum,'')),
                  bsTooltip(id = "accNum", title = "Enter Lending Club account number", 
                    placement = "bottom", trigger = "hover")
                ),
                column(4,
                  textInput('token', 'Account Token', ifelse(length(config$token)>0,config$token,'')),
                  bsTooltip(id = "token", title = "Enter account API token found under LendingClub settings page", 
                    placement = "bottom", trigger = "hover")
                )
              )
            ),
            wellPanel(

              fluidRow(
                column(4,
                  numericInput('amountPerNote', 'Investment Amount Per Note', ifelse(length(config$amountPerNote)>0,config$amountPerNote,25),step=25),
                  bsTooltip(id = "amountPerNote", title = "Enter amount to invest per note", 
                    placement = "bottom", trigger = "hover")
                ),
                column(4,
                  numericInput('maxNotesPerOrder', 'Maximum Notes Per Order', ifelse(length(config$maxNotesPerOrder)>0,config$maxNotesPerOrder,1)),
                  bsTooltip(id = "maxNotesPerOrder", title = "Enter maximum number notes per order", 
                    placement = "bottom", trigger = "hover")
                ),
                column(4,
                  numericInput('minCash', 'Maintain Minimum Cash Level', ifelse(length(config$minCash)>0,config$minCash,0)),
                  bsTooltip(id = "minCash", title = "Enter minimum cash value to maintain in account", 
                    placement = "bottom", trigger = "hover")
                )
              ),
              fluidRow(
                column(4,
                  numericInput('portfolioId', 'Portfolio ID', ifelse(length(config$portfolioId)>0,config$portfolioId,0)),
                  bsTooltip(id = "portfolioId", title = "Emter defaul portfolio ID per order.  Enter 0 to not assign to any portfolio.", 
                    placement = "bottom", trigger = "hover")
                ),
                column(4,
                  numericInput('filterMaxPct', 'Filter Max Percent', ifelse(length(config$filterMaxPct)>0,config$filterMaxPct,15)),
                  bsTooltip(id = "filterMaxPct", title = "Max percent filtered new notes allowed.  This is a safety measure to prevent loose filters from ordering too many notes.  Order will not be submitted if percent notes filtered is greater than this amount.", 
                    placement = "bottom", trigger = "hover")
                )
              ),
              fluidRow (
                column(4,
                  selectInput('sortField', 'Sort Field', 
                    choices=fields,
                    multiple = FALSE,
                    selected = ifelse(length(config$sortField)>0,config$sortField,'intRate'),
                    selectize = TRUE),            
                  bsTooltip(id = "sortField", title = "Select priority field for note selection", 
                    placement = "top", trigger = "hover")
                ),
                column(4,
                  selectInput('sortOrder', 'Sort Order', 
                    choices=c('desc','asc'),
                    multiple = FALSE,
                    selected = ifelse(length(config$sortOrder)>0,config$sortOrder,'desc'),
                    selectize = TRUE),            
                  bsTooltip(id = "sortOrder", title = "Selection order used for sort field", 
                    placement = "top", trigger = "hover")
                ),
                column(4,
                  selectInput('submit', 'Submit Order', 
                    choices=c('No','Yes'),
                    selected=ifelse(length(config$submit)>0,config$submit,'No'),
                    selectize = TRUE),
                  bsTooltip(id = "submit", title = "Enable order submission", 
                    placement = "top", trigger = "hover")
                )
              )
            )
        
          ),
          
          fluidRow(
            column(5,
              actionButton('save', 'Save'),
              actionButton("reset", "Reset"),
              actionButton("help", "Help"),
              tags$button( "Close", id="close", type="button", class="btn action-button", onclick="self.close()")    
            ),
            column(7,
              bsAlert("alert"),      
              bsModal("helper", "System Configuration", "help", size = "large",
                HTML(help())
              )
            )
          )


      
      
    ), 
  
  server = function(input, output, session) {
    
    session$onSessionEnded(function() {
      stopApp()
    })
    observe({
      if(input$save > buttonSaveValue) {
        
        buttonSaveValue <<- input$save
                
        
        if (invalid(input$accNum)) {
          createAlert(session, anchorId = "alert", alertId="a1", 
            content="Please enter account number",
            style = "danger",
            append = FALSE)
          return()
        }
        
        if (input$token=='') {
          createAlert(session, anchorId = "alert", alertId="a1", 
            content="Please enter API token",
            style = "danger",
            append = FALSE)
          return()
        }
        
        if (invalid(input$amountPerNote) | input$amountPerNote %% 25 | input$amountPerNote < 25) {
          createAlert(session, anchorId = "alert", alertId="a1", 
            content="Please enter amount per note in multiples of 25 with minimum 25",
            style = "danger",
            append = FALSE)
          return()
        }
        
      
        if (invalid(input$maxNotesPerOrder) | input$maxNotesPerOrder < 1) {
          createAlert(session, anchorId = "alert", alertId="a1", 
            content="Please enter max notes per order > 0",
            style = "danger",
            append = FALSE)
          return()
        }
        
        
        if (invalid(input$minCash) | input$minCash < 0) {
          createAlert(session, anchorId = "alert", alertId="a1", 
            content="Please enter minimum cash value >= 0",
            style = "danger",
            append = FALSE)
          return()
        }
        
        if (invalid(input$portfolioId) | input$portfolioId < 0) {
          createAlert(session, anchorId = "alert", alertId="a1", 
            content="Please enter portfolio id >= 0",
            style = "danger",
            append = FALSE)
          return()
        }
        
        if (invalid(input$filterMaxPct) | input$filterMaxPct < 1 | input$filterMaxPct > 100) {
          createAlert(session, anchorId = "alert", alertId="a1", 
            content="Please enter filter max percent between 1 and 100",
            style = "danger",
            append = FALSE)
          return()
        }
        
        
        closeAlert(session, alertId="a1")
        
        # Save configuration data
        config <- reactiveValuesToList(input)
                
        save(config,file='config/config.rda')
        
        createAlert(session, anchorId = "alert", alertId="a1", 
          content="Configuration saved",
          style = "success",
          append = FALSE)
        
      }
    })
    
  },
  options = list(launch.browser=launch.browser)
)