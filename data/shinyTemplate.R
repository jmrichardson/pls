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


help <- function() {
return('
<p>NO HELP YET
')
}

### UI
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
    .alert {
      margin-left: 20px;
    }
    ")
  ),
#   fluidRow(
#     numericInput('id',"Note ID")
#   ),
  fluidRow(
    dataTableOutput('table')
  )
  
  



))


server <- function(input, output, session) {
  
  session$onSessionEnded(function() {
    stopApp()
  })
  

  output$table <- renderDataTable(iris,
    options = list(
    pageLength = 5,
    initComplete = I("function(settings, json) {alert('Done.');}")
  ))


  
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

