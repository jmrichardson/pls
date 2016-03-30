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

load('config/grade.rda')

help <- function() {
return('
<p>Peer Lending Server can purchase new notes based on a portfolio percentage 
distribution of loan grades. Investors looking to mitigate risk by limiting 
the notes purchased in each grade can specify a maximum percentage for
each grade by overall distribution.</p>
<li>You can assign the maximum percentage of new notes to purchase for each loan grade based on 
your existing portfolio distribution.  
<li>PLS will not purchase
any new notes in a particular loan grade if it exceeds the maximum threshold.  For example,
if you assign grade C 60%, PLS will not purchase any new C notes
which would increase your current portfolio of C notes above 60%.
<li>An empty value will allow new notes to be purchased in the respective
loan grade regardless of allocation values in other grades. 
<li>Setting 0% maximum value will disable any new notes to be purchased
in the respective loan grade. 
<li>PLS will not sell or any way adjust your existing portfolio to match 
the assigned allocation.
<p></p>
Example 1:<br>
A=30, B=70, C=0, D=0, E=0, F=0, G=0<br>
Only purchase A notes if A notes do not exceed 30% of portfolio.
Only purchase B notes if B notes do not exceed 70% of portfolio.
Do not purchase any C,D,E,F or G notes.
<p></p>
Example 2:<br>
A=0, B=, C=40, D=40, E=40, F=0, G=0<br>
No limit on purchasing B notes.
Only purchase C notes if C notes do not exceed 40% of portfolio.
Only purchase D notes if D notes do not exceed 40% of portfolio.
Only purchase E notes if E notes do not exceed 40% of portfolio.
Do not purchase any A, F or G notes.
')
}

ui <- shinyUI(fluidPage(
  
  tags$head(
    tags$style(type="text/css","

    .well {
      margin-top: 20px;
    }

    .inline {
      display: inline-block;
    }

    input {
      margin-bottom: 20px;
    }

    #total {
      margin-top: 50px;
    }

    .fa {
      margin-left: 20px;
    }

    .alert {
      margin-left: 20px;
    }


    ")
  ),
  
  wellPanel(
    fluidRow(
      column(3,
        numericInput("gradeA", "Grade A:", min = 0, max = 100, value = NA, step = 1),
        numericInput("gradeE", "Grade E:", min = 0, max = 100, value = NA, step = 1)
      ),
      column(3,
        numericInput("gradeB", "Grade B:", min = 0, max = 100, value = NA, step = 1),
        numericInput("gradeF", "Grade F:", min = 0, max = 100, value = NA, step = 1)
      ),
      column(3,
        numericInput("gradeC", "Grade C:", min = 0, max = 100, value = NA, step = 1),
        numericInput("gradeG", "Grade G:", min = 0, max = 100, value = NA, step = 1)
      ),
      column(3,
        numericInput("gradeD", "Grade D:", min = 0, max = 100, value = NA, step = 1)
      )
    )
  ),
  fluidRow(
    column(5,
      actionButton("save", "Save"),
      actionButton("reset", "Reset"),
      actionButton("help", "Help"),
      tags$button( "Close", id="close", type="button", class="btn action-button", onclick="self.close()")    

    ),
    column(7,
      bsAlert("alert"),
      bsModal("helper", "Grade Allocation", "help", size = "large",
        HTML(help())
      )
    )
  )

))


server <- function(input, output, session) {
  
  # Update inputs on load
  updateNumericInput(session, "gradeA", value = grade$gradeA)
  updateNumericInput(session, "gradeB", value = grade$gradeB)
  updateNumericInput(session, "gradeC", value = grade$gradeC)
  updateNumericInput(session, "gradeD", value = grade$gradeD)
  updateNumericInput(session, "gradeE", value = grade$gradeE)
  updateNumericInput(session, "gradeF", value = grade$gradeF)
  updateNumericInput(session, "gradeG", value = grade$gradeG)
  
  session$onSessionEnded(function() {
    stopApp()
  })
  
  observeEvent(input$reset, {
    updateNumericInput(session, "gradeA", value = NA)
    updateNumericInput(session, "gradeB", value = NA)
    updateNumericInput(session, "gradeC", value = NA)
    updateNumericInput(session, "gradeD", value = NA)
    updateNumericInput(session, "gradeE", value = NA)
    updateNumericInput(session, "gradeF", value = NA)
    updateNumericInput(session, "gradeG", value = NA)
    closeAlert(session, alertId = "ALERT")
  })  
  
  observeEvent(input$save, {
    
    closeAlert(session, alertId = "ALERT")
    
    
    grade['gradeAlloc'] <- FALSE
    msg='Disabled'
    for (name in c('gradeA','gradeB','gradeC','gradeD','gradeE','gradeF','gradeG')) {

      if(!is.na(input[[name]])) {
        # Check for decimal point
        if(grepl("\\.",(input[[name]]))) {
          createAlert(session, anchorId = "alert", alertId = "ALERT",
            content=paste("Integer between 0 and 100 expected for",name),
            style = "danger",
            append = FALSE)
          return()
        }
        if(input[[name]] < 0) {
          createAlert(session, anchorId = "alert", alertId = "ALERT",
            content=paste("Integer between 0 and 100 expected for",name),
            style = "danger",
            append = FALSE)
          return()
        }
        if(input[[name]] > 100) {
          createAlert(session, anchorId = "alert", alertId = "ALERT",
            content=paste("Integer between 0 and 100 expected for",name),
            style = "danger",
            append = FALSE)
          return()
        }
        grade['gradeAlloc'] <- TRUE
        msg="Enabled"
      }
    }
    
    grade['gradeA'] <- input$gradeA
    grade['gradeB'] <- input$gradeB
    grade['gradeC'] <- input$gradeC
    grade['gradeD'] <- input$gradeD
    grade['gradeE'] <- input$gradeE
    grade['gradeF'] <- input$gradeF
    grade['gradeG'] <- input$gradeG
    
    save(grade,file='config/grade.rda')
    
    createAlert(session, anchorId = "alert", alertId = "ALERT",
      content=paste("Configuration Saved - Allocation ",msg, "",sep=''),
      style = "success",
      append = FALSE)
  })

  
}

# Browser launch settings
launch.browser = function(appUrl, browser.path=path) {
  system(sprintf('"%s" --disable-gpu --app="data:text/html,<html>
    <head>
    <title>Grade Allocation</title>
    </head>
    <body>
    <script>window.resizeTo(830,350);window.location=\'%s\';</script>
    </body></html>" &', browser.path, appUrl))
}

shinyApp(ui = ui, server = server, options = list(launch.browser=launch.browser))

