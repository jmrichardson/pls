#https://www.lendingclub.com/developers/listed-loans.action


# System configuration
library(methods)
library(shiny)
library(shinyBS)
library(gtools)

cron <- list()
if (file.exists('config/cron.rda')) {
  load('config/cron.rda')
}

launch.browser = function(appUrl, browser.path='/usr/bin/chromium-browser') {
  system(sprintf('"%s" --disable-gpu --app="data:text/html,<html>
    <head>
    <title>Schedule Service</title>
    </head>
    <body>
    <script>window.resizeTo(%s,%s);window.location=\'%s\';</script>
    </body></html>" &', browser.path, 900, 560, appUrl))
}


buttonEnableValue <- 0
buttonResetValue <- 0
buttonDisableValue <- 0

hoursChoices <- c(5,9,13,17)
minutesChoices <- c(59)
hoursNoListChoices <- ''
minutesNoListChoices <- ''

shinyApp(
  ui = fluidPage(
    br(),
    h4('Schedule Service'),
    fluidRow(
      column(6,
        wellPanel(
          h4('With List Detection'),
          HTML('PLS is configured to use the Pacific Time Zone to match the Lending Club platform.  Lending Club lists new loans 
            at 06:00, 10:00, 14:00, 18:00 PST.  The default configuration below starts PLS with list detection one minute prior to allow the system 
            enough time to properly load. <br><br>'),
          selectInput('hours', 'Start Hours', 
            choices=seq(0,23),
            multiple=TRUE,
            selected=if(length(cron$hours)>0) cron$hours else hoursChoices,
            selectize = TRUE),
          bsTooltip(id = "hours", title = "Select hours to start service in PST time", 
            placement = "top", trigger = "hover")
          , 
          selectInput('minutes', 'Start Minutes', 
            choices=0:59,
            multiple=TRUE,
            selected=if(length(cron$minutes)>0) cron$minutes else minutesChoices,
            selectize = TRUE),
          bsTooltip(id = "minutes", title = "Select minutes to start service in PST time", 
            placement = "top", trigger = "hover") 
          )
      ),
      column(6,
        wellPanel(
          h4('Without List Detection'),
          HTML('You can enable PLS to start without list detection if desired (expert use only).  Note that only one service can run at one time.  Please schedule with different start times
            than the "With" panel on the left and with enough time between start times to avoid overlap.<br><br>'),
          selectInput('hoursNoList', 'Start Hours', 
            choices=seq(0,23),
            multiple=TRUE,
            selected=if(length(cron$hoursNoList)>0) cron$hoursNoList else hoursNoListChoices,
            selectize = TRUE),
          bsTooltip(id = "hoursNoList", title = "Select hours to start service in PST time", 
            placement = "top", trigger = "hover")
          , 
          selectInput('minutesNoList', 'Start Minutes', 
            choices=0:59,
            multiple=TRUE,
            selected=if(length(cron$minutesNoList)>0) cron$minutesNoList else minutesNoListChoices,
            selectize = TRUE),
          bsTooltip(id = "minutesNoList", title = "Select minutes to start service in PST time", 
            placement = "top", trigger = "hover") 
        )
      )
    ),
    fluidRow(
      column(12,
        actionButton('enable', 'Enable Service'),
        actionButton('disable', 'Disable Service'),
        actionButton('reset', 'Reset'),
        tags$button( "Close", id="close", type="button", class="btn action-button", onclick="self.close()")    
      )
    ),
    fluidRow(
      column(12,
        br(),
        bsAlert(inputId="alert")   
      )
    )

  ), 
  
  server = function(input, output, session) {
    session$onSessionEnded(function() {
      stopApp()
    })
    
    # Enable button
    observe({
      if(input$enable > buttonEnableValue) {
        buttonEnableValue <<- input$enable
        
    
        if (invalid(input$hours)) {
          createAlert(session, inputId = "alert", alertId="a1", 
            message="Please select start hours with list detection (left panel)",
            type = "danger",
            append = FALSE)
          return()
        }
        
        if (invalid(input$minutes)) {
          createAlert(session, inputId = "alert", alertId="a1", 
            message="Please enter start minutes with list detection (left panel)",
            type = "danger",
            append = FALSE)
          return()
        }
             
        
        if (  invalid(input$hoursNoList) & !invalid(input$minutesNoList)   ) {
          createAlert(session, inputId = "alert", alertId="a1", 
            message="Please enter start hours without list detection (right panel)",
            type = "danger",
            append = FALSE)
          return()
        }
        
        if (  !invalid(input$hoursNoList) & invalid(input$minutesNoList)   ) {
          createAlert(session, inputId = "alert", alertId="a1", 
            message="Please enter start minutes without list detection (right panel)",
            type = "danger",
            append = FALSE)
          return()
        }
        
        closeAlert(session, alertId="a1")
        
        cron <<- reactiveValuesToList(input)
        save(cron,file='config/cron.rda')
        
        hours=paste(cron$hours, collapse=',')
        minutes=paste(cron$minutes, collapse=',')
        cronStr=paste(minutes,hours,'* * * /home/user/pls/start/startOrder.sh')
        
        cronStrNoList=''
        if (  !invalid(input$hoursNoList) & !invalid(input$minutesNoList)   ) {
          hoursNoList=paste(cron$hoursNoList, collapse=',')
          minutesNoList=paste(cron$minutesNoList, collapse=',')
          cronStrNoList=paste(minutesNoList,hoursNoList,'* * * /home/user/pls/start/startManual.sh nolist')
          cronStrCmb=paste(cronStr,cronStrNoList,sep="\n")
        } else {
          cronStrCmb=cronStr
        }
        
        print(cronStr)
        print(cronStrNoList)
        print(cronStrCmb)
        
        cmd=paste('echo "',cronStrCmb,'" | crontab -',sep='')
        system(cmd)
        stat=system('crontab -l | grep startOrder')
        if(stat!=0) {
          createAlert(session, inputId = "alert", alertId="a1", 
            message="Error adding service",
            type = "danger",
            append = FALSE)
          return()
        }
              
              
        createAlert(session, inputId = "alert", alertId="a1", 
          message="Service enabled",
          type = "success",
          append = FALSE)
        

      } 
    })
    
    # Disable button
    observe({
      if(input$disable > buttonDisableValue) {
        buttonDisableValue <<- input$disable
        closeAlert(session, alertId="a1")
        
        system('echo | crontab -')
        stat=system('crontab -l | grep startOrder')
        if(stat==0) {
          createAlert(session, inputId = "alert", alertId="a1", 
            message="Error clearing service",
            type = "danger",
            append = FALSE)
          return()
        }
                
        createAlert(session, inputId = "alert", alertId="a1", 
          message="Service disabled",
          type = "success",
          append = FALSE)
        
      } 
    })
    
    
    # Reset button
    observe({
      if(input$reset > buttonResetValue) {
        buttonResetValue <<- input$reset
        updateSelectizeInput(session, 'hours', choices=seq(0,23), selected=hoursChoices)
        updateSelectizeInput(session, 'minutes', choices=seq(0,59), selected=minutesChoices)
        updateSelectizeInput(session, 'hoursNoList', choices=seq(0,23), selected=hoursNoListChoices)
        updateSelectizeInput(session, 'minutesNoList', choices=seq(0,59), selected=minutesNoListChoices)
        createAlert(session, inputId = "alert", alertId="a1", 
          message="Start times reset.  Remember to click 'Enable Service' to apply",
          type = "success",
          append = FALSE)
      } 
    })
    

  },
  options = list(launch.browser=launch.browser)
)



