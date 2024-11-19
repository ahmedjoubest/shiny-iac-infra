library(shiny)

ui <- fluidPage(
  titlePanel("Simple Shiny App"),
  sidebarLayout(
    sidebarPanel(
      sliderInput("num",
                  "Number of Random Values:",
                  min = 1, max = 100, value = 50)
    ),
    mainPanel(
      plotOutput("hist")
    )
  )
)

server <- function(input, output, session) {
  
  # Increment ActiveSessions when a user connects
  update_active_sessions_per_task(
    value = 1,
    dynamodb_table_name = paste(Sys.getenv("env"), "active", "sessions", sep = "-"),
    cluster_name = "shiny-cluster",
    service_name = paste(Sys.getenv("env"), "shiny", "service", sep = "-")
  )
  
  # Decrement ActiveSessions when the session ends
  session$onSessionEnded(function() {
    update_active_sessions_per_task(
      value = -1,
      dynamodb_table_name = paste(Sys.getenv("env"), "active", "sessions", sep = "-"),
      cluster_name = "shiny-cluster",
      service_name = paste(Sys.getenv("env"), "shiny", "service", sep = "-")
    )
  })
  
  output$hist <- renderPlot({
    hist(rnorm(input$num))
  })
}

# Run the application
shinyApp(ui = ui, server = server)
