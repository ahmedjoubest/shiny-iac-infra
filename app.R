library(shiny)
library(shinyjs)

ui <- fluidPage(
  shinyjs::useShinyjs(), # Use shinyjs
  
  # ------ Scripts & styles ----------------------------------------------------
  includeCSS("www/css/app.min.css"), # App styles
  includeScript("www/js/logout.js"), # logout script
  
  # ------ Sandbox content -----------------------------------------------------
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
  ),
  
  # ------ Logout button -------------------------------------------------------
  actionButton("logout", "Logout")
)

server <- function(input, output, session) {
  
  # ------ Increment ActiveSessions when a user connects -----------------------
  update_active_sessions_per_task(
    value = 1,
    dynamodb_table_name = paste(Sys.getenv("env"), "active", "sessions", sep = "-"),
    cluster_name = "shiny-cluster",
    service_name = paste(Sys.getenv("env"), "shiny", "service", sep = "-")
  )
  
  # ------ Decrement ActiveSessions when a user disconnects --------------------
  session$onSessionEnded(function() {
    update_active_sessions_per_task(
      value = -1,
      dynamodb_table_name = paste(Sys.getenv("env"), "active", "sessions", sep = "-"),
      cluster_name = "shiny-cluster",
      service_name = paste(Sys.getenv("env"), "shiny", "service", sep = "-")
    )
  })
  
  # Sample plot
  output$hist <- renderPlot({
    hist(rnorm(input$num))
  })
  
  # ------ On logout, delete cookies and redirect to the logout URL ------------
  observeEvent(input$logout, {
    # Delete cookies and logout using JavaScript
    shinyjs::runjs("logout('logout');")
    # Redirect to the logout URL
    base_url <- Sys.getenv("cognito_domain")
    client_id <- paste0("client_id=", Sys.getenv("cognito_client_id"))
    logout_uri <- paste0("logout_uri=", Sys.getenv("logout_uri"))
    redirect_url <- paste0(base_url, "logout?", client_id, "&", logout_uri)
    shinyjs::runjs(sprintf("window.location.href = '%s';", redirect_url))
  })
}

# Run the application
shinyApp(ui = ui, server = server)
