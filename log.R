# Load
library(shiny)
# System configuration
library(dplyr)
library(shinyBS)
library(gtools)

# require(rCharts)
# library(reshape2)

launch.browser = function(appUrl, browser.path='/usr/bin/chromium-browser') {
  system(sprintf('"%s" --disable-gpu --app="data:text/html,<html>
    <head>
    <title>PLS Log</title>
    </head>
    <body>
    <script>window.resizeTo(%s,%s);window.location=\'%s\';</script>
    </body></html>" &', browser.path, 870, 650, appUrl))
}

buttonClearValue <- 0
buttonStopValue <- 0

shinyApp(
  ui = fluidPage(
    fluidRow(
      br(),
      column(11,
        tags$button( "Stop Service", id="stop", type="button", class="btn action-button", 
          onclick="val=confirm('Are you sure you want to kill any running service?');
          Shiny.onInputChange('confirmStop', val);"),
        tags$button( "Clear Log", id="clear", type="button", class="btn action-button", 
          onclick="val=confirm('Are you sure you want to clear the log?');
          Shiny.onInputChange('confirmClear', val);"),
        tags$button( "Close", id="close", type="button", class="btn action-button", onclick="self.close()"),
        br(),br(),
        bsAlert(inputId="alert")
      )
    ),
    fluidRow(
      column(12,
        dataTableOutput(outputId="log"),
        br()
      )
    )
  ), 
  
  server = function(input, output, session) {
    session$onSessionEnded(function() {
      stopApp()
    })
    
    fileData <- reactiveFileReader(1000, session, 'log/system.log', read.csv,header=FALSE,sep="|")
    
    output$log <- renderDataTable({
      data <- fileData()
      names(data)<-c('Date','Status')
      data <- arrange(data,desc(Date))
      # head(print(data))
      arrange(data,desc(Date))
      
    },options = list(pageLength = 100,
      autoWidth = FALSE,
      columns = list(list(width = "140px"), list(width = "375px"))
      ))
    
    # Clear log button
    observe({
      if(input$clear > buttonClearValue) {
        buttonClearValue <<- input$clear
        if (input$confirmClear==TRUE) {
          system('echo "0000-00-00 00:00:00 PST|PLS Log File Init" > /home/user/pls/log/system.log')
          createAlert(session, inputId = "alert", alertId="a1", 
            message="Service log cleared",
            type = "success",
            append = FALSE)
          return()
        }
      } 
    })
    
    # Stop service
    observe({
      if(input$stop > buttonStopValue) {
        buttonStopValue <<- input$stop
        if (input$confirmStop==TRUE) {
          system('/home/user/pls/bin/kill_service.sh')
          createAlert(session, inputId = "alert", alertId="a1", 
            message="All service processes killed",
            type = "success",
            append = FALSE)
          return()
        }
      } 
    })
    
  },
  options = list(launch.browser=launch.browser)
)
