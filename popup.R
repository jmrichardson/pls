library(shiny)

popup <- function (message='Default Message', width=500, height=150, title='Important') {
  
  launch.browser = function(appUrl, browser.path='/usr/bin/chromium-browser') {
    system(sprintf('"%s" --disable-gpu --app="data:text/html,<html>
      <head>
      <title>%s</title>
      </head>
      <body>
      <script>window.resizeTo(%s,%s);window.location=\'%s\';</script>
      </body></html>" &', browser.path, title, width, height, appUrl))
  }
  
  shinyApp(
    ui = fluidPage(
      fluidRow(
        br(),
        br(),
          fluidRow(
            column(12,
              div(htmlOutput("message"),align = "center"),
              br(),
              div(tags$button( "Close", id="close", type="button", class="btn action-button", onclick="self.close()"),align = "center") 
            )
          )

      )
    ), 
    
    server = function(input, output, session) {
      session$onSessionEnded(function() {
        stopApp()
      })
      output$message <- renderText(message)
    },
    options = list(launch.browser=launch.browser)
  )
}
