
# Load Shiny package
library(shiny)

# Define UI for app
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

# Define server logic
server <- function(input, output) {
  output$hist <- renderPlot({
    hist(rnorm(input$num))
  })
}

# Run the application
shinyApp(ui = ui, server = server)
